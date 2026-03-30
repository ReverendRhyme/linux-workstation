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
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1
```

Default behavior is minimal and policy-driven:
- local-only migration-critical paths are backed up
- cloud-managed paths are metadata-only
- unknown paths are skipped

Use full legacy backup mode only when needed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -All -IncludeDownloads
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
powershell -ExecutionPolicy Bypass -File .\scripts\windows\run-migration-test-loop.ps1
```

Optional:
- `-SkipBackup` to only run export + validation
- `-AllBackup` to run full backup mode in the loop
- `-PlanOnlyBackup` to generate backup plan/metadata without copying files
- `-PrepareFixBranch` to auto-create `fix/migration-loop/<yyyymmdd>-<topic>` when blocked

The export includes:
- machine profile + storage summary
- software map with Linux install intent categories
- drive/install intent hints (fresh vs dualboot)
- deployment seed env for Linux import (including Fusion 360 provider defaults and gaming extended-tools flag)

## Optional arguments

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 `
  -GoogleDriveRoot "S:\My Drive" `
  -BackupName "PopOS-Migration-Manual" `
  -PlanOnly `
  -HashSamplePercent 10
```

## Output structure

The script creates:

```
S:\My Drive\PopOS-Migration-YYYYMMDD-HHMMSS\
  data\
  logs\
  backup-decision-plan.json
  backup-decision-plan.md
  backup-summary.csv
  backup-manifest.json
  installed-apps.csv
```

## What gets backed up

- Minimal default: migration-critical local settings/metadata only (saved games, bookmarks, launcher metadata, CAD configs, dev settings)
- Cloud-managed paths: metadata-only by policy (no bulk payload copy)
- Unknown paths: skipped by policy unless `-All`
- Full mode (`-All`): includes broad user folders and full profile payloads
- Steam `steamapps` in minimal mode excludes large game payload directories (`common`, `downloading`, `shadercache`, `workshop`, `compatdata`, `music`)

## Exit codes

- `0` = PASS (no critical backup/verification issues)
- `2` = WARN (review manifest and summary before cutover)

## Notes

- The script uses `robocopy` for directory backups.
- Missing optional sources are skipped.
- Missing required sources are reported as warnings.
- Hash checks are sampled for speed (default 5%).
