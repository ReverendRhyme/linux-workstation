# Quickstart

Fast path for Windows -> Pop!_OS migration with this repo.

Run all commands from repository root.

## 1) On Windows (collect migration context)

Run from repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -IncludeDownloads
powershell -ExecutionPolicy Bypass -File .\scripts\windows\export-migration-context.ps1
```

This creates sanitized context in `migration/context/<machine-id>/`.

Find your generated machine ID:

```powershell
Get-ChildItem .\migration\context
```

## 2) Commit context (repo or fork)

```powershell
git checkout -b migration/windows/<machine-id>/<yyyymmdd>
git add migration/context/<machine-id>
git commit -m "Add sanitized Windows migration context."
git push -u origin migration/windows/<machine-id>/<yyyymmdd>
```

Only commit sanitized files. Never commit raw backup payloads.
See `migration/README.md` for allowlist and safety rules.

## 3) On Pop!_OS (import + provision)

Run from repo root:

```bash
git fetch origin
git checkout migration/windows/<machine-id>/<yyyymmdd>
```

Then import context and provision:

```bash
./scripts/linux/import-migration-context.sh --context-dir migration/context/<machine-id> --write-local-env --print-restore-plan
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

If Fusion 360 is required, confirm `config/deployment.local.env` contains:
- `USE_FUSION360=yes`
- `FUSION360_PROVIDER=codeberg-script`
- `FUSION360_FALLBACK_PROVIDER=bottles`

If `GAMES_DRIVE` is blank and a Windows games-drive hint exists, the importer prompts for Linux partition mapping.

## 4) Validate migration artifacts (optional)

```bash
python3 scripts/linux/validate-migration-context.py --all-contexts --context-root migration/context
./scripts/linux/check-migration-allowlist.sh --all
```

## AI agent one-liner flow

If context already exists on Linux:

```bash
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

For unattended automation:

```bash
./scripts/popos-auto.sh --migration-context migration/context/<machine-id> --non-interactive --preset dual-disk
```
