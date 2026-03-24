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

## Quick Start (After Pop_OS! Installation)

```bash
# 1. Clone this repo (or your fork)
git clone https://github.com/ReverendRhyme/linux-workstation.git
cd linux-workstation

# 2. Generate hardware report (for AI decisions)
./scripts/hardware-report.sh
# or share-safe output
./scripts/hardware-report.sh --sanitize

# 3. Run guided configuration (recommended)
./scripts/agent-configure.sh --guided
# or seed local overrides from template
cp ./config/deployment.local.env.example ./config/deployment.local.env

# 4. Provision selected profile
source ./config/defaults.env
test -f ./config/deployment.local.env && source ./config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"

# 5. Verify with Ansible checks
./scripts/full-setup.sh --verify

# 6. (Optional) Manual drive helper for fstab review
./scripts/mount-drives.sh

# One-command wrapper (does guided + provision + verify)
./scripts/popos-auto.sh

# Non-interactive automation (CI/remote provisioning)
./scripts/popos-auto.sh --non-interactive --preset dual-disk
```

Preset options for non-interactive mode:
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

## Migration Checklist

Dedicated E-drive dual-boot runbook:
- `docs/POP_OS_DUAL_BOOT_PLAN.md`

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
│   └── packages/          # Package lists by category
├── bootstrap/
│   └── bootstrap.sh       # Main entry point (installs Ansible, runs playbook)
├── ansible/
│   ├── inventory.yml      # Localhost inventory
│   ├── site.yml           # Main playbook (tagged by profile)
│   └── roles/
│       ├── base/          # Core system packages
│       ├── gaming/        # Steam, Heroic, mangohud
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
│   └── maintenance.sh     # System updates
├── configs/
│   ├── fstab.example      # Template for /etc/fstab
│   ├── zshrc.example      # ZSH configuration
│   └── hardware-notes.md  # Full hardware documentation
└── .github/
    └── workflows/         # CI/CD (ansible-lint)
```

---

## Installed Software

### Gaming Stack
| App | Purpose |
|-----|---------|
| Steam | PC gaming |
| Proton | Windows game compatibility |
| Heroic Games Launcher | Epic + GOG games |
| ProtonUp-Qt | Proton GE versions |
| MangoHud | FPS overlay |
| Gamemode | Performance optimization |
| OBS Studio | Streaming/recording |
| Discord | Voice chat |

### Development Tools
| App | Purpose |
|-----|---------|
| Docker | Containers |
| ZSH + Oh My Zsh | Enhanced shell |
| Git | Version control |
| Python 3 | Scripting |
| VS Code / Cursor | IDE |

### CAD/3D Design
| App | Purpose |
|-----|---------|
| Blender | 3D modeling, animation, rendering |
| FreeCAD | Parametric CAD (Fusion 360 alternative) |
| OpenSCAD | Script-based 3D modeling |
| MeshLab | Mesh processing |
| Fusion 360 | Full CAD via Wine (cryinkfly script) |

### 3D Printing
| App | Purpose |
|-----|---------|
| OrcaSlicer | Primary slicer (Bambu, etc.) |
| Bambu Studio | Bambu Lab slicer (native Linux) |
| CHITUBOX | Resin printing slicer |
| PrusaSlicer | Alternative slicer |
| Cura | Ultimaker slicer |

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

### Cloud Storage
| App | Purpose |
|-----|---------|
| rclone | Google Drive/OneDrive sync |
| Flatpak apps | Native cloud integration |

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
# Should show: AMD Radeon RX 580
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
vulkan-smi
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

- `scripts/modules/*` and `scripts/post-install-check.sh` are retained for compatibility/reference.
- Preferred verification path is `./scripts/full-setup.sh --verify` (Ansible role).
