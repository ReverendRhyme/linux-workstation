# Agentic Test Loops

Unified operator runbook for iterative migration/setup testing with AI agents.

## Trigger Phrases (from `AGENTS.md`)

- Windows migration loop: `run windows migration test loop`
- Bare-metal snapshot loop: `run baremetal migration test loop`

## Loop A: Windows Migration QA (Closed-Loop)

Goal: validate export + context generation, capture failures, and feed repair PRs.

Run from repo root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\run-migration-test-loop.ps1 -SkipBackup
```

Optional flags:

- `-AllBackup -IncludeDownloads` (full backup payload path)
- `-PlanOnlyBackup` (backup planning only, no payload copy)
- `-PrepareFixBranch` (create `fix/migration-loop/<yyyymmdd>-<topic>` on failure)

Backup policy defaults:

- minimal mode by default
- cloud-managed paths: metadata-only
- unknown paths: skipped

Expected outcomes:

- `Status: PASS` when backup/export/validation complete
- `Status: BLOCKED` when a step fails, with incident details appended to `migration/context/<machine-id>/summary.md`

References:

- `scripts/windows/README.md`
- `migration/README.md`

## Loop B: Bare-Metal Snapshot QA (Pop!_OS Hardware)

Goal: run setup tests from a known-clean baseline and repeat quickly.

Prerequisites:

- Btrfs root + `snapper` available
- durable `STATE_DIR` path that survives rollback (example: `/mnt/storage/linux-workstation-test-loop`)

1) Create baseline snapshot once:

```bash
./scripts/linux/run-baremetal-test-loop.sh --prepare-baseline --snapshot-label baseline-clean
```

2) Optional boot-resume service:

```bash
./scripts/linux/install-baremetal-loop-resume-service.sh
```

3) Run one iteration + rollback + reboot:

```bash
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --prepare-fix-branch --rollback-after --rollback-reboot
```

4) Optional auto-retry mode (continue until PASS or max attempts):

```bash
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --prepare-fix-branch --loop-until-pass --max-attempts 10
```

Loop artifacts:

- `automation/test-loop/state.env`
- `automation/test-loop/LATEST.md`
- `automation/test-loop/runs/<run-id>/iteration-<n>.md`

Preflight + blocker behavior:

- Preflight checks run before each invocation: `snapper` availability, `snapper list` for configured config, context directory (if provided), and writable `STATE_DIR`.
- If preflight fails, status is `BLOCKED` and `automation/test-loop/LATEST.md` is updated with failure class, step, and detail.
- `--loop-until-pass` retries only transient classes (`network`, `git`) and stops on non-transient blockers (`path`, `permissions`, `schema`, `script`).
- On non-btrfs root, you can run setup-validation loop mode without rollback: add `--allow-non-btrfs`.

References:

- `automation/test-loop/README.md`
- `scripts/linux/run-baremetal-test-loop.sh --help`
- `scripts/linux/btrfs-snapshot-loop.sh --help`

## Safety Rules

- Commit only sanitized migration context files under `migration/context/<machine-id>/`.
- Never commit backup payload directories or raw/sensitive exports.
- Treat rollback as destructive to uncommitted local changes.
- Use minimal fixes and PR each repair before rerunning loops.
