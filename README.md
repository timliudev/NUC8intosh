# Intel NUC8i7BEH (Bean Canyon) Hackintosh - macOS Tahoe 26.7.2

English | [繁體中文](README.zh-TW.md)

An OpenCore EFI for the **Intel NUC8i7BEH** running **macOS Tahoe 26.7.2 (25G330)**, plus the notes that explain how it got there.

- OpenCore **1.0.8** (official release, 2026-09-27; `OpenCore.efi`, `BOOTx64.efi` and the OpenCore drivers are from the official `OpenCore-1.0.8-RELEASE.zip`)
- SMBIOS: `iMac20,2`
- This is a personal, hand-tested setup, not a turnkey release. Read "What works / what does not" before relying on it.

> **Before you boot: generate your own SMBIOS.** `PlatformInfo.Generic` in `EFI/OC/config.plist` ships with an **empty** `SystemSerialNumber`, `MLB`, `SystemUUID` and `ROM`. Generate a set for `iMac20,2` with [macserial](https://github.com/acidanthera/OpenCorePkg/tree/master/Utilities/macserial) (`./macserial -m iMac20,2 -g -n 1`), make a random `SystemUUID` (`uuidgen`), and set `ROM` (for example to your NIC's MAC address bytes). Never reuse someone else's values and never publish yours.

## Hardware

| Part | Model | Notes |
| --- | --- | --- |
| Machine | Intel NUC8i7BEH (Bean Canyon) | BIOS 0095 or newer recommended |
| CPU | Intel Core i7-8559U (Coffee Lake) | |
| iGPU | Intel Iris Plus Graphics 655 | `AAPL,ig-platform-id` = `0x3EA50004` |
| RAM | 16 GB + 4 GB | asymmetric dual channel, works |
| Storage | Crucial MX500 500 GB, M.2 2280 **SATA** | not NVMe, so NVMeFix is not used. NVMe drives work natively; NVMeFix is optional (power management for non-Apple NVMe) |
| Ethernet | Intel I219-V | IntelMausi |
| Wi-Fi | Intel Wireless-AC 9560 (PCI `8086:9DF0`) | AirportItlwm (native Wi-Fi menu) |
| Bluetooth | Intel (USB, part of the 9560) | IntelBluetoothFirmware |
| Audio | Realtek ALC235 | SimpleHDA + AppleALC, layout-id 8 |
| Card reader | Realtek RTS522A | RealtekCardReader |

## Status

Tested on macOS 26.7.2 (25G330). "User-confirmed" means the owner of this machine tried it by hand; it is not a benchmark.

| Feature | Status | Evidence / caveat |
| --- | --- | --- |
| Boot, install, graphics acceleration | Works | Metal 3 acceleration confirmed at install time (26.6.2) |
| Ethernet (I219-V) | Works | Needs `DisableIoMapper=true` (see below) |
| Wi-Fi | Works | AirportItlwm, system Wi-Fi menu, WPA2 and a ping test confirmed. Alpha-quality kext; 5 GHz under load, Wi-Fi 6 and long-term stability untested |
| Handoff | Works | User-confirmed |
| Bluetooth | Works | IntelBluetoothFirmware 2.5.2; A2DP/HFP to a Bluetooth DAC user-confirmed |
| 3.5 mm audio output | Works | SimpleHDA with layout-id 8, user-confirmed. layout-id 3 produced only noise |
| USB audio | Works | User-confirmed |
| USB-C hub with DP and camera | Works, **hot-plug included** (with SSDT-TBFP) | Tested 2026-10-27: booted with nothing on USB-C, then plugged the hub in; USB cameras enumerated. The DP monitor needed one DP-cable re-plug on the first attempt; repeat tests pending. Hub attached at boot also works |
| Microphone | Untested | Input devices enumerate; no recording test |
| Sleep / wake | **Not tested, kept disabled** | `pmset sleep 0`. No public reports of NUC8 sleep on Sonoma+ or with Thunderbolt force-power; known Tahoe wake issues in AirportItlwm ([laobamac/itlwm#19](https://github.com/laobamac/itlwm/issues/19), fix `2d3e797` not in the shipped build) and IntelBluetoothFirmware ([#484](https://github.com/OpenIntelWireless/IntelBluetoothFirmware/issues/484)) |
| Card reader | Works | 256 GB SDXC card mounts as "Built In SDXC Reader"; 32 MB write/read-back checksum matched (2026-10-27) |
| OTA update | Works | 25G325 → 25G330 via Software Update (`revpatch=sbvmm` + RestrictEvents) |
| Universal Clipboard | Untested | |
| AirDrop, AWDL | **Not supported** | No `awdl0` with this Wi-Fi driver |
| Thunderbolt (native) | **Partial / experimental** | JHL6340 (Alpine Ridge), firmware **not** flashed. With SSDT-TBFP the NHI (`8086:15D9`) appears and `AppleThunderboltNHIType3` loads; Thunderbolt devices themselves are untested. Flashing the controller firmware ([osy/ThunderboltPatcher](https://github.com/osy/ThunderboltPatcher)) is **not pursued**: on NUC8 it causes wake-from-sleep panics and unstable USB-C with no fix since 2021 ([zearp/Nucintosh#174](https://github.com/zearp/Nucintosh/issues/174)) |

Intermittent USB drop-outs and `bluetoothd` crashes were seen earlier in the project. The `bluetoothd` crashes stopped after an in-place macOS reinstall; the USB root cause was never isolated.

## Kexts

All versions below were read from the kexts' `Info.plist` files in this repo. "Latest" was checked on 2026-10-27 against GitHub releases and [Dortania build-repo](https://github.com/dortania/build-repo). Policy: use the **official latest release** whenever one exists; every official zip's sha256 was checked against the GitHub asset digest and the executable's sha256 was compared with the installed file. Dev builds (Dortania) are no longer used. Where the official release is *older* than the previous dev build, the reason is in the table.

| Kext | Installed | Latest available (checked 2026-10-27) | Source | Binary |
| --- | --- | --- | --- | --- |
| [Lilu](https://github.com/acidanthera/Lilu) | 1.7.2 | 1.7.2 is the official latest (2026-03-20); master is 1.7.3 | Official [1.7.2](https://github.com/acidanthera/Lilu/releases/tag/1.7.2) `Lilu-1.7.2-RELEASE.zip` | matches. Was dev 1.7.3; 1.7.3 adds only a Tiger Lake-H CPU model (+ analyzer fix, not released), irrelevant to Coffee Lake. 1.7.1 already allows loading on macOS 26 without `-lilubetaall`; every kext here needs Lilu ≥1.2.0 (SimpleHDA ≥1.7.1), so 1.7.2 suffices |
| [WhateverGreen](https://github.com/acidanthera/WhateverGreen) | 1.7.1 | 1.7.1 is the official latest (2026-09-27) | Official [1.7.1](https://github.com/acidanthera/WhateverGreen/releases/tag/1.7.1) `WhateverGreen-1.7.1-RELEASE.zip` | matches (replaced a dev build) |
| [VirtualSMC](https://github.com/acidanthera/VirtualSMC), SMCProcessor, SMCSuperIO | 1.3.8 | 1.3.8 is the official latest (2026-09-27) | Official [1.3.8](https://github.com/acidanthera/VirtualSMC/releases/tag/1.3.8) `VirtualSMC-1.3.8-RELEASE.zip` | matches (replaced a dev build) |
| [RestrictEvents](https://github.com/acidanthera/RestrictEvents) | 1.1.6 | 1.1.6 is the official latest (2025-07-07) | Official [1.1.6](https://github.com/acidanthera/RestrictEvents/releases/tag/1.1.6) | matches. Was dev 1.1.7: The dev "newer" version is only a post-release `Bump version` commit (project file only); no code change |
| [FeatureUnlock](https://github.com/acidanthera/FeatureUnlock) | 1.1.8 | 1.1.8 is the official latest (2025-07-07) | Official [1.1.8](https://github.com/acidanthera/FeatureUnlock/releases/tag/1.1.8) | matches. Was dev 1.1.9: The dev "newer" version is only a post-release `Bump version` commit (project file only); no code change |
| [CPUFriend](https://github.com/acidanthera/CPUFriend) | 1.3.0 | 1.3.0 is the official latest (2025-07-07) | Official [1.3.0](https://github.com/acidanthera/CPUFriend/releases/tag/1.3.0) | matches. Was dev 1.3.1: The dev "newer" version is only a post-release `Bump version` commit (project file only); no code change |
| BlueToolFixup ([BrcmPatchRAM](https://github.com/acidanthera/BrcmPatchRAM)) | 2.7.2 | 2.7.2 is the official latest (2026-03-20) | Official [2.7.2](https://github.com/acidanthera/BrcmPatchRAM/releases/tag/2.7.2) `BrcmPatchRAM-2.7.2-RELEASE.zip` | matches. Was dev 2.7.3: only a `Bump version` commit (project and injector Info.plists, not BlueToolFixup code) |
| [AppleALC](https://github.com/acidanthera/AppleALC) | 1.9.8 | 1.9.8 is the official latest (2026-09-27) | Official [1.9.8](https://github.com/acidanthera/AppleALC/releases/tag/1.9.8) `AppleALC-1.9.8-RELEASE.zip` | matches (replaced a 2026-03 dev build) |
| [SimpleHDA](https://github.com/laobamac/SimpleHDA) | 1.0.0 | 1.0.0 (v1.0.0, 2026-10-14) is the latest | laobamac/SimpleHDA v1.0.0 `SimpleHDA-Tahoe-v1.0.0-RELEASE.zip`; zip sha256 `89198256664078c91155d673ee7cebb08134dad1b71d5e34b0aa4ef0d4877f8f` | matches |
| [IntelMausi](https://github.com/acidanthera/IntelMausi) | 1.0.8 | 1.0.8 is the latest (no newer commits since 2024-12) | release 1.0.8 | matches |
| [AirportItlwm](https://github.com/laobamac/itlwm) | 2.4.0 (alpha, commit `738d4c6`, Tahoe build) | 2.4.0-alpha is the latest; no stable release | [laobamac/itlwm](https://github.com/laobamac/itlwm/releases/tag/v2.4.0-alpha) (not a fork; prerelease 2026-10-11), asset `AirportItlwm-Tahoe-v2.4.0-RELEASE-alpha-738d4c6.zip`; sha256 `25680aa39ddd79b205141875b261bdcc28bea150d13f27787b3c215555daa00f` | matches |
| IntelBluetoothFirmware, IntelBTPatcher | 2.5.2 | 2.5.2 (2026-10-18) is the latest of the fork; [OpenIntelWireless](https://github.com/OpenIntelWireless/IntelBluetoothFirmware) upstream's latest release is still 2.4.0, no 2.5.x | [lshbluesky/IntelBluetoothFirmware](https://github.com/lshbluesky/IntelBluetoothFirmware) v2.5.2, a fork of OpenIntelWireless (7 commits ahead, 0 behind); zip sha256 `c26140b2091e7b41aab5e5fbdd322112908efc509f9fde3d71d4e3f91396b991` | matches |
| [RealtekCardReader](https://github.com/0xFireWolf/RealtekCardReader) | 0.9.7 | 0.9.7 is the latest | release 0.9.7 (`006a845`) | matches |
| [RealtekCardReaderFriend](https://github.com/0xFireWolf/RealtekCardReaderFriend) | 1.0.4 | 1.0.4 is the latest | release 1.0.4 (`e1e3301`) | matches |
| USBPorts | 1.1 | n/a (local) | local USB map, from [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh) | not checked |
| CPUFriendDataProvider | 1.0.1 | n/a (local) | local power data, from [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh) | not checked |
| itlwm | 2.3.0 | 2.3.0 is the latest stable of [OpenIntelWireless/itlwm](https://github.com/OpenIntelWireless/itlwm) | release v2.3.0; present but **disabled** in `config.plist` (replaced by AirportItlwm) | matches the v2.3.0 release |

OpenCore binaries and drivers (`OpenCore.efi`, `BOOTx64.efi`, `OpenCanopy`, `OpenRuntime`, `ResetNvramEntry`, `ToggleSipEntry`) are from the official [OpenCore 1.0.8](https://github.com/acidanthera/OpenCorePkg/releases/tag/1.0.8) `OpenCore-1.0.8-RELEASE.zip` (sha256 `2011e8b7216ecb2645d97ea710df965947edd406846e92050b9bc4190be6d27b`); `config.plist` passes the release's `ocvalidate`. `HfsPlus.efi` is identical to [acidanthera/OcBinaryData](https://github.com/acidanthera/OcBinaryData) master. `Resources` come from OcBinaryData. ACPI: `DMAR.aml`, `SSDT-AWAC-HPTE`, `SSDT-EC-USBX`, `SSDT-PLUG`, `SSDT-PMC`, `SSDT-SBUS-MCHC`, `SSDT-TYPC-NUC8-BC`.

Not official-stable on purpose: **AirportItlwm** (laobamac's 2.4.0-alpha is the only Tahoe build; OpenIntelWireless/itlwm's latest is 2.3.0 and has no Tahoe AirportItlwm) and **IntelBluetoothFirmware/IntelBTPatcher 2.5.2** (lshbluesky fork; the official OpenIntelWireless 2.4.0 does not load on Tahoe). SimpleHDA is laobamac's official v1.0.0 release.

## BIOS settings

Tested on **BIOS BECFL357.86A.0098** (2026-10-27; upgraded from 0095 with F7). Press F2, load defaults with F9, then set:

| Path | Setting | Value |
| --- | --- | --- |
| Advanced > Boot > Secure Boot | Secure Boot | Disabled |
| Advanced > Boot > Boot Priority | UEFI Boot / Legacy Boot | Enabled / Disabled |
| Advanced > Boot > Boot Configuration | Fast Boot, Network Boot | Disabled |
| Advanced > Devices > Video | IGD Minimum Memory | 64 MB |
| Advanced > Devices > Video | IGD Aperture Size | 256 MB |
| Advanced > Security > Security Features | Thunderbolt Security Level | Options: Legacy Mode / Unique ID (BIOS default) / One time saved Key / DP++ only (from the BIOS 0098 UQI list). **Tested with the default, Unique ID** (USB-C hot-plug and native NHI work with SSDT-TBFP). Legacy Mode is not needed |

SATA Mode stays AHCI (default). VT-d may stay on because `DisableIoMapper=true` keeps macOS from using it. Other NUC8 guides also set Deep S4/S5 Disabled, Wake on LAN from S4/S5 Stay Off and Intel SGX Disabled; this build did not verify whether those matter.

## Install flow (summary)

1. Generate your SMBIOS values and put them in `config.plist` (see the warning above).
2. Download a macOS Recovery image with OpenCorePkg's `macrecovery.py` (board `Mac-CFF7D910A743CAAF`) and place it with the `EFI` folder on a FAT32 EFI partition, either on a USB stick or on the target SSD.
3. Boot it (F10 boot menu), choose the Recovery entry in the OpenCore picker.
4. In Disk Utility, show all devices and erase the target volume as APFS.
5. Reinstall macOS. It downloads about 15 GB, so Ethernet or a working network is required.
6. After each reboot pick "macOS Installer" until it disappears, then boot the installed volume.
7. Copy `EFI` to the internal EFI partition. `com.apple.recovery.boot/` is only for installing and is git-ignored.

## Key fixes

- **`DisableIoMapper=true`**: with it set to `false`, the I219-V link flapped between active and inactive and never got IPv4 (the IOMMU appeared to block IntelMausi DMA). The cause is inferred from the fact that this one change fixed it; no before/after logs were kept.
- **`.contentVisibility` / `.contentFlavour`** in `EFI/BOOT` and `EFI/OC`: without them the picker lists OpenCore's own `BOOTx64.efi` as a boot entry, and selecting it gives a black screen. Keep these hidden files.
- **SimpleHDA with `layout-id` 8** (`PciRoot(0x0)/Pci(0x1F,0x3)`): Tahoe no longer ships AppleHDA. AppleALC alone gave no output, and layout 3 gave noise.
- **AirportItlwm instead of itlwm + HeliPort**: gives the native Wi-Fi menu and Handoff. After switching, check network service order; the Wi-Fi service may take priority over Ethernet.
- **IntelBluetoothFirmware / IntelBTPatcher 2.5.x**: 2.4.0 hard-codes Sequoia as its maximum kernel and does not load on Tahoe.
- `codesign --verify` of `bluetoothd` can fail on this setup. The differing pages were traced to BlueToolFixup's known patches; the file on disk was not modified (reverting the patches on a working copy made verification pass).

## Leftovers under evaluation

`amfi=0x80` and `csr-active-config` = `03080000` were once added for an OCLP-Mod root-patch route that was never run. Both were **removed on 2026-10-27**: `boot-args` no longer contains `amfi=0x80`, and `csr-active-config` is `00000000` and listed under `NVRAM -> Delete`, so SIP stays fully enabled even after an NVRAM reset. After a reboot, 3.5 mm audio (SimpleHDA), Wi-Fi (AirportItlwm), Bluetooth, the USB-C hub and both displays were confirmed working.

## Credits and licensing

- [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh): the starting point of this repo. Git history from that repo is kept. The **seven ACPI tables, `USBPorts.kext` and `CPUFriendDataProvider.kext`** still come from it.
- [zearp/Nucintosh](https://github.com/zearp/Nucintosh): the reference NUC8 Hackintosh guide.
- [Acidanthera](https://github.com/acidanthera): OpenCorePkg, Lilu, WhateverGreen, VirtualSMC, AppleALC, RestrictEvents, FeatureUnlock, CPUFriend, IntelMausi, BrcmPatchRAM (BlueToolFixup), OcBinaryData.
- [Dortania build-repo](https://github.com/dortania/build-repo): CI builds, used only to check what is newer than the official releases.
- [OpenIntelWireless](https://github.com/OpenIntelWireless): itlwm, HeliPort, IntelBluetoothFirmware.
- laobamac: SimpleHDA and the AirportItlwm Tahoe build.
- lshbluesky: the IntelBluetoothFirmware 2.5.x builds.
- [0xFireWolf](https://github.com/0xFireWolf): RealtekCardReader and RealtekCardReaderFriend.

The [MIT License](LICENSE) covers the files written for this repo: the `config.plist` changes, documentation and scripts. OpenCore, the kexts, drivers and other third-party files keep their own licenses, and the ACPI tables, `USBPorts.kext` and `CPUFriendDataProvider.kext` taken from leoncdq/NUC8intosh are not covered by it.
