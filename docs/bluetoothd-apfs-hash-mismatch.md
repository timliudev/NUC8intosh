# bluetoothd 反覆 SIGBUS：APFS 壓縮雜湊錯誤（2026-10-27 調查）

macOS 26.7.2（25G332）、BlueToolFixup 2.7.2、IntelBluetoothFirmware／IntelBTPatcher 2.5.2、Lilu 1.7.3、SIP 全開。

## 症狀

- 藍牙整個消失，USB 正常。藍牙 USB 控制器（`Bluetooth USB Host Controller@14500000`）仍在，三個藍牙 kext 都有載入。
- `bluetoothd` 不在執行；`launchctl print system/com.apple.bluetoothd` 顯示 `state = spawn scheduled`，`sudo launchctl kickstart -k` 會一直卡住（launchd log：`launch already in progress`）。
- 只有重開機能恢復。

## 時間軸（10-27 這次）

- 13:24 開機。
- 13:56:48 已跑 32 分鐘的 `bluetoothd`（pid 166）SIGBUS；同一毫秒 kernel 記：
  `apfs_pagein: disk2s1 ino 1152921500312575936 ... f_offset 1990656 size 4096 file size 0 error 94 (bluetoothd)`
- 13:56:48～13:58:49 launchd 重啟 14 次，每次 30～300 ms 內死在同樣的 pagein 錯誤；log 有 `Too many corpses being created`。
- 13:58:49 之後 launchd 不再有任何 bluetoothd 紀錄，一直停在 `spawn scheduled`（15:26 起只記 `cannot spawn: service is throttled`）。

## 證據

- `error 94` = `EBADMSG`。ino `1152921500312575936` 就是 `/usr/sbin/bluetoothd`（`stat -f %i` 對過），在 sealed 系統卷上、旗標 `restricted,compressed`。
- 今天 log 中全部 `apfs_pagein` 錯誤（約 55 筆）都是這個檔，讀取者只有 `bluetoothd` 與讀它的 `ReportCrash`。沒有其他檔案出錯，不像 SSD 壞。
- 10-23 以來 23 份 crash 報告全部是 `EXC_BAD_ACCESS / KERN_MEMORY_ERROR`，故障位址都落在 bluetoothd 自己的映像內，堆疊位置隨機（objc、mach_msg、dyld）——是讀到某頁時才炸，不是程式邏輯錯。10-23 的報告 ktriage 寫明 `Encountered a compressed data hash mismatch`／`Pagein of compressed inode failed`。
- 出錯頁與 BlueToolFixup 補丁頁的對照（x86_64 slice 位於檔案 offset 16384；頁大小 4 KiB；APFS 壓縮區塊 64 KiB）：

  | crash 位址的 slice 內頁號 | BlueToolFixup 補丁頁（Codex 10-26 逐頁比對 CodeDirectory） | 檔案 offset 所屬 64 KiB 區塊 |
  | --- | --- | --- |
  | 235（`0xebd6f`） | 233 | `0x0E0000` |
  | 482（`0x1e2415`；pagein `f_offset 1990656`） | 483 | `0x1E0000` |
  | 825（`0x339b50`；pagein `f_offset 3395584`） | 827 | `0x330000` |
  | 890（`0x37ad9a`；pagein `f_offset 3661824`） | 889 | `0x370000` |

  四組全部「出錯頁 ≠ 補丁頁，但同一個 64 KiB 壓縮區塊」。
- 15:3x（bluetoothd 停止期間）逐頁比對 x86_64 slice 2885 頁的 SHA-256 與 CodeDirectory：全部相符，檔案本身沒壞。

## 推論（未證實）

APFS 讀壓縮檔時會把整個 64 KiB 區塊解壓後一起驗雜湊。Lilu／BlueToolFixup 在記憶體裡改了 bluetoothd 的某頁；記憶體吃緊（當時 swap 已用 1 GB）時，同區塊的其他頁被換出、補丁頁還留著，之後重新讀入時把「被改過的頁」一起拿去驗 → hash mismatch → `EBADMSG` → SIGBUS。補丁頁一直留在快取裡，所以之後每次重啟都死在同一處，直到重開機。

這也說明為什麼要開機一段時間才出事、為什麼重啟服務沒用。

## 上游前例（都沒有人診斷，都已關閉）

- [OpenIntelWireless/IntelBluetoothFirmware#493](https://github.com/OpenIntelWireless/IntelBluetoothFirmware/issues/493)：Sonoma 14.4.1、AX210、bluetoothd SIGBUS，ktriage 與本機一字不差。
- [acidanthera/bugtracker#2228](https://github.com/acidanthera/bugtracker/issues/2228)：ControlCenter 同樣錯誤，環境有 FeatureUnlock（也是 Lilu 使用者空間補丁）。
- [dortania/bugtracker#329](https://github.com/dortania/bugtracker/issues/329)、[MacRumors 討論串](https://forums.macrumors.com/threads/macos-ventura-13-on-unsupported-macs-using-command-button-or-arrow-buttons-in-apps-causes-them-to-crash.2375101/)：OCLP 機器多個 App 同樣錯誤，重開機撐 10～15 小時。

共通點：都有 Lilu 在使用者空間改 macOS 系統程式。

## 處置

- 發生時：Ctrl+C 中斷卡住的 `kickstart`，重開機。
- 根治方法：沒有上游修正；選項（`sudo purge` 實驗、偵測提醒、fork BlueToolFixup 等）與評估見 [bluetoothd-fix-research.md](bluetoothd-fix-research.md)。新的 IntelBTUnified 用同一個 `_cs_validate_page` 手法，換過去不會好。

## 調查用到的指令

```bash
launchctl print system/com.apple.bluetoothd | grep -E "state|runs"
/usr/bin/log show --last 30m --style compact --predicate 'process == "kernel" AND eventMessage CONTAINS "apfs_pagein"'
lipo -detailed_info /usr/sbin/bluetoothd
```

（zsh 的 `log` 是內建指令，要寫 `/usr/bin/log`。）
