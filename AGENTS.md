# Linux Workstation Automation Agent

> **FOR AI AGENTS**: To provision this workstation, run:
> ```bash
> cd <repo-directory> && ./scripts/popos-auto.sh
> ```

---

## Quick Start for AI Agents

For a concise command-only runbook, see `QUICKSTART.md`.

When a user says "set up my Linux workstation" or "run the setup":

```bash
cd <repo-directory>
./scripts/popos-auto.sh
```

Unattended path:

```bash
./scripts/popos-auto.sh --non-interactive --preset dual-disk
```

Skill shortcut:
- `/popos-setup` for end-to-end Pop!_OS (COSMIC) guided automation.

If drive layout or install mode is unclear, ask before changing mount or partition behavior.

This wrapper runs: guided/non-interactive config -> profile provisioning -> verification.

### Migration-Context-Aware Flow (Recommended)

When helping with Windows -> Pop!_OS migration, use this two-phase flow:

#### Phase A: Windows (collect + commit context)

```powershell
# From repo root on Windows
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -IncludeDownloads
powershell -ExecutionPolicy Bypass -File .\scripts\windows\export-migration-context.ps1

# Review and commit sanitized context
git checkout -b migration/windows/<machine-id>/<yyyymmdd>
git add migration/context/<machine-id>
git commit -m "Add sanitized Windows migration context."
git push -u origin migration/windows/<machine-id>/<yyyymmdd>
```

#### Phase B: Linux (import + provision)

```bash
# From repo root on Pop!_OS
./scripts/linux/import-migration-context.sh --context-dir migration/context/<machine-id> --write-local-env --print-restore-plan
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

Agent behavior notes:
- Prefer `--migration-context` when context exists.
- If `GAMES_DRIVE` is empty and a Windows games-drive hint exists, prompt for Linux partition mapping.
- Never auto-commit backup payloads or raw/sensitive migration data.

### Command-Triggered Migration QA Loop

Use a strict trigger phrase so behavior is deterministic.

Primary trigger:
- `run windows migration test loop`

Accepted aliases:
- `run migration qa loop`
- `retest windows migration flow`

When triggered, execute this closed-loop workflow:
1. Run Phase A Windows commands via helper script:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\windows\run-migration-test-loop.ps1 -IncludeDownloads`
   - (or manually run `backup-to-gdrive.ps1` then `export-migration-context.ps1`)
2. Validate generated context (`deployment.seed.env`, required JSON files).
3. If a failure occurs, stop normal flow and:
   - capture failing command, exit code, and key stderr/stdout lines
   - classify root cause (`script`, `path`, `permissions`, `network`, `schema`, `git`)
   - document findings in a concise incident note in `migration/context/<machine-id>/summary.md` (append section)
4. Hand back to AI repair cycle:
   - create fix branch `fix/migration-loop/<yyyymmdd>-<short-topic>`
   - implement minimal fix
   - run validation commands
   - open PR with failure evidence + fix summary
5. After PR merge, rerun trigger flow and report final status (`PASS` or `BLOCKED`).

Automation constraints for this loop:
- Commit only sanitized context files under `migration/context/<machine-id>/`.
- Never commit backup payload directories or raw/sensitive exports.
- Never use destructive git commands unless explicitly requested.
- Only ask user questions when blocked by missing required values (credentials, ambiguous target disk mapping, etc.).

---

## Purpose
Provisioning and maintenance agent for a portable Pop!_OS workstation setup.

## System Context

### Example Hardware (reference only)
- **CPU**: Modern x86_64 processor (AMD or Intel)
- **GPU**: Mesa-supported integrated or discrete graphics
- **RAM**: 16GB+ recommended
- **Storage**: One or more SSD/NVMe drives

### OS Target
- **Primary**: Pop!_OS (COSMIC edition)
- **Package Manager**: apt + flatpak
- **Desktop**: COSMIC (System76's Rust-based desktop)
- **Display Server**: Wayland

---

## Full Setup Script

### Usage
```bash
./scripts/popos-auto.sh              # Full guided setup (recommended)
./scripts/full-setup.sh --check     # Check system readiness
./scripts/full-setup.sh --hardware  # Generate hardware report only
./scripts/full-setup.sh --bootstrap # Run Ansible only
./scripts/full-setup.sh --profile full|gaming|dev|minimal
./scripts/full-setup.sh --verify    # Verify installation
```

### Recommended Agent Flow
```bash
cd <repo-directory>
./scripts/full-setup.sh --check
./scripts/full-setup.sh --hardware
./scripts/agent-configure.sh --guided
source ./config/defaults.env
test -f ./config/deployment.local.env && source ./config/deployment.local.env
./scripts/full-setup.sh --profile "${DEPLOY_PROFILE:-full}"
```

Use the generated JSON report to make deployment decisions:
- `logs/hardware/hardware-report-latest.json`

### What It Installs

| Category | Software |
|----------|----------|
| **Gaming** | Steam, Heroic, ProtonUp-Qt, MangoHud, Gamemode, Discord, OBS |
| **CAD/3D** | Blender, FreeCAD, OpenSCAD, MeshLab |
| **3D Printing** | OrcaSlicer, Bambu Studio, CHITUBOX, PrusaSlicer, Cura |
| **Office** | LibreOffice, 1Password, Slack, Zoom, Obsidian |
| **Dev** | Docker, ZSH, Oh My Zsh, Git, Python, VS Code/Cursor |
| **Cloud** | rclone |
| **Utilities** | btop, ncdu, bat, fzf, FileZilla |

Package/source-of-truth note: role task files under `ansible/roles/*/tasks/main.yml` define installed software.

---

## COSMIC Desktop

COSMIC is System76's Rust-based desktop for Pop!_OS.

### Hotkeys
- `Super + Space` - App launcher
- `Super + T` - Toggle tiling
- `Super + 1-9` - Switch workspaces
- `Super + Arrow` - Move windows

### Install (if not already)
```bash
sudo apt install pop-desktop
# Select COSMIC at login
```

---

## Rules

1. **Use Ansible-first automation** - Prefer Ansible modules/playbooks for all configuration changes; use bash only for orchestration
2. **Keep scripts idempotent** - Safe to re-run
3. **Avoid destructive changes** - Never wipe without confirmation
4. **AMD GPU** - Use Mesa drivers only (no proprietary)
5. **Flatpak for apps** - Steam is apt-only exception
6. **nofail for mounts** - Prevent boot failure

---

## Drive Configuration

### Intelligent Drive Detection
```bash
./scripts/drive-recommend.sh --detect
```

This script:
1. Scans all drives (NVMe, SSD, HDD)
2. Classifies by speed and size
3. Makes recommendations for OS, games, and storage
4. Shows optimal partition layout
5. Provides fstab examples

### Example Output
```
[1] /dev/nvme0n1
    Model: <drive-model-A>
    Size: <size> (nvme, medium)
    Speed Class: fast

[2] /dev/nvme1n1
    Model: <drive-model-B>
    Size: <size> (nvme, medium)

Recommended Layout:
OS Drive: /dev/<device>
Game Drive: /dev/<device>
Storage: Use HDD if available
```

### Mount Points
```
/mnt/games     - Steam/GOG/Epic libraries (fast NVMe/SSD)
/mnt/storage   - Secondary storage
/home          - User configs
```

### Mount Drives
```bash
# Find UUIDs
sudo blkid

# Add to fstab
sudo nano /etc/fstab
# UUID=xxxx /mnt/games ext4 defaults,nofail 0 2
```

---

## Fusion 360 Setup

Fusion 360 native install uses the maintained Codeberg installer provider:

```bash
curl -L https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/setup/autodesk_fusion_installer_x86-64.sh -o fusion_installer.sh
chmod +x fusion_installer.sh
./fusion_installer.sh --install --default
```

Requires active Fusion 360 license.

Automation notes:
- `FUSION360_PROVIDER=codeberg-script` is the primary path.
- `FUSION360_FALLBACK_PROVIDER=bottles` is the recommended fallback.
- Avoid silent downgrade to web when Fusion is required.

---

## Gaming Configuration

### Steam
1. Launch Steam → Settings → Compatibility
2. Enable Steam Play for all titles
3. Add library folder: `/mnt/games`
4. Launch option: `mangohud gamemoderun %command%`

### Heroic (Epic/GOG)
1. Launch Heroic → Settings → Wine/Proton
2. Login to accounts
3. Install location: `/mnt/games/Heroic`

### Proton GE
1. Open ProtonUp-Qt
2. Download latest Proton GE
3. Select in Steam/Heroic

---

## Cloud Storage

### Google Drive (rclone)
```bash
./scripts/cloud-setup.sh
# or
rclone config
rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full &
```

### OneDrive
```bash
sudo apt install onedrive
onedrive --synchronize
```

---

## Vortex Mod Manager

For BG3 and other moddable games:

```bash
sudo apt install lutris
# Then install Vortex via Lutris GUI
```

---

## Troubleshooting

### GPU Check
```bash
glxinfo | grep "OpenGL renderer"
# Should show your active renderer
```

### Steam Issues
```bash
rm -rf ~/.local/share/Steam/steam/cached
steam --reset
```

### Flatpak Issues
```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

---

## Safety Constraints

- **NEVER** wipe disks without explicit confirmation
- **NEVER** overwrite fstab without showing changes
- **NEVER** commit secrets (use .gitignore)
- **ALWAYS** backup before major changes

---

## Repository Structure

```
linux-workstation/
├── scripts/
│   ├── full-setup.sh        # Main automation script
│   ├── maintenance.sh       # System updates
│   ├── cloud-setup.sh       # Google Drive/OneDrive
│   ├── mount-drives.sh      # Drive mount helper
│   └── post-install-check.sh # Verification
├── legacy/
│   ├── core/                # Legacy shared bash libraries
│   └── modules/             # Legacy module installers
├── ansible/
│   ├── site.yml             # Main playbook
│   └── roles/              # Modular roles
│       ├── base/           # Core packages
│       ├── gaming/         # Steam, Heroic
│       ├── cad/            # Blender, FreeCAD
│       ├── printing/       # Slicers
│       ├── dev/            # Docker, ZSH
│       └── security/       # UFW firewall
├── configs/
│   ├── fstab.example       # Mount template
│   └── zshrc.example      # Shell config
└── README.md
```
