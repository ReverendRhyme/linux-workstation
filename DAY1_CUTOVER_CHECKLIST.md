# Day 1 Cutover Checklist (Windows 11 -> Pop!_OS COSMIC)

Use this runbook on migration day for a safe cutover.

## 1) Backup Gate (Do not skip)

1. Confirm Google Drive Desktop is signed in and synced.
2. Confirm target path exists: `S:\My Drive`.
3. Close browsers before backup (Chrome/Edge/Firefox/Brave).
4. Run backup helper from Windows PowerShell:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -IncludeDownloads`
5. Review output files in generated backup folder:
   - `backup-manifest.json`
   - `backup-summary.csv`
   - `installed-apps.csv`
6. Verify `backup-summary.csv` includes bookmark entries (`Chrome-Bookmarks-Default`, `Edge-Bookmarks-Default`, etc.).
7. Verify status is PASS before continuing.

## 2) Install Pop!_OS COSMIC

1. Boot Pop!_OS USB installer.
2. Use custom partitioning and apply your chosen layout.
3. Complete install, reboot, and connect to internet.
4. Update system:
   - `sudo apt update && sudo apt upgrade -y`

## 3) Clone and Preflight

1. Clone repo:
   - `git clone https://github.com/ReverendRhyme/linux-workstation.git`
2. Run dry-run preview:
   - `cd linux-workstation`
   - `./scripts/popos-auto.sh --dry-run`

## 4) Guided Provisioning

1. Run guided automation:
   - `./scripts/popos-auto.sh`
2. Confirm drive mappings when prompted.
3. Let setup complete.

## 5) Validation

1. Run checks:
   - `./scripts/post-install-check.sh`
   - `./scripts/full-setup.sh --verify`
2. Manually validate:
   - GPU renderer and Vulkan
   - Steam/Heroic launch from `/mnt/games`
   - Docker and shell setup
   - CAD and slicer apps

## 6) Restore and Sign-In

1. Restore files from Google Drive backup bundle.
2. Sign in to Steam, Epic/GOG (Heroic), Discord, 1Password, Slack, Zoom.
3. Re-import browser profiles/bookmarks and app settings.

## 7) Stabilization

1. Keep Windows backup untouched for at least 2 weeks.
2. Snapshot Linux state (Timeshift or your preferred backup strategy).
3. Note any Windows-only app gaps for dual-boot/VM fallback.
