# Migration Context Workflow

This folder stores sanitized migration context exported from a Windows machine and reused during Linux provisioning.

For a concise command sequence, see `QUICKSTART.md`.

## Why this exists

- Capture machine context before cutover.
- Keep setup decisions versioned.
- Reuse migration intent after installing Pop!_OS.

## Safe workflow

1. On Windows, export migration context:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\export-migration-context.ps1
```

For closed-loop QA automation on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\run-migration-test-loop.ps1 -IncludeDownloads
```

2. Review generated files in `migration/context/<machine-id>/`.
3. Commit only sanitized context files.
4. On Pop!_OS, import context:

```bash
./scripts/linux/import-migration-context.sh --context-dir migration/context/<machine-id> --write-local-env --print-restore-plan
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

## AI Agent Contract

When automating this flow with an AI agent:

- Prefer these exact commands for export/import.
- Use `--migration-context` whenever context exists.
- Prompt only for Linux partition mapping when Windows drive hints cannot be mapped safely.
- When Fusion 360 is required, prefer `FUSION360_PROVIDER=codeberg-script` with `FUSION360_FALLBACK_PROVIDER=bottles`.
- Never commit backup payloads, raw exports, or sensitive data.
- Never auto-push destructive git history changes.

## Using this in your own repo

- Create a branch such as `migration/windows/<machine-id>/<yyyymmdd>`.
- Commit sanitized files from `migration/context/<machine-id>/`.
- Push to your normal remote.

## Using this from a fork

- Fork this repository.
- Run the same branch workflow in your fork.
- Keep migration branches private when possible.

## Allowed committed files

Each machine context directory may include only:

- `machine-profile.json`
- `software-map.json`
- `paths.json`
- `backup-manifest.json`
- `deployment.seed.env`
- `summary.md`

The allowlist checker (`scripts/linux/check-migration-allowlist.sh`) enforces this.

## Never commit

- Raw browser profile data
- Key material (`.ssh`, certs, keyrings)
- Full backup payloads
- Session/token/cookie databases
- Any `raw` or `sensitive` migration output

## Schemas

Schemas for context JSON files are under `migration/schema/`.

Validate all checked-in contexts:

```bash
python3 scripts/linux/validate-migration-context.py --all-contexts --context-root migration/context
```

## Sample context

`migration/context/sample-win-devgamer/` is a sanitized fixture used for CI and documentation examples.
