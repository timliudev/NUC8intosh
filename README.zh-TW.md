# Intel NUC8i7BEH (Bean Canyon) Hackintosh - macOS Tahoe 26.7.2

[English](README.md) | 繁體中文

適用於 **Intel NUC8i7BEH** 的 OpenCore EFI，目前在 **macOS Tahoe 26.7.2 (25G330)** 上使用，並附上完整的建置與除錯紀錄。

- OpenCore **1.0.8**（Dortania build-repo，OpenCorePkg commit `64d1ed3`，2026-08-31 建置）
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
| USB-C Hub（DP 與攝影機） | **開機前已插著**時可用 | **熱插拔仍在測試，未確認。** 有一次在系統運行中才插入，Hub 只以 USB 2.0 Billboard 裝置出現 |
| 麥克風 | 未測 | 輸入裝置有列舉，沒做錄音測試 |
| 睡眠／喚醒 | 未測 | 測試期間以 `pmset` 停用了自動睡眠 |
| 讀卡機 | 正常 | 256 GB SDXC 卡掛載為「Built In SDXC Reader」；32 MB 寫入後讀回雜湊相符（2026-10-27） |
| 通用剪貼簿、OTA 更新 | 未測 | |
| AirDrop、AWDL | **不支援** | 此 Wi‑Fi 驅動沒有 `awdl0` |
| Thunderbolt（PCIe／NHI） | **不支援** | USB-C 埠由 JHL6340（Alpine Ridge）控制。macOS 看得到它的橋接器（`8086:15DA`）與 USB 控制器（`8086:15DB`，`AppleUSBXHCIAR`），所以 USB 與 DP alt-mode 可用；但 Thunderbolt NHI（`15D9`）沒出現，`system_profiler` 顯示沒有 Thunderbolt 驅動，真正的 Thunderbolt 裝置預期無法使用 |

專案早期曾出現 USB 間歇失效與 `bluetoothd` 崩潰。`bluetoothd` 崩潰在原地重裝 macOS 後不再出現；USB 的根因未能釐清（見 [docs/history](docs/history/README.md)）。

## Kext

下列版本均讀自本 repo 內各 kext 的 `Info.plist`。Dortania build-repo 的建置是 Acidanthera master 的 CI 編譯；雜湊見安裝紀錄 [第 3.1 節](docs/history/01-windows-install-claude.md)。

| Kext | 版本 | 來源 |
| --- | --- | --- |
| Lilu | 1.7.3 | Dortania build-repo |
| WhateverGreen | 1.7.1 | Dortania build-repo |
| VirtualSMC、SMCProcessor、SMCSuperIO | 1.3.8 | Dortania build-repo |
| RestrictEvents | 1.1.7 | Dortania build-repo |
| FeatureUnlock | 1.1.9 | Dortania build-repo |
| CPUFriend | 1.3.1 | Dortania build-repo |
| BlueToolFixup（BrcmPatchRAM） | 2.7.3 | Dortania build-repo，BrcmPatchRAM commit `6538902` |
| AppleALC | 1.9.8 | 複製自 leoncdq/NUC8intosh，無留存雜湊（當時為上游最新正式版） |
| SimpleHDA | 1.0.0 | [laobamac/SimpleHDA](https://github.com/laobamac/SimpleHDA) v1.0.0 release；zip sha256 `89198256664078c91155d673ee7cebb08134dad1b71d5e34b0aa4ef0d4877f8f` |
| IntelMausi | 1.0.8 | [acidanthera/IntelMausi](https://github.com/acidanthera/IntelMausi) release 1.0.8 |
| AirportItlwm | 2.4.0（alpha，commit `738d4c6`，Tahoe 版） | laobamac 的 itlwm 分支，release 檔案 `AirportItlwm-Tahoe-v2.4.0-RELEASE-alpha-738d4c6.zip`（prerelease，2026-10-11）；sha256 `25680aa39ddd79b205141875b261bdcc28bea150d13f27787b3c215555daa00f`。確切 repo 路徑來自 session 紀錄，下載前請自行確認 |
| IntelBluetoothFirmware、IntelBTPatcher | 2.5.2 | [lshbluesky/IntelBluetoothFirmware](https://github.com/lshbluesky/IntelBluetoothFirmware) v2.5.2；zip sha256 `c26140b2091e7b41aab5e5fbdd322112908efc509f9fde3d71d4e3f91396b991`（支援 Tahoe 的 2.5.0 最初是以 CI 從上游 master 編出） |
| RealtekCardReader | 0.9.7 | [0xFireWolf/RealtekCardReader](https://github.com/0xFireWolf/RealtekCardReader) release |
| RealtekCardReaderFriend | 1.0.4 | [0xFireWolf/RealtekCardReaderFriend](https://github.com/0xFireWolf/RealtekCardReaderFriend) release |
| USBPorts | 1.1 | 本機 USB 對應表，來自 leoncdq/NUC8intosh |
| CPUFriendDataProvider | 1.0.1 | 本機電源資料，來自 leoncdq/NUC8intosh |
| itlwm | 2.3.0 | 資料夾內仍有，但在 `config.plist` 中**已停用**（由 AirportItlwm 取代） |

OpenCore 本體、Drivers 與 `Resources` 來自 OpenCore 1.0.8 release 與 OcBinaryData（`HfsPlus.efi`）。ACPI：`DMAR.aml`、`SSDT-AWAC-HPTE`、`SSDT-EC-USBX`、`SSDT-PLUG`、`SSDT-PMC`、`SSDT-SBUS-MCHC`、`SSDT-TYPC-NUC8-BC`。

## BIOS 設定

開機按 F2，先按 F9 載入預設值，再修改：

| 路徑 | 項目 | 設定 |
| --- | --- | --- |
| Advanced > Boot > Secure Boot | Secure Boot | Disabled |
| Advanced > Boot > Boot Priority | UEFI Boot / Legacy Boot | Enabled / Disabled |
| Advanced > Boot > Boot Configuration | Fast Boot、Network Boot | Disabled |
| Advanced > Devices > Video | IGD Minimum Memory | 64 MB |
| Advanced > Devices > Video | IGD Aperture Size | 256 MB |
| Advanced > Devices > Onboard Devices（或 Security） | Thunderbolt Security Level | Legacy Mode |

建議：Deep S4/S5 Disabled、Wake on LAN from S4/S5 Stay Off、Intel SGX Disabled。SATA Mode 維持 AHCI。VT-d 可以開著，因為 `DisableIoMapper=true` 讓 macOS 不使用它。

## 安裝流程（摘要）

完整過程（包含在 Windows 準備單顆 SSD 的腳本）見 [docs/history/01-windows-install-claude.md](docs/history/01-windows-install-claude.md)。

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

`boot-args` 中的 `amfi=0x80`，以及 NVRAM 中的 `csr-active-config` = `03080000`，是為了一條從未執行的 OCLP-Mod root patch 路線而加入的。它們是**殘留設定**，必要性尚未評估，也會削弱安全檢查。最後一次檢查時，實際 NVRAM 的 `csr-active-config` 仍是 `00000000`（SIP 開啟），因為舊值沒有被刪除。若不需要請自行評估後移除，每次改動後都要重新測試。其餘 `boot-args`（`keepsyms=1 debug=0x100 revpatch=sbvmm revcpu=1 revcpuname=...`）與 `ProtocolOverrides` 維持實測時的原樣。

## 更多文件

[docs/history](docs/history/README.md) 收錄多個 AI 輔助 session（Claude、Codex、Antigravity）的建置與除錯紀錄，已去識別化。其中部分結論後來被推翻，各檔案都標示了哪些已驗證、哪些未驗證。

## 致謝與授權

- [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh)：本 repo 的起點，其 git 歷史予以保留。**七個 ACPI 表、`USBPorts.kext`、`CPUFriendDataProvider.kext`** 仍來自該 repo。
- [zearp/Nucintosh](https://github.com/zearp/Nucintosh)：NUC8 Hackintosh 的參考指南。
- [Acidanthera](https://github.com/acidanthera)：OpenCorePkg、Lilu、WhateverGreen、VirtualSMC、AppleALC、RestrictEvents、FeatureUnlock、CPUFriend、IntelMausi、BrcmPatchRAM（BlueToolFixup）、OcBinaryData。
- [Dortania build-repo](https://github.com/dortania/build-repo)：多數 kext 與 OpenCore 使用的 CI 建置。
- [OpenIntelWireless](https://github.com/OpenIntelWireless)：itlwm、HeliPort、IntelBluetoothFirmware。
- laobamac：SimpleHDA 與 AirportItlwm Tahoe 版。
- lshbluesky：IntelBluetoothFirmware 2.5.x 建置。
- [0xFireWolf](https://github.com/0xFireWolf)：RealtekCardReader 與 RealtekCardReaderFriend。

本 repo 自行撰寫的部分（`config.plist` 調整、文件、腳本）採 [MIT 授權](LICENSE)。OpenCore、各 kext、驅動等第三方檔案保有各自的授權；取自 leoncdq/NUC8intosh 的 ACPI 表、`USBPorts.kext`、`CPUFriendDataProvider.kext` 不在 MIT 範圍內。
