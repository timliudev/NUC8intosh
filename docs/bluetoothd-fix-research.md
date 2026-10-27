# bluetoothd SIGBUS（APFS 壓縮雜湊錯誤）：根治／緩解研究（2026-10-27）

接續 [bluetoothd-apfs-hash-mismatch.md](bluetoothd-apfs-hash-mismatch.md)。只讀研究，未改任何系統設定。

## 結論

**沒有已知的上游修正，也沒有現成的開關可以關掉這個問題；根因的「補丁頁 → 雜湊失敗」機制仍是推論。** 現實可行的是：先拿「`sudo purge` 能否救回」做一次便宜實驗，並加上偵測提醒；要根治只剩「自行 fork BlueToolFixup，改成不動檔案頁」，工程量大、成功率不明。

## 建議排序

| # | 做法 | 效果 | 成本 | 信心 | 依據 |
| --- | --- | --- | --- | --- | --- |
| 1 | 下次發生時先試 `sudo purge`，再 `launchctl kickstart -k system/com.apple.bluetoothd`，成功就不必重開機 | 若補丁頁是殘留在檔案快取，purge 會丟掉乾淨的快取頁 | 幾乎 0，但**純屬實驗**，尚未測過 | 低 | 見「機制」：補丁寫在檔案頁快取；但壞的可能是 APFS 解壓快取，purge 不一定清得到 |
| 2 | 偵測 log 的 `apfs_pagein ... error 94 (bluetoothd)` 後通知（見下方腳本方向） | 不改變問題，但不用等到發現藍牙壞掉才處理 | 低 | 高（可行性）／低（價值） | 症狀在第一次 SIGBUS 的同一毫秒就有 kernel log |
| 3 | 觀察記憶體壓力是否為觸發條件（記錄 swap／`memory_pressure` 與 SIGBUS 時間） | 驗證推論；若證實可靠減少 swap 緩解 | 低 | 低 | 目前機器 20 GB RAM、swap 已用 5.5／6 GB（本次調查時實測），壓力確實高；但「壓力是必要條件」未證實 |
| 4 | fork BlueToolFixup，把補丁從 `cs_validate_page` 的檔案頁改成「行程私有頁」（仿 Lilu `UserPatcher` 的 `vm_map_write_user` 路徑）或其他不改檔案頁的做法 | 理論上根治（APFS 看到的頁不再被改） | 高：要寫 kext、Tahoe 上沒人驗證過 | 低 | 見「機制」與「為何無現成選項」 |
| 5 | 換成不需要 BlueToolFixup 的藍牙：**僅「真 Broadcom（USB 0x0A5C）」有機會**，Intel 沒有（見「不改 bluetoothd 的路線」） | 可能根治 | 換硬體；9560 是否可換未確定，且 Broadcom 非 PatchRAM 路線的 Tahoe 實例未查到 | 低 | bugtracker#1821、BlueToolFixup 原始碼 |
| 5b | 在 kernel 端偽裝成 Broadcom 以免改 bluetoothd | 若可行即根治 | 要自己逆向 bluetoothd、寫 kext；**查無任何前人做法** | 很低 | 見下節 |
| 6 | 降 Lilu／BlueToolFixup 版本、換 FeatureUnlock 版本 | 無依據 | 中 | 很低 | 前例（#493 用 2.4.0／Sonoma、#329 用 OCLP Ventura）說明不是 Tahoe 或 2.5.x 才有 |
| ✗ | 改 bluetoothd 本體 | 不可行 | — | — | SSV，已排除 |

## 機制：補丁到底改了什麼（回答 Q1、Q2）

**前提要修正：BlueToolFixup 不走 Lilu `UserPatcher` 改行程記憶體，走的是 kernel 端的 `cs_validate_page` 掛鉤。** 所以 Lilu 的 `-liluuseroff` 之類（UserPatcher 開關）關不掉它。

- 來源 `BrcmPatchRAM/BlueToolFixup.cpp`：`pluginStart()` 用 `patcher.routeMultipleLong(KernelPatcher::KernelID, "_cs_validate_page", patched_cs_validate_page, ...)`；`patched_cs_validate_page` 先呼叫原函式，再用 `vn_getpath` 判斷路徑是 `/usr/sbin/bluetoothd`，對傳進來的 `data`（`PAGE_SIZE` 一頁）做 `findAndReplace`。
- `data` 是核心正在驗證的那一頁的內容緩衝，**不是行程私有 COW 頁**；補丁在簽章驗證之後才寫入，所以頁面內容與 CodeDirectory 雜湊不符，而 kernel 不會察覺。（推斷：`data` 對應 page cache 頁；`xnu/osfmk/vm/vm_fault.c` 只看到呼叫 `vm_page_validate_cs(m, ...)`，我沒讀到驗證函式本體，**未直接證實**。）
- Lilu 側 `kern_user.cpp` 的 `codeSignValidatePageWrapper`（`if (res) that->performPagePatch(data, PAGE_SIZE)`）是同一種機制，也是後寫入、不重算簽章；`performPagePatch` 對每一頁比對儲存的樣板再寫補丁。這就是 FeatureUnlock（bugtracker#2228）與 BlueToolFixup 共有的路徑。
- Lilu 真正的行程私有補丁是 `UserPatcher::patchSharedCache` ／ `patchBinary`，先 `vmProtect` 加寫入權限、清掉 `CS_KILL|CS_HARD|CS_ENFORCEMENT`、再 `vm_map_write_user`——那條才是 COW。BlueToolFixup 沒走這條。
- Tahoe 上 BlueToolFixup 打的補丁（`searchAndPatch`，同一檔）：
  - `kVendorCheck`：把 `cmp edx, 0x0A5C`（Broadcom）後的 `jnz`（0x74）改成 `jmp`（0xEB），讓非 Broadcom 廠商通過。
  - `kBadChipsetCheck15_4`（核心版本 ≥ Sequoia）：`cmp ecx, 5999; ja` 整段改成 NOP，讓 chipset 範圍檢查失效（註解：舊版 `kBadChipsetCheck` 是「不認 0 THIRD_PARTY_DONGLE，關再開藍牙會失敗」，見 BrcmPatchRAM PR#18）。
  - 可選、預設關：`-btlfxboardid`（≥ Sonoma）、`-btlfxallowanyaddr`、`-btlfxnvramcheck`（僅 ≤ Sonoma）。
  - 外掛 `BlueTool` 的 `/etc/bluetool/SkipBluetoothAutomaticFirmwareUpdate` 路徑也會被換掉（不影響 bluetoothd）。
  - 版本範圍上限 `KernelVersion::Tahoe`。
- 為什麼 Intel 也需要：`kVendorCheck` 讓 bluetoothd 收非 Broadcom／CSR 的控制器（BrcmPatchRAM bugtracker#1821 提到「Monterey beta 10 起 bluetoothd 忽略 Broadcom／CSR 以外廠商」）。IntelBTPatcher 本身是 kernel 端（改 IOBluetooth 相關行為），**lshbluesky fork 的 README 只說支援 Tahoe 26 與 LE Data Length 修正，沒有提到 BlueToolFixup，所以「Intel 在 Tahoe 是否可以不要 BlueToolFixup」找不到任何文件，視為不行**（信心中）。

### 為什麼會跟 APFS 壓縮區塊衝突（仍是推論）

- 實測的四組「出錯頁 ≠ 補丁頁、同 64 KiB 區塊」支持：APFS／decmpfs 以 64 KiB 區塊解壓並驗證，該區塊內有頁面被改過，後續重新讀入該區塊時驗證失敗 → `EBADMSG`。
- 補丁每次 page-in 都會重打（hook 在每頁驗證時執行），所以乾淨重新讀入也會再被改；真正讓重啟服務無效的原因（舊快取頁被留著，還是狀態卡在 APFS 內）**沒有證據可分辨**。
- Apple 在 APFS／decmpfs 的驗證路徑不開源，找不到任何公開資料說明為何 Tahoe 以後會對壓縮檔做這種雜湊比對；Lilu 的 Changelog 也沒有相關條目。

## 上游現況（回答 Q4）

| 專案 | 結果 |
| --- | --- |
| acidanthera/Lilu | `gh search`／搜尋 `apfs_pagein`、`hash mismatch`、`bluetoothd SIGBUS` 皆無命中 |
| acidanthera/BrcmPatchRAM | 同上；只有 #1821（BlueToolFixup 已知問題總表，未提 SIGBUS／雜湊錯誤） |
| acidanthera/bugtracker | #2228（FeatureUnlock、ControlCenter，已關，無診斷）；#1833（Monterey bluetoothd crash，與本案不同） |
| OpenIntelWireless／lshbluesky IntelBluetoothFirmware | #493 已關，作者自行關閉，無回覆；lshbluesky 未找到相關 issue |
| dortania/bugtracker #329 | 「Encountered a compressed data hash mismatch」，維護者以非 OCLP 議題為由關閉（not planned），無人診斷；未列任何 kext |
| OCLP | 搜尋無命中（但 GitHub API 在中途撞到 rate limit，OCLP／IntelBluetoothFirmware 的部分查詢可能不完整） |

**搜尋有缺口**：GitHub issue 搜尋只能做關鍵字；後半段 API 被限流，未能對 Lilu／BrcmPatchRAM 用更多詞（`KERN_MEMORY_ERROR`、`ktriage`）重搜。結論是「沒找到」，不是「確定沒有」。

## Q3：能否避開壓縮區塊

- 改 bluetoothd 本體、把檔案搬離壓縮：被 SSV 擋，排除。
- `-lilulowmem`（Lilu 的 `bootargLowMem`）只是關閉 Lilu 的 kext 解壓縮功能（`allowDecompress`），與 bluetoothd 的 APFS 壓縮無關，無效。
- 降低記憶體壓力：可行但只是機率下降；本機 swap 已近滿（5.5／6 GB）。如果第 3 項實驗證實相關，可以考慮增加 swap 以外的作法（關掉吃記憶體的 App），但**沒有證據能保證消除**。
- 改成 kernel 端以外的補丁方式（第 4 項）才是真正避開：Lilu 有可借用的 `UserPatcher` 路徑，但 Tahoe 上是否能在 `bluetoothd`（platform binary）上運作，找不到任何人驗證過。

## 第 2 項：偵測提醒的做法（Q5）

值得做，但只是提醒，不是修復。建議以 `launchd` user agent 跑 `/usr/bin/log stream --predicate 'process == "kernel" AND eventMessage CONTAINS "apfs_pagein" AND eventMessage CONTAINS "error 94" AND eventMessage CONTAINS "bluetoothd"'`，命中後 `osascript -e 'display notification ...'`，並在通知裡寫「先試 `sudo purge` + kickstart，不行就重開機」。因為第一次 SIGBUS 與 kernel 錯誤同毫秒出現，不需要輪詢。**還沒實作**，要做請另外指示。

## 下一步建議

1. 把本文第 1、3 項寫成「發生時的標準動作」：先 `sudo purge`＋kickstart，記下成功與否與 `vm.swapusage`。
2. 蒐集 2～3 次實測後再決定要不要投入第 4 項。

## 不改 bluetoothd 的路線（追加研究）

**結論：查不到任何前人做過「kernel 端讓 Intel 藍牙看起來像 Broadcom、因而不用改 bluetoothd」，現有所有 Intel 方案（含新的 IntelBTUnified）都還是用 `cs_validate_page` 改 bluetoothd 頁面。**

### 1. 檢查值從哪來

- **廠商檢查（`cmp edx, 0x0A5C`）**：值 0x0A5C 是 USB Broadcom 廠商 ID，這點有間接證據——[bugtracker#1821](https://github.com/acidanthera/bugtracker/issues/1821) 中 dhinakg 說「Monterey beta 10 起，非 Broadcom／CSR 的廠商一律被忽略」，另一位回覆者（CommandMaker）說補丁只對「genuine Broadcom devices (vendor id 0x0a5c)」有效。但**沒有人貼出反組譯，也沒說 `edx` 是從 IOKit 的 `idVendor` 屬性、HCI 的 Manufacturer 還是 IOBluetoothFamily 傳上來的 controller 屬性取得——查不到。**
- **`kBadChipsetCheck`（`cmp ecx, 1999／3998／5999`）**：BlueToolFixup 註解說是「chipset 範圍檢查不認 0 `THIRD_PARTY_DONGLE`」；[BrcmPatchRAM PR#18](https://github.com/acidanthera/BrcmPatchRAM/pull/18) 只給出 `chipsetToStr` 偽碼（>1999 為 Apple chipset、0～21 為 Broadcom／第三方），**沒說 chipset 值怎麼得來**。#1821 中的線索是「bluetoothd 要從預先定義的 chipset 清單辨識晶片」「產品名稱超過 29 字元會被歸為 THIRD_PARTY_DONGLE」「改短產品名後變成 BCM_20702A3」——代表**chipset 值很可能來自 USB 產品名／描述字串與預設表比對**，這是推論，不是反組譯結論。
- 舊版 BlueToolFixup 的做法是設 `transport-encoding`（改傳輸類型），但 #1821 指出 Monterey beta 10 後「`transport-encoding` 不再能改傳輸類型」，且副作用大；所以才改成改 bluetoothd。

### 2. 有沒有人做過 kernel 端偽裝

- **IntelBluetoothFirmware**：只把 USB host controller 的名稱改成 `Bluetooth USB Host Controller`，目的是繞過 **board-id 檢查**（[官方 FAQ](https://openintelwireless.github.io/IntelBluetoothFirmware/FAQ.html)）。這跟廠商檢查是兩回事；FAQ 同一頁仍要求「Monterey 以後安裝 BlueToolFixup」。你的 log 裡已經有這個名稱（`Bluetooth USB Host Controller@14500000`）。
- **IntelBTPatcher**（`IntelBTPatcher.cpp`）：Monterey 以後只 hook `IOUSBHostDevice::deviceRequest`，在 `LE Set Scan Param`（0x200B）前補送一次隨機位址 HCI 指令，在 `HCI Reset`（0x0C03）時重設旗標；**沒有任何偽裝廠商或 chipset 的程式碼，也沒提到 Broadcom**。
- **[laguillo/IntelBTUnified](https://github.com/laguillo/IntelBTUnified)**：把三支 kext 合成一支，README 明說 bluetoothd／BlueTool 補丁是「the same ones」（BlueToolFixup 的），原始碼同樣 route `_cs_validate_page`。**所以換成它不會解決問題，反而多一個沒審過的 kext**；作者只在 AX210＋macOS 26.7 上測過。
- 搜尋 Dortania 文件、AMD-OSX、tonymacx86、Reddit、遠景：只找到「Intel 要用 BlueToolFixup」（Dortania Monterey 頁）與 Ventura 上組合失敗的零星貼文，**沒有 spoof／fake Broadcom／「without BlueToolFixup」的實例**。遠景（pcbeta）與 Reddit 沒有搜尋到有用結果，不代表不存在。

### 3. 理論上可行嗎

- 若要只靠 kernel 改，必須讓 bluetoothd 看到的廠商 ID＝0x0A5C 且 chipset 在 Broadcom 表內。但這會讓 IOBluetoothFamily 選用 `BroadcomBluetoothHostController`（[官方 FAQ](https://openintelwireless.github.io/IntelBluetoothFirmware/FAQ.html) 說該類別用 `SendRawHCICommand`），把 Intel 控制器當 Broadcom 驅動，可能套用 Broadcom 專屬 HCI 指令／韌體路徑。**沒有任何人驗證過，風險是藍牙更不穩，且要自己逆向 bluetoothd 才知道值從哪來。** 偽造 USB 描述符（`idVendor`）還會影響 IntelBluetoothFirmware 的 IOKit 比對（它靠 `8087:xxxx` 比對裝置）。
- 與 IntelBTPatcher 相容性、韌體載入影響：**無資料，無法評估。**

### 4. NUC8i7BEH 的 Wireless-AC 9560 是否可換

**沒有查到確定答案。** 證據互相矛盾：Notebookcheck 評測把 WLAN 模組標為「不可更換」；ASUS（接手 NUC）FAQ 對 NUC8i5BEH 說 2230 插槽是給原廠無線模組的、不支援裝別的模組；第三方手冊網站說 NUC8i3BEH 的 2230 Wi-Fi 模組拆天線線和一顆螺絲即可更換。綜合看，**較可能是 M.2 2230（CNVi）插卡而非焊死，但 CNVi 介面只相容 Intel 的 CNVi 卡，不是任意 M.2 Wi-Fi 卡，所以「換成 Broadcom 卡」可能根本插不進來**（此點為依一般 CNVi 規格的推論，未查到 NUC8 專屬資料）。要確認請看使用者自己的機器或 Intel 官方 Technical Product Specification。實務替代是 **USB 外接 Broadcom 藍牙 dongle**，但那仍要 BrcmPatchRAM 與 BlueToolFixup（`kBadChipsetCheck` 對 Broadcom 也是必要補丁），不會免於改 bluetoothd，除非是原生被接受的 Apple 認可晶片，**未找到 Tahoe 實例**。

### 對建議排序的影響

沒有新的低成本根治路線；第 5 項改寫為「僅真 Broadcom 才有機會」，新增 5b（kernel 偽裝，查無前例）。排序維持：purge 實驗 → 偵測提醒 → 記錄記憶體壓力 → 若要根治，優先 fork BlueToolFixup 改成不動檔案頁，而不是偽裝廠商。
