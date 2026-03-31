# Bare-Metal Loop Handoff

- Date: 2026-03-30
- Host state: fresh Pop!_OS install, btrfs root
- Certification run: `cert-20260330-213714`
- Loop run: `run-20260330-213706`
- Result: PASS on first iteration

## Findings

- Initial blocker on fresh host: `snapper` was not installed.
- Remediation applied: installed `btrfs-progs` + `snapper`, created snapper root config.
- After remediation, full certification + self-healing loop completed PASS.
- No repo code fixes were required in this run (no blocker-triggered patch branch/PR).

## Commands Used (Successful Path)

```bash
sudo apt update && sudo apt install -y btrfs-progs snapper
sudo snapper -c root create-config /

STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --prepare-baseline --snapshot-label baseline-clean

STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-new-build-certification.sh --auto-pr --max-cycles 5 --max-attempts 3
```

## Artifacts

- `automation/new-build-certification/cert-20260330-213714/SUMMARY.md`
- `/mnt/storage/linux-workstation-test-loop/LATEST.md`
- `/mnt/storage/linux-workstation-test-loop/HANDOFF.md`
- `/mnt/storage/linux-workstation-test-loop/runs/run-20260330-213706/iteration-1.md`

## Restore And Rerun From Scratch

```bash
# Roll back OS to the clean baseline snapshot
./scripts/linux/btrfs-snapshot-loop.sh rollback --label baseline-clean --config root --reboot

# After reboot, run the full certification loop again
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-new-build-certification.sh --auto-pr --max-cycles 5 --max-attempts 3
```
