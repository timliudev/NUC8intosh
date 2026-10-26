# Intel NUC8i7BEH (Bean Canyon) Hackintosh - macOS Tahoe 26.7.2

English | [繁體中文](README.zh-TW.md)

An OpenCore EFI for the **Intel NUC8i7BEH** running **macOS Tahoe 26.7.2 (25G330)**, plus the notes that explain how it got there.

- OpenCore **1.0.8** (Dortania build-repo, OpenCorePkg commit `64d1ed3`, built 2026-08-31)
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
| Storage | 2.5" SATA SSD | not NVMe, so NVMeFix is not used |
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
| USB-C hub with DP and camera | Works if plugged in **before boot** | **Hot-plug is under test and not confirmed.** One run showed the hub as a USB 2.0 Billboard device only when plugged in while running |
| Microphone | Untested | Input devices enumerate; no recording test |
| Sleep / wake | Untested | Auto-sleep was disabled with `pmset` during testing |
| Card reader | Not verified | Kext loads; no read/write test is documented |
| Universal Clipboard, OTA update | Untested | |
| AirDrop, AWDL | **Not supported** | No `awdl0` with this Wi-Fi driver |
| Thunderbolt (PCIe/NHI) | **Not supported** | `system_profiler` reports no Thunderbolt driver; USB and DP over USB-C go through ACPI/USB paths instead |

Intermittent USB drop-outs and `bluetoothd` crashes were seen earlier in the project. The `bluetoothd` crashes stopped after an in-place macOS reinstall; the USB root cause was never isolated (see [docs/history](docs/history/README.md)).

## Kexts

All versions below were read from the kexts' `Info.plist` files in this repo. Dortania build-repo builds are CI builds of Acidanthera master; hashes are in the install notes ([section 3.1](docs/history/01-windows-install-claude.md)).

| Kext | Version | Source |
| --- | --- | --- |
| Lilu | 1.7.3 | Dortania build-repo |
| WhateverGreen | 1.7.1 | Dortania build-repo |
| VirtualSMC, SMCProcessor, SMCSuperIO | 1.3.8 | Dortania build-repo |
| RestrictEvents | 1.1.7 | Dortania build-repo |
| FeatureUnlock | 1.1.9 | Dortania build-repo |
| CPUFriend | 1.3.1 | Dortania build-repo |
| BlueToolFixup (BrcmPatchRAM) | 2.7.3 | Dortania build-repo, BrcmPatchRAM commit `6538902` |
| AppleALC | 1.9.8 | copied from leoncdq/NUC8intosh; the repo has no recorded hash (1.9.8 was the latest upstream release at the time) |
| SimpleHDA | 1.0.0 | [laobamac/SimpleHDA](https://github.com/laobamac/SimpleHDA) v1.0.0 release; zip sha256 `89198256664078c91155d673ee7cebb08134dad1b71d5e34b0aa4ef0d4877f8f` |
| IntelMausi | 1.0.8 | [acidanthera/IntelMausi](https://github.com/acidanthera/IntelMausi) release 1.0.8 |
| AirportItlwm | 2.4.0 (alpha, commit `738d4c6`, Tahoe build) | laobamac fork of itlwm, release asset `AirportItlwm-Tahoe-v2.4.0-RELEASE-alpha-738d4c6.zip` (prerelease, 2026-10-11); sha256 `25680aa39ddd79b205141875b261bdcc28bea150d13f27787b3c215555daa00f`. The exact repository path comes from the session notes; check it before downloading |
| IntelBluetoothFirmware, IntelBTPatcher | 2.5.2 | [lshbluesky/IntelBluetoothFirmware](https://github.com/lshbluesky/IntelBluetoothFirmware) v2.5.2; zip sha256 `c26140b2091e7b41aab5e5fbdd322112908efc509f9fde3d71d4e3f91396b991` (the Tahoe-capable 2.5.0 was originally built from upstream master via CI) |
| RealtekCardReader | 0.9.7 | [0xFireWolf/RealtekCardReader](https://github.com/0xFireWolf/RealtekCardReader) release |
| RealtekCardReaderFriend | 1.0.4 | [0xFireWolf/RealtekCardReaderFriend](https://github.com/0xFireWolf/RealtekCardReaderFriend) release |
| USBPorts | 1.1 | local USB map, from leoncdq/NUC8intosh |
| CPUFriendDataProvider | 1.0.1 | local power data, from leoncdq/NUC8intosh |
| itlwm | 2.3.0 | present in the folder but **disabled** in `config.plist` (replaced by AirportItlwm) |

OpenCore binaries, drivers and `Resources` come from the OpenCore 1.0.8 release and OcBinaryData (`HfsPlus.efi`). ACPI: `DMAR.aml`, `SSDT-AWAC-HPTE`, `SSDT-EC-USBX`, `SSDT-PLUG`, `SSDT-PMC`, `SSDT-SBUS-MCHC`, `SSDT-TYPC-NUC8-BC`.

## BIOS settings

Press F2, load defaults with F9 first, then change:

| Path | Setting | Value |
| --- | --- | --- |
| Advanced > Boot > Secure Boot | Secure Boot | Disabled |
| Advanced > Boot > Boot Priority | UEFI Boot / Legacy Boot | Enabled / Disabled |
| Advanced > Boot > Boot Configuration | Fast Boot, Network Boot | Disabled |
| Advanced > Devices > Video | IGD Minimum Memory | 64 MB |
| Advanced > Devices > Video | IGD Aperture Size | 256 MB |
| Advanced > Devices > Onboard Devices (or Security) | Thunderbolt Security Level | Legacy Mode |

Recommended: Deep S4/S5 Disabled, Wake on LAN from S4/S5 Stay Off, Intel SGX Disabled. Keep SATA Mode = AHCI. VT-d may stay on because `DisableIoMapper=true` keeps macOS from using it.

## Install flow (summary)

The full account, including the Windows scripts used to prepare a single SSD, is in [docs/history/01-windows-install-claude.md](docs/history/01-windows-install-claude.md).

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

`amfi=0x80` in `boot-args` and `csr-active-config` = `03080000` in `NVRAM` were added for an OCLP-Mod root-patch route that was never run. They are **leftovers**, their necessity has not been evaluated, and they weaken security checks. At the last check, the live NVRAM still reported `csr-active-config` as `00000000` (SIP enabled), because the older value was not deleted. Review and remove them if you do not need them; test after any change. The other `boot-args` (`keepsyms=1 debug=0x100 revpatch=sbvmm revcpu=1 revcpuname=...`) and `ProtocolOverrides` are kept exactly as tested.

## More documentation

[docs/history](docs/history/README.md) holds de-identified build and troubleshooting notes from several AI-assisted sessions (Claude, Codex, Antigravity). Some conclusions in them were later overturned; each file marks what is verified and what is not.

## Credits and licensing

- [leoncdq/NUC8intosh](https://github.com/leoncdq/NUC8intosh): the starting point of this repo. Git history from that repo is kept. The **seven ACPI tables, `USBPorts.kext` and `CPUFriendDataProvider.kext`** still come from it. **That repository has no license, and permission to reuse these files is being requested.** Until it is granted, treat those files as not yet cleared for redistribution.
- [zearp/Nucintosh](https://github.com/zearp/Nucintosh): the reference NUC8 Hackintosh guide.
- [Acidanthera](https://github.com/acidanthera): OpenCorePkg, Lilu, WhateverGreen, VirtualSMC, AppleALC, RestrictEvents, FeatureUnlock, CPUFriend, IntelMausi, BrcmPatchRAM (BlueToolFixup), OcBinaryData.
- [Dortania build-repo](https://github.com/dortania/build-repo): CI builds used for most kexts and OpenCore.
- [OpenIntelWireless](https://github.com/OpenIntelWireless): itlwm, HeliPort, IntelBluetoothFirmware.
- laobamac: SimpleHDA and the AirportItlwm Tahoe build.
- lshbluesky: the IntelBluetoothFirmware 2.5.x builds.
- [0xFireWolf](https://github.com/0xFireWolf): RealtekCardReader and RealtekCardReaderFriend.

No license file is included yet. Third-party binaries keep their own licenses.
