# Linux Workstation Platform

## Philosophy
Treat personal machines like production infrastructure:
- **Reproducible** - One command rebuild
- **Version controlled** - Git-tracked configs
- **Automated** - Ansible provisioning

## Desktop Environment
**COSMIC** - System76's Rust-based desktop environment for Pop!_OS
- Lightweight and fast (uses ~400MB vs GNOME's ~800MB)
- Built-in tiling window management
- Wayland-native
- Download: https://pop.system76.com (select COSMIC edition)

## Hardware Compatibility
This repository is designed to be portable across most Pop!_OS-compatible hardware.

- Works best on systems with SSD/NVMe storage.
- Supports AMD and Intel CPUs.
- Uses open-source Mesa graphics stack by default.
- Auto-detects available drives and helps generate mount recommendations.

---

## Quick Start

- Fastest end-to-end path (Windows export + Linux import + provisioning): `QUICKSTART.md`
- Full walkthrough with detailed explanations: `SETUP_GUIDE.md`
- AI-agent behavior and automation contract: `AGENTS.md`
- Unified loop operator guide: `docs/TEST_LOOPS.md`

Core commands after Pop!_OS install:

```bash
# Clone this repo (or your fork)
git clone <your-fork-url>
cd <repo-directory>

# One-command guided setup
./scripts/popos-auto.sh

# Non-interactive setup
./scripts/popos-auto.sh --non-interactive --preset dual-disk

# Migration-context-aware setup
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

Bare-metal snapshot loop (Btrfs + snapper):

```bash
# Preflight gate runs automatically and writes BLOCKED details to automation/test-loop/LATEST.md
./scripts/linux/run-baremetal-test-loop.sh --prepare-baseline --snapshot-label baseline-clean
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --prepare-fix-branch --rollback-after --rollback-reboot

# Optional unattended retry mode (continues until PASS or max attempts)
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --prepare-fix-branch --loop-until-pass --max-attempts 10

# Non-btrfs fallback (no rollback safety)
STATE_DIR=/mnt/storage/linux-workstation-test-loop ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --prepare-fix-branch --loop-until-pass --max-attempts 10 --allow-non-btrfs
```

Preset options:
- `single-disk` - single-drive systems, full profile
- `dual-disk` - gaming-focused dual-drive systems
- `dual-boot` - dual-boot install mode with gaming profile

---

## Security Best Practices

- Never commit `config/deployment.local.env` or any `.env.*` local secrets.
- Use sanitized hardware reports when sharing outside your trusted environment:
  - `./scripts/hardware-report.sh --sanitize`
- Enable local secret scanning before commits:
  - `pipx install pre-commit` (or `pip install pre-commit`)
  - `pre-commit install`
  - `pre-commit run --all-files`
- CI runs secret scanning automatically via Gitleaks (`.github/workflows/secret-scan.yml`).

---

## Windows -> Linux Context Flow

Use `QUICKSTART.md` for the canonical command sequence.

Detailed migration policy (allowlist, safety rules, and AI-agent contract):
- `migration/README.md`

Fusion 360 native runtime defaults:
- `FUSION360_PROVIDER=codeberg-script`
- `FUSION360_FALLBACK_PROVIDER=bottles`

## Migration Checklist

Portable migration guidance is in `SETUP_GUIDE.md`.

Machine-specific runbooks and notes live under `docs/personal/`:
- `docs/personal/POP_OS_DUAL_BOOT_PLAN.md`
- `docs/personal/PREFLIGHT_CHECKLIST.md`
- `docs/personal/DAY1_CUTOVER_CHECKLIST.md`
- `docs/personal/HANDOVER.md`
- `docs/personal/hardware-notes.md`

### Before Installation (Windows Side)
- [ ] Backup important data to external drive
- [ ] Run `scripts/windows/backup-to-gdrive.ps1` to create Google Drive backup bundle
- [ ] Export browser bookmarks (Chrome/Firefox)
- [ ] Export 1Password vault
- [ ] Note down game library locations
- [ ] Download Pop_OS! ISO to USB
- [ ] Create list of Windows apps needing Linux alternatives

### During Installation (Pop_OS!)
- [ ] Boot from USB
- [ ] Select "Custom Partitioning"
- [ ] Partition your target Linux disk:
  ```
  /boot/efi   512MB  EFI System Partition
  /           200GB  Root (ext4)
  /home       300GB  Home (ext4)
  /mnt/games  remaining space for game libraries (ext4)
  ```
- [ ] Complete installation
- [ ] Create your user account

### After Installation (First Boot)
- [ ] Connect to WiFi
- [ ] Update system: `sudo apt update && sudo apt upgrade -y`
- [ ] Clone this repo
- [ ] Run `./bootstrap/bootstrap.sh`
- [ ] Run `./scripts/full-setup.sh --verify`
- [ ] (Optional) Run `./scripts/mount-drives.sh`
- [ ] Add game drives to `/etc/fstab`
- [ ] Install Steam + enable Proton
- [ ] Install Heroic for Epic/GOG
- [ ] Configure ZSH

---

## Repository Structure

```
linux-workstation/
├── README.md              # This file
├── AGENTS.md              # AI agent instructions
├── config/
│   ├── defaults.env       # Portable defaults (tracked)
│   ├── deployment.local.env  # Local overrides (gitignored)
│   └── deployment.local.env.example # Local override template
├── bootstrap/
│   └── bootstrap.sh       # Main entry point (installs Ansible, runs playbook)
├── ansible/
│   ├── inventory.yml      # Localhost inventory
│   ├── site.yml           # Main playbook (tagged by profile)
│   └── roles/
│       ├── base/          # Core system packages
│       ├── gaming/        # Steam, Lutris, Heroic, gaming tools
│       ├── cad/           # Blender, FreeCAD, OpenSCAD
│       ├── printing/      # OrcaSlicer, PrusaSlicer, Cura
│       ├── dev/           # Docker, Oh My Zsh, dev tools
│       ├── security/      # UFW firewall
│       ├── storage/       # Mount paths and storage prep
│       ├── cloud/         # rclone/OneDrive tools
│       ├── desktop/       # COSMIC desktop tuning helpers
│       └── verify/        # Post-provision verification checks
├── scripts/
│   ├── popos-auto.sh      # Guided wrapper (recommended)
│   ├── full-setup.sh      # Main orchestrator
│   ├── agent-configure.sh # Interactive config + local env generation
│   ├── post-install-check.sh # Legacy deep-check helper
│   ├── drive-recommend.sh # Drive detection + recommendations
│   ├── mount-drives.sh    # Mount helper
│   ├── maintenance.sh     # System updates
│   ├── linux/             # Linux migration import + policy + bare-metal loop tools
│   └── windows/           # Windows backup + migration export helpers
├── automation/
│   └── test-loop/         # Durable test-loop state and iteration logs
├── migration/
│   ├── README.md          # Migration branch workflow + safety
│   ├── schema/            # JSON schemas for migration context
│   └── context/           # Machine-specific sanitized migration data
├── legacy/
│   ├── core/              # Legacy shared bash libraries
│   └── modules/           # Legacy per-category installer scripts
├── configs/
│   ├── fstab.example      # Template for /etc/fstab
│   └── zshrc.example      # ZSH configuration
├── docs/
│   └── personal/          # Optional machine-specific runbooks
└── .github/
    └── workflows/         # CI/CD (ansible-lint)
```

---

## Installed Software

### Gaming Stack
| App | Purpose |
|-----|---------|
| Steam (apt exception) | PC gaming |
| Proton | Windows game compatibility |
| Lutris | Non-Steam game launcher |
| Heroic Games Launcher | Epic + GOG games |
| ProtonUp-Qt | Proton GE versions |
| MangoHud | FPS overlay |
| Gamemode | Performance optimization |
| OBS Studio | Streaming/recording |
| Discord | Voice chat |

Package source of truth: `ansible/roles/gaming/tasks/main.yml`.

Flatpak-first note: gaming GUI tools prefer Flatpak for freshness; Steam remains the apt exception.
Optional extended tools (`GAMING_EXTENDED_TOOLS=yes`): Flatseal, Warehouse, Gear Lever.

### Development Tools
| App | Purpose |
|-----|---------|
| Docker | Containers |
| ZSH + Oh My Zsh | Enhanced shell |
| Git | Version control |
| Python 3 | Scripting |
| VS Code / Cursor | IDE |

Package source of truth: `ansible/roles/dev/tasks/main.yml`.

### CAD/3D Design
| App | Purpose |
|-----|---------|
| Blender | 3D modeling, animation, rendering |
| FreeCAD | Parametric CAD (Fusion 360 alternative) |
| OpenSCAD | Script-based 3D modeling |
| MeshLab | Mesh processing |
| Fusion 360 | Full CAD via Wine/Proton (Codeberg provider) |

Package source of truth: `ansible/roles/cad/tasks/main.yml` and `ansible/roles/fusion360/tasks/main.yml`.

### 3D Printing
| App | Purpose |
|-----|---------|
| OrcaSlicer | Primary slicer (Bambu, etc.) |
| Bambu Studio | Bambu Lab slicer (native Linux) |
| CHITUBOX | Resin printing slicer |
| PrusaSlicer | Alternative slicer |
| Cura | Ultimaker slicer |

Package source of truth: `ansible/roles/printing/tasks/main.yml`.

### Productivity & Office
| App | Purpose |
|-----|---------|
| LibreOffice | Office suite (Word, Excel, PowerPoint) |
| 1Password | Password manager |
| Slack | Work communication |
| Zoom | Video conferencing |
| Obsidian | Note-taking |
| Spotify | Music streaming |
| FileZilla | FTP/SFTP client |

Package source of truth: `ansible/roles/base/tasks/main.yml`.

### Cloud Storage
| App | Purpose |
|-----|---------|
| rclone | Google Drive/OneDrive sync |
| Flatpak apps | Native cloud integration |

Package source of truth: `ansible/roles/cloud/tasks/main.yml`.

### Mod Management
| App | Purpose |
|-----|---------|
| Vortex | Nexus Mods manager (via Lutris) |
| Mod Organizer 2 | Alternative mod manager |

### System Utilities
| App | Purpose |
|-----|---------|
| btop | System monitor |
| ncdu | Disk usage analyzer |
| bat | cat alternative |
| fzf | Fuzzy finder |
| ripgrep | grep alternative |

---

## Game Drive Configuration

After installation, configure your game libraries:

```bash
# Find drive UUIDs
sudo blkid

# Add to /etc/fstab
sudo nano /etc/fstab
```

Example entry:
```
UUID=xxxx-xxxx /mnt/games ext4 defaults,nofail 0 2
```

Then mount and use in Steam:
- Settings → Downloads → Steam Library Folders
- Add library on `/mnt/games`

---

## Troubleshooting

### GPU not detected
```bash
glxinfo | grep "OpenGL renderer"
# Should show your active renderer (Mesa/AMD/Intel/NVIDIA)
```

### Steam games not launching
- Enable Proton in Steam settings
- Try Proton GE via ProtonUp-Qt
- Check launch options: `mangohud gamemoderun %command%`

### Flatpak apps not installing
```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

---

## Useful Commands

```bash
# Update everything
./scripts/maintenance.sh

# Run specific Ansible role
ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags gaming

# Check disk usage
ncdu -x /

# Monitor system
btop

# Check GPU
vulkaninfo --summary
```

---

## Next Steps After Setup

1. **Import game libraries** - Point Steam/GOG/Epic to `/mnt/games`
2. **Configure gaming performance** - Set Steam launch options
3. **Set up 1Password** - Install Linux desktop app
4. **Configure backups** - Install Timeshift
5. **Personalize** - Theme, fonts, extensions

---

## References

- [Pop_OS! Installation Guide](https://pop.system76.com)
- [ProtonDB](https://www.protondb.com) - Game compatibility ratings
- [Heroic Games Launcher](https://heroicgameslauncher.com)
- [Ansible Documentation](https://docs.ansible.com)

---

## Contributing

- See `CONTRIBUTING.md` for local validation and workflow expectations.
- This repo is Ansible-first; shell scripts are orchestration helpers.

## Legacy Helpers

- `legacy/modules/*`, `legacy/core/*`, and `scripts/post-install-check.sh` are retained for compatibility/reference.
- Preferred verification path is `./scripts/full-setup.sh --verify` (Ansible role).
