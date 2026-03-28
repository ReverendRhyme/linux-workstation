# Workstation Handover Template

Use this file as a per-machine handoff note. Replace placeholders with actual values.

## Quick Run

For AI agents or operators:

```bash
cd <repo-directory>
./scripts/popos-auto.sh
```

## System Hardware

| Component | Value |
|-----------|-------|
| CPU | <cpu-model> |
| GPU | <gpu-model> |
| RAM | <ram-size> |
| Motherboard | <board-model> |
| Desktop | COSMIC / GNOME / other |

## Drive Layout

| Drive | Size | Assignment |
|-------|------|-----------|
| <device> | <size> | OS (`/`) |
| <device> | <size> | Games (`/mnt/games`) |
| <device> | <size> | Storage (`/mnt/storage`) |
| <device> | <size> | Backups (`/mnt/backups`) |

Notes:
- Keep OS and games on SSD/NVMe when possible.
- Use `nofail` in `/etc/fstab` for non-critical mounts.

## Setup Commands

```bash
git clone <your-fork-url>
cd <repo-directory>

./scripts/full-setup.sh --check
./scripts/full-setup.sh --hardware
./scripts/popos-auto.sh
./scripts/full-setup.sh --verify
```

## Profile Notes

| Profile | Intended Use |
|---------|---------------|
| `full` | Complete workstation |
| `gaming` | Gaming-focused setup |
| `dev` | Development-focused setup |
| `minimal` | Core utilities only |

## Post-Install Checklist

1. Confirm mounts and update `/etc/fstab` by UUID.
2. Verify graphics stack (`glxinfo`, `vulkaninfo --summary`).
3. Launch key apps for selected profile.
4. Run `./scripts/full-setup.sh --verify`.

## Safety Rules

- Never wipe disks without explicit confirmation.
- Review partition targets before install.
- Do not commit secrets or local `.env` files.

## Repo

`<your-repository-url>`
