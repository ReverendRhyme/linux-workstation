# New Build Certification

Use this runbook to certify the repository on a freshly installed Linux machine.

For single-disk Pop!_OS install layout with btrfs root, see:
- `docs/POP_OS_SINGLE_DISK_BTRFS_INSTALL.md`

## Agent Trigger Phrase

- `run new linux build certification`

When an AI agent receives this trigger, it should run the certification wrapper
and report the summary file path.

## One-Command Certification

```bash
./scripts/linux/run-new-build-certification.sh --context-dir migration/context/<machine-id>
```

## Fresh Build Prerequisites (Snapshot Mode)

Before first certification on a brand-new Pop!_OS install, ensure snapper is installed and configured.

```bash
sudo apt update
sudo apt install -y btrfs-progs snapper
sudo snapper -c root create-config /
findmnt -no FSTYPE /
sudo snapper -c root list
```

Expected:

- root filesystem reports `btrfs`
- `snapper -c root list` succeeds

If these are missing, the loop preflight blocks with `Failure step: snapper list`.

This command performs:

1. `./scripts/full-setup.sh --check`
2. `./scripts/full-setup.sh --all --dry-run`
3. `./scripts/full-setup.sh --profile full`
4. `./scripts/full-setup.sh --verify`
5. `./scripts/linux/run-self-healing-loop.sh` (with non-btrfs fallback when needed)

## Useful Options

```bash
# Skip provisioning, loop-only certification
./scripts/linux/run-new-build-certification.sh --skip-provision --context-dir migration/context/<machine-id>

# Allow self-healing loop to create/merge PRs
./scripts/linux/run-new-build-certification.sh --auto-pr --context-dir migration/context/<machine-id>

# Custom certification artifact root
./scripts/linux/run-new-build-certification.sh --cert-root-dir /mnt/storage/new-build-certification --context-dir migration/context/<machine-id>
```

## Certification Artifacts

- `automation/new-build-certification/<run-id>/SUMMARY.md`
- `automation/new-build-certification/<run-id>/01-check.log`
- `automation/new-build-certification/<run-id>/02-dry-run.log`
- `automation/new-build-certification/<run-id>/03-profile.log`
- `automation/new-build-certification/<run-id>/04-verify.log`
- `automation/new-build-certification/<run-id>/05-loop.log`

Loop artifacts remain in the configured loop state dir (default: `automation/test-loop-certification`).

## Pass Criteria

- check passes
- dry run passes
- profile + verify pass (unless explicitly skipped)
- self-healing loop returns PASS (unless explicitly skipped)

## Restore + Second Run From Scratch

Use this sequence after validating one run and wanting a clean rerun from the baseline snapshot.

```bash
# 1) Roll back to baseline and reboot into the restored system
./scripts/linux/btrfs-snapshot-loop.sh rollback --label baseline-clean --config root --reboot

# 2) After reboot, rerun full certification with persistent state
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-new-build-certification.sh --auto-pr --max-cycles 5 --max-attempts 3
```

Review artifacts:

- `automation/new-build-certification/<run-id>/SUMMARY.md`
- `/mnt/storage/linux-workstation-test-loop/LATEST.md`
- `/mnt/storage/linux-workstation-test-loop/HANDOFF.md`
