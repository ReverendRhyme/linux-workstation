# Windows Backup Helper (Google Drive)

This helper creates a migration backup bundle in Google Drive before moving to Pop!_OS.

Default target root:
- `S:\My Drive`

## Script

- `scripts/windows/backup-to-gdrive.ps1`

## Quick start

Run from a PowerShell prompt on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -IncludeDownloads
```

For best browser/bookmark consistency, close Chrome/Edge/Firefox/Brave before running.

## Optional arguments

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 `
  -GoogleDriveRoot "S:\My Drive" `
  -BackupName "PopOS-Migration-Manual" `
  -IncludeDownloads `
  -HashSamplePercent 10
```

## Output structure

The script creates:

```
S:\My Drive\PopOS-Migration-YYYYMMDD-HHMMSS\
  data\
  logs\
  backup-summary.csv
  backup-manifest.json
  installed-apps.csv
```

## What gets backed up

- User data: Desktop, Documents, Pictures, Videos, Saved Games, optional Downloads
- Browser data: Chrome/Edge/Brave user data, Firefox profiles
- Bookmark artifacts: explicit `Bookmarks` files for Chrome/Edge/Brave default profiles
- Game/launcher data: Steam userdata and metadata, Epic, GOG
- CAD/3D data: Autodesk/Fusion/Blender and slicer configs
- Dev/auth: `.ssh`, `.gitconfig`, PowerShell profile, VS Code/Cursor user settings
- Installed app inventory: exported to `installed-apps.csv`

## Exit codes

- `0` = PASS (no critical backup/verification issues)
- `2` = WARN (review manifest and summary before cutover)

## Notes

- The script uses `robocopy` for directory backups.
- Missing optional sources are skipped.
- Missing required sources are reported as warnings.
- Hash checks are sampled for speed (default 5%).
