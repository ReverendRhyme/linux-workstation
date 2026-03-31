# Bare-Metal Test Loop Artifacts

This directory stores state and logs for snapshot-based bare-metal test loops.

## Files

- `state.env` - current loop state used for resume after reboot
- `LATEST.md` - latest run summary
- `runs/<run-id>/iteration-<n>.md` - per-iteration command logs
- `runs/<run-id>/AI_FEEDBACK.md` - AI feedback journal (what worked, what failed, what changed)
- `runs/<run-id>/HANDOFF.md` - per-run AI handoff notes for next restore/test round
- `HANDOFF.md` - latest handoff snapshot (copied from the active run)

## Durability note

If your root snapshot rollback reverts this directory, place state on a separate persistent mount:

```bash
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh ...
```
