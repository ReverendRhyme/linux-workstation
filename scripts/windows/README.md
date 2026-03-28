# Windows Migration Helpers

These helpers collect backup data and migration context before moving to Pop!_OS.

Default target root:
- `S:\My Drive`

## Scripts

- `scripts/windows/backup-to-gdrive.ps1`
- `scripts/windows/export-migration-context.ps1`
- `scripts/windows/run-migration-test-loop.ps1`

## Quick start

Run from a PowerShell prompt on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -IncludeDownloads
```

For best browser/bookmark consistency, close Chrome/Edge/Firefox/Brave before running.

Export migration context (sanitized by default):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\export-migration-context.ps1
```

This writes structured migration files to `migration/context/<machine-id>/` that can be committed and reused on Linux.

Commit flow example:

```powershell
git checkout -b migration/windows/<machine-id>/<yyyymmdd>
git add migration/context/<machine-id>
git commit -m "Add sanitized Windows migration context."
git push -u origin migration/windows/<machine-id>/<yyyymmdd>
```

On Linux, import and provision:

```bash
./scripts/linux/import-migration-context.sh --context-dir migration/context/<machine-id> --write-local-env --print-restore-plan
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

Run the closed-loop migration QA helper (backup + export + validation + incident note on failure):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\run-migration-test-loop.ps1 -IncludeDownloads
```

Optional:
- `-SkipBackup` to only run export + validation
- `-PrepareFixBranch` to auto-create `fix/migration-loop/<yyyymmdd>-<topic>` when blocked

The export includes:
- machine profile + storage summary
- software map with Linux install intent categories
- drive/install intent hints (fresh vs dualboot)
- deployment seed env for Linux import (including Fusion 360 provider defaults)

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
