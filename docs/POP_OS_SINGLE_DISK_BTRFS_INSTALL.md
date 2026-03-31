# Pop!_OS Single-Disk Btrfs Install (Loop-Friendly)

This guide configures a single-disk Pop!_OS install so bare-metal test loops can
reset quickly using snapshots.

## Goal

- root filesystem on `btrfs`
- `snapper` configured for root snapshots
- baseline snapshot created before test-loop runs

## Installer Steps (Single Disk)

1. Boot Pop!_OS installer USB.
2. Choose language/keyboard as normal.
3. Select **Custom (Advanced)** install.
4. In partitioning, create or assign these partitions on the same disk:
   - EFI: `512MB`, `FAT32`, mount at `/boot/efi`
   - Recovery (optional): `2GB-4GB`, `FAT32`, mount at `/recovery`
   - Root: remaining space, `btrfs`, mount at `/`
   - Swap: optional (Pop!_OS uses zram by default)
5. Confirm root (`/`) is set to `btrfs` (not ext4).
6. Complete install and reboot.

## Post-Install Snapshot Setup

```bash
sudo apt update
sudo apt install -y btrfs-progs snapper
sudo snapper -c root create-config /
findmnt -no FSTYPE /
snapper list
```

Expected:

- `findmnt -no FSTYPE /` prints `btrfs`
- `snapper list` succeeds

## Create Baseline For Test Loops

```bash
cd ~/projects/linux-workstation
./scripts/linux/run-baremetal-test-loop.sh --prepare-baseline --snapshot-label baseline-clean
```

## Recommended Loop Run

Use a durable state path that is easy to inspect between iterations:

```bash
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --prepare-fix-branch --loop-until-pass --max-attempts 10 --rollback-after --rollback-reboot
```

## If You Already Installed ext4 Root

For repeatable rollback testing, the simplest path is reinstalling Pop!_OS with
`btrfs` root. Converting an in-use ext4 root to btrfs is possible but not
recommended for this workflow.
