# Pop!_OS Dual-Boot Plan (Dedicated E: SSD)

## Goal
Install Pop!_OS on a dedicated SSD currently labeled `E:` in Windows, while keeping the Windows system drive untouched and bootable.

## Current Assumption
- `E:` is a separate physical SSD (confirmed).
- Windows is already installed and working.
- Install target: only the `E:` SSD.

## Pre-Install Checklist (Windows)
1. Back up anything on `E:` (it will be repartitioned/formatted).
2. Disable Fast Startup:
   - Control Panel -> Power Options -> Choose what the power buttons do.
3. If BitLocker is enabled on Windows system drive:
   - Suspend BitLocker before install.
4. Confirm boot mode is UEFI:
   - `msinfo32` -> BIOS Mode = `UEFI`.
5. Keep a Windows recovery USB available.

## Installer Media
1. Download latest Pop!_OS ISO.
2. Create bootable USB with Rufus or BalenaEtcher.
3. If using Rufus, choose GPT + UEFI target.

## Booting the Installer
1. Enter one-time boot menu (F12/F11/Esc/Del depending motherboard).
2. Select the USB entry labeled UEFI.
3. Do not boot installer in Legacy/CSM mode.

## Partitioning Strategy (Custom/Advanced Install)
Use custom partitioning and target only the `E:` SSD.

- Reuse existing EFI System Partition (ESP):
  - Usually FAT32, 100-500 MB, typically on Windows disk.
  - Mount as `/boot/efi`.
  - **Do not format**.
- Create Linux partitions on `E:` SSD only:
  - Root `/` -> ext4
  - Swap -> linux-swap
  - Optional `/home` -> ext4

## Partition Templates by SSD Size

### 256 GB SSD (E:)
- `/` (ext4): 100 GB
- `swap`: 8-16 GB
- `/home` (ext4): remainder

### 512 GB SSD (E:)
- `/` (ext4): 150 GB
- `swap`: 16 GB
- `/home` (ext4): remainder (~346 GB)

### 1 TB SSD (E:)
- `/` (ext4): 200 GB
- `swap`: 16-32 GB
- `/home` (ext4): remainder (~768+ GB)

### Swap Sizing Rule
- General use: 8-16 GB.
- If hibernation is required: set swap >= RAM.

## Critical Safety Checks Before Clicking Install
1. Confirm selected install disk model/size matches `E:` SSD.
2. Confirm no delete/format actions are queued for Windows `C:` disk partitions.
3. Confirm ESP is mounted as `/boot/efi` and not set to format.
4. Confirm boot mode remains UEFI.

## Post-Install Validation
1. Reboot and verify Pop!_OS boots.
2. Reboot and verify Windows boots.
3. In BIOS/UEFI boot list, verify both entries exist:
   - Windows Boot Manager
   - Pop!_OS (systemd-boot)
4. Set preferred default boot entry in firmware.
5. Re-enable BitLocker after both OS boots are confirmed.

## Recovery Notes (If Needed)
- If Windows boot entry disappears:
  - Use firmware boot menu to boot Windows Boot Manager directly.
  - Use Windows recovery USB to repair boot records if necessary.
- If Pop!_OS entry is missing:
  - Recheck UEFI mode and ESP mount.
  - Reinstall/reconfigure bootloader from live USB.

## What This Plan Avoids
- No overwrite of Windows system partitions.
- No mixed Legacy/UEFI boot config.
- No shared OS partition between Windows and Linux.
