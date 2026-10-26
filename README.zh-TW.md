# Intel NUC8i7BEH (Bean Canyon) Hackintosh - macOS Tahoe 26.7.2

[English](README.md) | 繁體中文

適用於 **Intel NUC8i7BEH** 的 OpenCore EFI，目前在 **macOS Tahoe 26.7.2 (25G330)** 上使用，並附上完整的建置與除錯紀錄。

- OpenCore **1.0.8**（官方 release，2026-09-27；`OpenCore.efi`、`BOOTx64.efi` 與 OpenCore 驅動均取自官方 `OpenCore-1.0.8-RELEASE.zip`）
- SMBIOS：`iMac20,2`
- 這是個人手動測試的設定，不是開箱即用的發行版。使用前請先看「可用／不可用」。

> **開機前請先產生你自己的 SMBIOS。** `EFI/OC/config.plist` 的 `PlatformInfo.Generic` 中，`SystemSerialNumber`、`MLB`、`SystemUUID`、`ROM` 都是**空的**。請用 [macserial](https://github.com/acidanthera/OpenCorePkg/tree/master/Utilities/macserial) 產生 `iMac20,2` 的序號與 MLB（`./macserial -m iMac20,2 -g -n 1`），用 `uuidgen` 產生 `SystemUUID`，並設定 `ROM`（例如填網卡 MAC 位元組）。不要沿用別人的值，也不要公開自己的。

## 硬體

| 項目 | 型號 | 備註 |
| --- | --- | --- |
| 主機 | Intel NUC8i7BEH (Bean Canyon) | 建議 BIOS 0095 以上 |
| CPU | Intel Core i7-8559U (Coffee Lake) | |
| 內顯 | Intel Iris Plus Graphics 655 | `AAPL,ig-platform-id` = `0x3EA50004` |
| 記憶體 | 16 GB + 4 GB | 雙通道不對稱，可運作 |
| 儲存 | Crucial MX500 500 GB，M.2 2280 **SATA** | 非 NVMe，因此不使用 NVMeFix |
| 有線網路 | Intel I219-V | IntelMausi |
| 無線網路 | Intel Wireless-AC 9560（PCI `8086:9DF0`） | AirportItlwm（原生 Wi‑Fi 選單） |
| 藍牙 | Intel（USB，9560 內建） | IntelBluetoothFirmware |
| 音效 | Realtek ALC235 | SimpleHDA + AppleALC，layout-id 8 |
| 讀卡機 | Realtek RTS522A | RealtekCardReader |

## 目前狀態

在 macOS 26.7.2 (25G330) 上測試。「使用者確認」指這台機器的主人實際操作過，並非跑分或正式測試。

| 功能 | 狀態 | 依據／限制 |
| --- | --- | --- |
| 開機、安裝、顯示加速 | 可用 | 安裝當時（26.6.2）確認 Metal 3 加速正常 |
| 有線網路（I219-V） | 可用 | 需要 `DisableIoMapper=true`（見下） |
| Wi‑Fi | 可用 | AirportItlwm，系統 Wi‑Fi 選單、WPA2 連線與 ping 測試皆確認。此 kext 為 alpha；5 GHz 高負載、Wi‑Fi 6、長時間穩定度未測 |
| 接力（Handoff） | 可用 | 使用者確認 |
| 藍牙 | 可用 | IntelBluetoothFirmware 2.5.2；藍牙 DAC 的 A2DP／HFP 使用者確認 |
| 3.5 mm 音訊輸出 | 可用 | SimpleHDA 搭配 layout-id 8，使用者確認。layout-id 3 只有雜訊 |
| USB 音訊 | 可用 | 使用者確認 |
| USB-C Hub（DP、鏡頭） | 可用，**含熱插拔**（需 SSDT-TBFP） | 2026-10-27 實測：開機時 USB-C 未接任何裝置，開機後才插 Hub，USB 鏡頭正常出現；DP 螢幕第一次需把 DP 線拔插一次才亮，待重複測試。開機前接上同樣可用 |
| 麥克風 | 未測 | 輸入裝置有列舉，沒做錄音測試 |
| 睡眠／喚醒 | **未測，維持停用** | `pmset sleep 0`。查無 NUC8 在 Sonoma 以後或搭配 Thunderbolt 強制供電的睡眠實測；AirportItlwm 在 Tahoe 有喚醒後失效的回報（[laobamac/itlwm#19](https://github.com/laobamac/itlwm/issues/19)，修正 `2d3e797` 不在目前使用的版本），IntelBluetoothFirmware 亦有喚醒問題（[#484](https://github.com/OpenIntelWireless/IntelBluetoothFirmware/issues/484)） |
| 讀卡機 | 正常 | 256 GB SDXC 卡掛載為「Built In SDXC Reader」；32 MB 寫入後讀回雜湊相符（2026-10-27） |
| OTA 更新 | 可用 | 已透過軟體更新從 25G325 升到 25G330（`revpatch=sbvmm` + RestrictEvents） |
| 通用剪貼簿 | 未測 | |
| AirDrop、AWDL | **不支援** | 此 Wi‑Fi 驅動沒有 `awdl0` |
| Thunderbolt（原生） | **部分／實驗性** | JHL6340（Alpine Ridge），**未刷韌體**。加入 SSDT-TBFP 後 NHI（`8086:15D9`）出現、`AppleThunderboltNHIType3` 載入；Thunderbolt 裝置本身未測。刷控制器韌體（[osy/ThunderboltPatcher](https://github.com/osy/ThunderboltPatcher)）**不採用**：在 NUC8 上會造成睡眠喚醒 kernel panic 與 USB-C 不穩，2021 年後無人解決（[zearp/Nucintosh#174](https://github.com/zearp/Nucintosh/issues/174)） |

專案早期曾出現 USB 間歇失效與 `bluetoothd` 崩潰。`bluetoothd` 崩潰在原地重裝 macOS 後不再出現；USB 的根因未能釐清。

## Kext

下列版本均讀自本 repo 內各 kext 的 `Info.plist`。「最新」於 2026-10-27 對照 GitHub release 與 [Dortania build-repo](https://github.com/dortania/build-repo) 查得。原則：只要有**官方最新 release** 就用官方版；每個官方 zip 的 sha256 都對過 GitHub asset digest，並把執行檔 sha256 與已安裝檔案比對。不再使用 Dortania dev 建置。官方版**比先前的 dev 建置舊**者，原因寫在表中。

| Kext | 已安裝 | 最新可用（2026-10-27 查） | 來源 | 二進位 |
| --- | --- | --- | --- | --- |
| [Lilu](https://github.com/acidanthera/Lilu) | 1.7.2 | 1.7.2 為官方最新（2026-03-20）；master 為 1.7.3 | 官方 [1.7.2](https://github.com/acidanthera/Lilu/releases/tag/1.7.2) `Lilu-1.7.2-RELEASE.zip` | 相符。原為 dev 1.7.3；1.7.3 只新增 Tiger Lake-H CPU 型號（另有未發行的 analyzer 修正），與 Coffee Lake 無關。1.7.1 起已可在 macOS 26 不加 `-lilubetaall` 載入；本 EFI 所有 kext 只需 Lilu ≥1.2.0（SimpleHDA ≥1.7.1），故 1.7.2 足夠 |
| [WhateverGreen](https://github.com/acidanthera/WhateverGreen) | 1.7.1 | 1.7.1 為官方最新（2026-09-27） | 官方 [1.7.1](https://github.com/acidanthera/WhateverGreen/releases/tag/1.7.1) `WhateverGreen-1.7.1-RELEASE.zip` | 相符（取代原 dev 建置） |
| [VirtualSMC](https://github.com/acidanthera/VirtualSMC)、SMCProcessor、SMCSuperIO | 1.3.8 | 1.3.8 為官方最新（2026-09-27） | 官方 [1.3.8](https://github.com/acidanthera/VirtualSMC/releases/tag/1.3.8) `VirtualSMC-1.3.8-RELEASE.zip` | 相符（取代原 dev 建置） |
| [RestrictEvents](https://github.com/acidanthera/RestrictEvents) | 1.1.6 | 1.1.6 為官方最新（2025-07-07） | 官方 [1.1.6](https://github.com/acidanthera/RestrictEvents/releases/tag/1.1.6) | 相符。原為 dev 1.1.7：dev 的「較新」版本只是 release 後的 `Bump version` commit（僅改專案檔），沒有程式變更 |
| [FeatureUnlock](https://github.com/acidanthera/FeatureUnlock) | 1.1.8 | 1.1.8 為官方最新（2025-07-07） | 官方 [1.1.8](https://github.com/acidanthera/FeatureUnlock/releases/tag/1.1.8) | 相符。原為 dev 1.1.9：dev 的「較新」版本只是 release 後的 `Bump version` commit（僅改專案檔），沒有程式變更 |
| [CPUFriend](https://github.com/acidanthera/CPUFriend) | 1.3.0 | 1.3.0 為官方最新（2025-07-07） | 官方 [1.3.0](https://github.com/acidanthera/CPUFriend/releases/tag/1.3.0) | 相符。原為 dev 1.3.1：dev 的「較新」版本只是 release 後的 `Bump version` commit（僅改專案檔），沒有程式變更 |
| BlueToolFixup（[BrcmPatchRAM](https://github.com/acidanthera/BrcmPatchRAM)） | 2.7.2 | 2.7.2 為官方最新（2026-03-20） | 官方 [2.7.2](https://github.com/acidanthera/BrcmPatchRAM/releases/tag/2.7.2) `BrcmPatchRAM-2.7.2-RELEASE.zip` | 相符。原為 dev 2.7.3：只是 `Bump version` commit（專案檔與 injector 的 Info.plist，不含 BlueToolFixup 程式） |
| [AppleALC](https://github.com/acidanthera/AppleALC) | 1.9.8 | 1.9.8 為官方最新（2026-09-27） | 官方 [1.9.8](https://github.com/acidanthera/AppleALC/releases/tag/1.9.8) `AppleALC-1.9.8-RELEASE.zip` | 相符（取代 2026-03 的 dev 建置） |
| [SimpleHDA](https://github.com/laobamac/SimpleHDA) | 1.0.0 | 1.0.0（v1.0.0，2026-10-14）即最新 | laobamac/SimpleHDA v1.0.0 `SimpleHDA-Tahoe-v1.0.0-RELEASE.zip`；zip sha256 `89198256664078c91155d673ee7cebb08134dad1b71d5e34b0aa4ef0d4877f8f` | 相符 |
| [IntelMausi](https://github.com/acidanthera/IntelMausi) | 1.0.8 | 1.0.8 即最新（2024-12 後無新 commit） | release 1.0.8 | 相符 |
| [AirportItlwm](https://github.com/laobamac/itlwm) | 2.4.0（alpha，commit `738d4c6`，Tahoe 版） | 2.4.0-alpha 即最新；尚無正式版 | [laobamac/itlwm](https://github.com/laobamac/itlwm/releases/tag/v2.4.0-alpha)（非 fork；prerelease，2026-10-11），檔案 `AirportItlwm-Tahoe-v2.4.0-RELEASE-alpha-738d4c6.zip`；sha256 `25680aa39ddd79b205141875b261bdcc28bea150d13f27787b3c215555daa00f` | 相符 |
| IntelBluetoothFirmware、IntelBTPatcher | 2.5.2 | 此 fork 的 2.5.2（2026-10-18）即最新；上游 [OpenIntelWireless](https://github.com/OpenIntelWireless/IntelBluetoothFirmware) 最新 release 仍是 2.4.0，沒有 2.5.x | [lshbluesky/IntelBluetoothFirmware](https://github.com/lshbluesky/IntelBluetoothFirmware) v2.5.2，是 OpenIntelWireless 的 fork（領先 7 個 commit、落後 0）；zip sha256 `c26140b2091e7b41aab5e5fbdd322112908efc509f9fde3d71d4e3f91396b991` | 相符 |
| [RealtekCardReader](https://github.com/0xFireWolf/RealtekCardReader) | 0.9.7 | 0.9.7 即最新 | release 0.9.7（`006a845`） | 相符 |
| [RealtekCardReaderFriend](https://github.com/0xFireWolf/RealtekCardReaderFriend) | 1.0.4 | 1.0.4 即最新 | release 1.0.4（`e1e3301`） | 相符 |
| USBPorts | 1.1 | 不適用（本機） | 本機 USB 對應表，來自 [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh) | 未檢查 |
| CPUFriendDataProvider | 1.0.1 | 不適用（本機） | 本機電源資料，來自 [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh) | 未檢查 |
| itlwm | 2.3.0 | 2.3.0 為 [OpenIntelWireless/itlwm](https://github.com/OpenIntelWireless/itlwm) 最新正式版 | release v2.3.0；資料夾內仍有，但在 `config.plist` 中**已停用**（由 AirportItlwm 取代） | 與 v2.3.0 release 相符 |

OpenCore 本體與 Drivers（`OpenCore.efi`、`BOOTx64.efi`、`OpenCanopy`、`OpenRuntime`、`ResetNvramEntry`、`ToggleSipEntry`）取自官方 [OpenCore 1.0.8](https://github.com/acidanthera/OpenCorePkg/releases/tag/1.0.8) 的 `OpenCore-1.0.8-RELEASE.zip`（sha256 `2011e8b7216ecb2645d97ea710df965947edd406846e92050b9bc4190be6d27b`）；`config.plist` 通過該版 `ocvalidate`。`HfsPlus.efi` 與 [acidanthera/OcBinaryData](https://github.com/acidanthera/OcBinaryData) master 相同。`Resources` 來自 OcBinaryData。ACPI：`DMAR.aml`、`SSDT-AWAC-HPTE`、`SSDT-EC-USBX`、`SSDT-PLUG`、`SSDT-PMC`、`SSDT-SBUS-MCHC`、`SSDT-TYPC-NUC8-BC`。

刻意不是官方穩定版者：**AirportItlwm**（laobamac 的 2.4.0-alpha 是唯一的 Tahoe 版；OpenIntelWireless/itlwm 最新為 2.3.0，沒有 Tahoe 的 AirportItlwm）與 **IntelBluetoothFirmware/IntelBTPatcher 2.5.2**（lshbluesky fork；官方 OpenIntelWireless 2.4.0 在 Tahoe 上無法載入）。SimpleHDA 為 laobamac 官方 v1.0.0 release。

## BIOS 設定

開機按 F2，先按 F9 載入預設值，再修改：

| 路徑 | 項目 | 設定 |
| --- | --- | --- |
| Advanced > Boot > Secure Boot | Secure Boot | Disabled |
| Advanced > Boot > Boot Priority | UEFI Boot / Legacy Boot | Enabled / Disabled |
| Advanced > Boot > Boot Configuration | Fast Boot、Network Boot | Disabled |
| Advanced > Devices > Video | IGD Minimum Memory | 64 MB |
| Advanced > Devices > Video | IGD Aperture Size | 256 MB |
| Advanced > Security > Security Features | Thunderbolt Security Level | 選項：Legacy Mode／Unique ID（BIOS 預設）／One time saved Key／DP++ only（依 BIOS 0098 的 UQI 清單）。**實測使用預設值 Unique ID**（搭配 SSDT-TBFP，USB-C 熱插拔與原生 NHI 可用），不需要改成 Legacy Mode |

建議：Deep S4/S5 Disabled、Wake on LAN from S4/S5 Stay Off、Intel SGX Disabled。SATA Mode 維持 AHCI。VT-d 可以開著，因為 `DisableIoMapper=true` 讓 macOS 不使用它。

## 安裝流程（摘要）

1. 產生自己的 SMBIOS 值並填進 `config.plist`（見上方警告）。
2. 用 OpenCorePkg 的 `macrecovery.py`（board `Mac-CFF7D910A743CAAF`）下載 macOS Recovery 映像，連同 `EFI` 資料夾放到 FAT32 的 EFI 分割區，可放 USB 隨身碟或目標 SSD。
3. 以 F10 開機選單從該碟開機，在 OpenCore 選單選 Recovery 項目。
4. 磁碟工具 → 顯示所有裝置 → 將目標分割區清除為 APFS。
5. 重新安裝 macOS。會下載約 15 GB，需要可用的網路（有線網路即可）。
6. 每次重開在選單選「macOS Installer」，直到它消失後改選已安裝的磁碟。
7. 把 `EFI` 複製到內建 EFI 分割區。`com.apple.recovery.boot/` 只用於安裝，已列入 `.gitignore`。

## 關鍵修正

- **`DisableIoMapper=true`**：設為 `false` 時，I219-V 的連線在 active／inactive 之間反覆跳動，始終拿不到 IPv4（IOMMU 似乎擋住了 IntelMausi 的 DMA）。成因是由「只改這一項就好了」推定，沒有修正前後的日誌。
- **`EFI/BOOT` 與 `EFI/OC` 的 `.contentVisibility`／`.contentFlavour`**：缺少時選單會把 OpenCore 自己的 `BOOTx64.efi` 列成開機項目，選了會黑畫面。請保留這些隱藏檔。
- **SimpleHDA 搭配 `layout-id` 8**（`PciRoot(0x0)/Pci(0x1F,0x3)`）：Tahoe 已不含 AppleHDA。只有 AppleALC 時沒有輸出，layout 3 則只有雜訊。
- **以 AirportItlwm 取代 itlwm + HeliPort**：可用原生 Wi‑Fi 選單與接力。切換後請檢查網路服務順序；Wi‑Fi 服務可能排在有線之前。
- **IntelBluetoothFirmware／IntelBTPatcher 2.5.x**：2.4.0 把最高核心寫死為 Sequoia，在 Tahoe 上不會載入。
- 在此設定下，`bluetoothd` 的 `codesign --verify` 可能失敗。差異頁面已追溯到 BlueToolFixup 的已知補丁；磁碟上的檔案並未被修改（在工作副本還原補丁後驗證會通過）。

## 評估中的殘留設定

`amfi=0x80` 與 `csr-active-config` = `03080000` 當初是為一條從未執行的 OCLP-Mod root patch 路線加入的，**已於 2026-10-27 移除**：`boot-args` 不再含 `amfi=0x80`，`csr-active-config` 設為 `00000000` 並列入 `NVRAM -> Delete`，即使重設 NVRAM，SIP 也維持全開。重開機後已確認 3.5mm 音效（SimpleHDA）、Wi-Fi（AirportItlwm）、藍牙、USB-C Hub 與兩台螢幕皆正常。

## 致謝與授權

- [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh)：本 repo 的起點，其 git 歷史予以保留。**七個 ACPI 表、`USBPorts.kext`、`CPUFriendDataProvider.kext`** 仍來自該 repo。
- [zearp/Nucintosh](https://github.com/zearp/Nucintosh)：NUC8 Hackintosh 的參考指南。
- [Acidanthera](https://github.com/acidanthera)：OpenCorePkg、Lilu、WhateverGreen、VirtualSMC、AppleALC、RestrictEvents、FeatureUnlock、CPUFriend、IntelMausi、BrcmPatchRAM（BlueToolFixup）、OcBinaryData。
- [Dortania build-repo](https://github.com/dortania/build-repo)：CI 建置，僅用來比對是否有比官方 release 更新的版本。
- [OpenIntelWireless](https://github.com/OpenIntelWireless)：itlwm、HeliPort、IntelBluetoothFirmware。
- laobamac：SimpleHDA 與 AirportItlwm Tahoe 版。
- lshbluesky：IntelBluetoothFirmware 2.5.x 建置。
- [0xFireWolf](https://github.com/0xFireWolf)：RealtekCardReader 與 RealtekCardReaderFriend。

本 repo 自行撰寫的部分（`config.plist` 調整、文件、腳本）採 [MIT 授權](LICENSE)。OpenCore、各 kext、驅動等第三方檔案保有各自的授權；取自 leoncdq/NUC8intosh 的 ACPI 表、`USBPorts.kext`、`CPUFriendDataProvider.kext` 不在 MIT 範圍內。
