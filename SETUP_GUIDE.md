# Pop_OS! Setup Guide

Complete walkthrough for migrating from Windows to Pop!_OS using this repo.

If you only need command-by-command execution, use `QUICKSTART.md`.

---

## Table of Contents

1. [Pre-Flight Checklist (Windows)](#1-pre-flight-checklist-windows)
2. [Installation Day](#2-installation-day)
3. [First Boot Setup](#3-first-boot-setup)
4. [Using This Repo](#4-using-this-repo)
5. [Configuring Games](#5-configuring-games)
6. [CAD/3D Design Software](#6-cad3d-design-software)
7. [3D Printing Setup](#7-3d-printing-setup)
8. [Post-Install Checklist](#8-post-install-checklist)
9. [Migration Notes](#9-migration-notes)

---

## 1. Pre-Flight Checklist (Windows)

Complete these **before** installation day.

### Automated Migration Context (Recommended)

This section mirrors the command flow in `QUICKSTART.md` with added context.

From repo root on Windows:

```powershell
# 1) Backup payload
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-to-gdrive.ps1 -IncludeDownloads

# 2) Export sanitized migration context for Linux import
powershell -ExecutionPolicy Bypass -File .\scripts\windows\export-migration-context.ps1
```

Then commit sanitized context files (repo or fork):

```powershell
git checkout -b migration/windows/<machine-id>/<yyyymmdd>
git add migration/context/<machine-id>
git commit -m "Add sanitized Windows migration context."
git push -u origin migration/windows/<machine-id>/<yyyymmdd>
```

On Linux, import this context before provisioning:

```bash
./scripts/linux/import-migration-context.sh --context-dir migration/context/<machine-id> --write-local-env --print-restore-plan
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

### Data Backup
```bash
# On Windows, backup:
- Documents
- Downloads  
- Browser profiles (Chrome: %LOCALAPPDATA%\Google\Chrome\User Data)
- Game save files (usually in Documents\My Games)
- 1Password vault export
```

### Identify What You Need to Keep
- [ ] **Game installers** - May need to re-download on Steam
- [ ] **Save files** - Cloud saves sync automatically (Steam), local saves need manual backup
- [ ] **Documents** - OneDrive paths from your current setup:
  ```
  C:\Users\<your-username>\OneDrive\Desktop
  C:\Users\<your-username>\Documents
  ```
- [ ] **Browser bookmarks** - Export from Chrome/Firefox
- [ ] **VPN config** - verify your VPN provider has a Linux client

### Software Equivalents (Linux)

| Windows App | Linux Alternative |
|-------------|-------------------|
| 1Password | 1Password (native Linux) |
| Steam | Steam |
| Epic Games | Heroic Games Launcher |
| GOG Galaxy | Heroic Games Launcher |
| Discord | Discord (native) |
| Docker Desktop | Docker Engine |
| OBS Studio | OBS Studio |
| VirtualBox | VirtualBox / GNOME Boxes |
| VS Code | Cursor / VS Code |
| PowerShell | PowerShell (native) |
| Git | Git |
| Autodesk AutoCAD | None (Windows only) |
| Vendor hardware suites | Usually not required on Linux |
| Malwarebytes | Not needed (Linux) |
| Backblaze | Timeshift / Restic |

### Download Pop_OS! (COSMIC Edition)
1. Go to: https://pop.system76.com
2. Download **Pop!_OS with COSMIC** (recommended)
   - COSMIC is System76's new Rust-based desktop
   - Lighter, faster, built-in tiling
   - Wayland-native
3. Create bootable USB with Rufus or Balena Etcher
4. Verify USB boots on your system

### COSMIC Desktop
COSMIC is the new default desktop for Pop!_OS:
- Built-in tiling window management
- ~400MB RAM (vs GNOME's ~800MB)
- Rust-based for performance
- Settings app for customization
- Super + Space = App launcher
- Super + T = Toggle tiling

---

## 2. Installation Day

For machine-specific dual-boot notes, see:
- `docs/personal/POP_OS_DUAL_BOOT_PLAN.md`

### Boot from USB
1. Insert USB
2. Restart, press **F8** or **DEL** for boot menu
3. Select USB drive
4. Select "Pop!_OS" (Try or Install)

### Partition Configuration

Select **"Custom (Advanced)"** partitioning:

Use these as example layouts. Adapt sizes to your actual disk capacity.

#### Option A: Fresh Install (Wipe Windows)
Use your target Linux SSD/NVMe as target:

```
Device: <target-linux-disk>

/boot/efi      512MB  EFI System Partition
/              200GB  ext4
/home          300GB  ext4  
/mnt/games     ~1.5TB ext4
```

#### Option B: Keep Windows (Dual Boot)
Allocate space from your Linux target disk:

```
Device: <target-linux-disk>

/dev/nvme0n1p1  512MB  EFI System Partition (Windows)
/dev/nvme0n1p2  [Windows partition - leave untouched]
/dev/nvme0n1p3  200GB  ext4  (Pop!_OS root)
/dev/nvme0n1p4  300GB  ext4  (Pop!_OS home)
/dev/nvme0n1p5  ~1.5TB ext4  (/mnt/games)
```

### Complete Installation
1. Select keyboard layout
2. Enter hostname: `<your-hostname>`
3. Create your user account
4. Set password
5. Wait for installation (~10-15 minutes)
6. Remove USB and reboot

---

## 3. First Boot Setup

### Initial System Update
```bash
# Open terminal (Super + T)
sudo apt update && sudo apt upgrade -y
```

### Connect Game Drives
```bash
# List drives
lsblk -f

# Find UUIDs
sudo blkid

# Example output:
# /dev/nvme1n1: UUID="xxxx-xxxx" TYPE="ext4"
```

Add to `/etc/fstab`:
```bash
sudo nano /etc/fstab
```
Add line:
```
UUID=xxxx-xxxx /mnt/games ext4 defaults,nofail 0 2
```

```bash
# Create mount point and mount
sudo mkdir -p /mnt/games
sudo mount -a

# Verify
df -h /mnt/games
```

---

## 4. Using This Repo

### Clone the Repository
```bash
# Install git if needed
sudo apt install -y git

# Clone with HTTPS (or your fork)
git clone <your-fork-url>
cd <repo-directory>

# Optional: import Windows migration context first
./scripts/linux/import-migration-context.sh --context-dir migration/context/<machine-id> --write-local-env --print-restore-plan

# Or run one wrapper that imports + provisions + verifies
./scripts/popos-auto.sh --migration-context migration/context/<machine-id>
```

For unattended automation with known disk layout:

```bash
./scripts/popos-auto.sh --migration-context migration/context/<machine-id> --non-interactive --preset dual-disk
```

### Run Bootstrap
```bash
./bootstrap/bootstrap.sh
```

This will:
- Install Ansible
- Install all base packages (htop, btop, flatpak, etc.)
- Install gaming stack (Steam, Lutris, Heroic, ProtonUp-Qt, mangohud, gamemode)
- Install dev tools (Docker, ZSH, Oh My Zsh)
- Configure UFW firewall

### Run Individual Roles
```bash
cd <repo-directory>

# Base system only
ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags base

# Gaming only  
ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags gaming

# Dev tools only
ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags dev

# Security only
ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags security
```

### Manual Post-Bootstrap Steps

#### 1. Set ZSH as Default Shell
```bash
chsh -s /bin/zsh
```

#### 2. Configure Oh My Zsh
```bash
# Copy config template
cp configs/zshrc.example ~/.zshrc

# Edit with your preferences
nano ~/.zshrc
```

#### 3. Set CPU to Performance Mode
```bash
# Verify cpufrequtils
cpupower frequency-info
```

---

## 5. Configuring Games

### Steam Setup
1. Launch Steam
2. Settings → Compatibility
3. Check "Enable Steam Play for all other titles"
4. Select Proton version (try Experimental first)

#### Add Game Library Folders
1. Settings → Storage
2. Add Library Folder
3. Select `/mnt/games`

#### Recommended Launch Options
For each game, set in Properties → General:
```
mangohud gamemoderun %command%
```

### Heroic Games Launcher (Epic/GOG)
1. Launch Heroic from app menu
2. Settings → Wine/Proton
3. Select Proton or Wine prefix
4. Login to Epic/GOG accounts
5. Set Install Location to `/mnt/games/Heroic`

### Lutris (Battle.net/other non-Steam launchers)
1. Launch Lutris from app menu
2. Add runner or import game installer script
3. Set default game path to `/mnt/games/Lutris`

### Proton GE (Better Compatibility)
1. Open ProtonUp-Qt
2. Download latest Proton GE
3. Select Proton GE in Steam/Heroic

### Optional Flatpak Gaming Tools
- `GAMING_EXTENDED_TOOLS=yes` enables:
  - Flatseal (Flatpak permissions)
  - Warehouse (Flatpak cleanup/manage)
  - Gear Lever (AppImage integration)

Policy note: gaming apps are Flatpak-first when available; Steam stays on apt by design.

---

## 6. CAD/3D Design Software

### Installed via Ansible
| Software | Purpose | Status |
|----------|---------|--------|
| Blender | 3D modeling, animation, rendering | Native |
| FreeCAD | Parametric CAD modeling | Native |
| OpenSCAD | Script-based 3D modeling | Native |
| MeshLab | Mesh processing/cleanup | Native |

### Fusion 360 Options
Fusion 360 can run on Linux via Wine!

#### Option A: Native Fusion 360 via Wine (Recommended)
Using the maintained Codeberg installer script, Fusion 360 runs natively on Linux.

```bash
# Install dependencies
sudo apt install wine wine64 winetricks p7zip-full curl wget cabextract

# Download and run installer
curl -L https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/setup/autodesk_fusion_installer_x86-64.sh -o fusion_installer.sh
chmod +x fusion_installer.sh
./fusion_installer.sh --install --default
```

**Supported Features:**
- Design, Manufacturing, Simulation, Rendering, Drawing, Electronics
- Cloud sync works
- Full functionality (not web version)

**Requirements:**
- Active Fusion 360 license (personal, education, or subscription)
- Verify your GPU meets Autodesk/Wine requirements
- ~5GB disk space

**Automation defaults in this repo:**
- `FUSION360_PROVIDER=codeberg-script`
- `FUSION360_FALLBACK_PROVIDER=bottles`
- `FUSION360_ENABLE_PROTON=no` (enable only when needed for your hardware/runtime)

#### Option B: Fusion 360 Web (Free)
- https://fusion.cloud.autodesk.com
- Limited features but works in browser
- Good for viewing and basic editing

#### Option C: Windows VM
```bash
# Install VirtualBox
sudo apt install virtualbox

# Create Windows VM
# Install Windows 11
# Install Fusion 360 in VM
```

#### Option D: Linux Alternatives
| Software | Similar To | Notes |
|----------|------------|-------|
| FreeCAD | Fusion 360 | Most similar workflow |
| Ondsel | Fusion 360 fork | Actively developed |
| SolveSpace | Fusion 360 | 2D/3D CAD |
| OpenSCAD | Parametric modeling | Code-based |

### Blender Workflow
```bash
# Launch Blender
blender

# Or use Flatpak version (latest)
flatpak run org.blender.Blender
```

### Useful Blender Add-ons
- **Bezier Tools** - Bezier curves for modeling
- **Bool Tool** - Boolean operations
- **Kit OPS** - Parametric parts
- **3D-Print Toolbox** - Check mesh for 3D printing

---

## 7. 3D Printing Setup

### Installed via Ansible
| Software | Purpose |
|----------|---------|
| OrcaSlicer | Primary slicer ( Bambu, Prusa, etc.) |
| PrusaSlicer | Alternative slicer |
| Cura | Ultimaker slicer |
| FreeCAD | 3D model creation |

### OrcaSlicer Setup

#### First Launch
1. Launch OrcaSlicer from app menu
2. Select your printer brand
3. Configure printer settings:
   - Printer type
   - Bed size
   - Nozzle size

#### Recommended Settings for Common Printers

##### Ender 3 V2
```
Printer: Creality Ender-3 V2
Bed Size: 220x220
Nozzle: 0.4mm
Max Temp: 260°C (PLA), 100°C (bed)
```

##### Prusa MK3S+
```
Printer: Prusa i3 MK3S+
Bed Size: 250x210
Nozzle: 0.4mm
Max Temp: 300°C (PLA), 110°C (bed)
```

##### Bambu X1C
```
Printer: Bambu Lab X1 Carbon
Bed Size: 256x256
Nozzle: 0.4mm (included), 0.6mm, 0.8mm
```

### Importing STL Files
```bash
# STL files from Fusion 360
# Export: File → Export → STL

# Open in OrcaSlicer
orcaSlicer --import your_model.stl
```

### Slice Settings Guide

#### PLA
```
Layer Height: 0.2mm
Infill: 15-20%
Supports: Tree or Line
Print Speed: 50-60mm/s
Temperature: 200-210°C
Bed Temp: 60°C
```

#### PETG
```
Layer Height: 0.2mm
Infill: 15-20%
Supports: Line (better adhesion)
Print Speed: 40-50mm/s
Temperature: 240-250°C
Bed Temp: 80°C
```

#### TPU
```
Layer Height: 0.24mm
Infill: 15%
Supports: None (or minimal)
Print Speed: 20-30mm/s
Temperature: 230-250°C
Bed Temp: 50°C
```

### Cura Configuration
```bash
# Launch Cura
cura

# Add printer if not detected
# Settings → Printer → Add Printer
```

### Print Directory
```bash
# Create organized print directory
mkdir -p ~/3dprinting/{models,prints,filament_profiles}

# Suggested structure:
# models/     - STL/3MF files
# prints/     - G-code output
# filament/   - Filament-specific profiles
```

---

## 8. Post-Install Checklist

Run this script to verify everything:
```bash
./scripts/maintenance.sh
```

### Verify GPU
```bash
glxinfo | grep "OpenGL renderer"
# Expected: your active GPU renderer

vulkaninfo --summary
# Should print Vulkan adapter details
```

### Verify Gaming Stack
```bash
# Steam
steam &

# Heroic
heroic &

# Test mangohud
mangohud glxinfo | head -5
```

### Verify Dev Stack
```bash
docker --version
git --version
python3 --version
zsh --version
```

---

## 7. Migration Notes

### Game Save Locations

| Platform | Default Path | Notes |
|----------|-------------|-------|
| Steam | `~/.steam/steam/steamapps/common/` | Cloud saves work |
| Epic | Heroic default | Check Heroic settings |
| GOG | Heroic default | Check Heroic settings |
| Manual | `/mnt/games/<game>` | Create folders manually |

### Import Windows Save Files
```bash
# From external drive or existing partitions
cp -r /media/<your-username>/backup/saves/* ~/.local/share/
```

### Browser Profiles
```bash
# Chrome
cp -r /media/<your-username>/windows_backup/Chrome/* ~/.config/google-chrome/

# Firefox
cp -r /media/<your-username>/windows_backup/Mozilla/* ~/.mozilla/firefox/
```

### 1Password
```bash
# Install 1Password
flatpak install flathub com.1password.1Password

# Or via CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import
```

### Docker
```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group change to take effect

# Test
docker run hello-world
```

---

## Troubleshooting

### "Unable to locate package"
```bash
sudo apt update
```

### Flatpak apps not showing
```bash
flatpak install -y flathub org.freedesktop.Platform//23.08
```

### GPU Issues
```bash
# Reinstall Mesa drivers
sudo apt install --reinstall mesa-vulkan-drivers
```

### Steam not launching
```bash
# Clear prefix
rm -rf ~/.local/share/Steam/steam/cached
rm -rf ~/.steam/steam/cache
```

### DNS Issues
```bash
# Use Cloudflare DNS
sudo nano /etc/systemd/resolved.conf
# Add: DNS=1.1.1.1 1.0.0.1
sudo systemctl restart systemd-resolved
```

---

## 10. Productivity & Communication

### Communication Apps
Installed via Flatpak:
| App | Purpose |
|-----|---------|
| Discord | Gaming voice/text chat |
| Slack | Work communication |
| Zoom | Video conferencing |

### Office Suite
**LibreOffice** is installed as the default office suite:
```bash
# Launch LibreOffice
libreoffice

# Specific apps:
libreoffice --writer   # Word processor
libreoffice --calc     # Spreadsheet
libreoffice --impress  # Presentations
libreoffice --draw     # Drawing
```

#### Microsoft Office Files
LibreOffice opens:
- `.docx`, `.xlsx`, `.pptx` files
- Google Docs/Sheets/Slides via web

### Password Management
**1Password** installed via Flatpak:
```bash
# Launch 1Password
flatpak run com.1password.1Password

# Or from app menu
```

### Cloud Storage

#### Google Drive
Set up with rclone:
```bash
# Run the cloud setup script
./scripts/cloud-setup.sh

# Or configure manually
rclone config
# Choose 'google cloud storage' and follow prompts

# Mount Google Drive
rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full &

# Sync folders
rclone sync ~/Documents gdrive:Documents
```

#### OneDrive (your Windows backup)
```bash
# Install OneDrive client
sudo apt install onedrive

# Connect account
onedrive --synchronize

# Or use rclone
rclone config  # Add OneDrive
```

### Mod Management

#### Vortex (Nexus Mods)
Vortex works on Linux via Lutris/Wine:
```bash
# Install Lutris first
sudo apt install lutris

# Then install Vortex via Lutris GUI
# 1. Open Lutris
# 2. Search for "Vortex"
# 3. Click Install
```

**Supported games on Linux:**
- Any game supported by your selected Proton/Wine stack
- Skyrim (via Proton)
- Fallout 4 (via Proton)
- Most Nexus Mods games

#### Alternative: Mod Organizer 2
```bash
# Install via Proton
# Works with most games through Steam/Proton
```

---

## Next Level (Optional)

- [ ] Set up Timeshift for system snapshots
- [ ] Configure automatic updates
- [ ] Set up game controller mappings
- [ ] Configure OBS for streaming
- [ ] Set up screen recording (for tutorials)
- [ ] Install Vulkan for games
- [ ] Configure RGB lighting (if supported)

---

## Getting Help

- Pop_OS! Discord: https://discord.gg/pop
- /r/pop_os: Reddit community
- ProtonDB: Game compatibility checks
- Arch Wiki: Excellent Linux documentation
