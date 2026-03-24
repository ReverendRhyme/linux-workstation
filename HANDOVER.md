# Pop!_OS Workstation Setup

**For AI Agents**: Run the setup with: `cd <repo-directory> && ./scripts/full-setup.sh --profile full`

---

## System Hardware

| Component | Model |
|-----------|-------|
| CPU | AMD Ryzen 5 3600 |
| GPU | AMD Radeon RX 580 (8GB) - Mesa drivers, no proprietary needed |
| RAM | 32GB DDR4 |
| Motherboard | ASUS ROG STRIX X570-F GAMING |
| Desktop | **COSMIC** (Rust-based, Wayland-native) |

## Drive Layout (CRITICAL)

| Drive | Size | Assignment |
|-------|------|-----------|
| /dev/nvme0n1 | 2TB Samsung 990 PRO | **GAMES** (mount: /mnt/games) |
| /dev/nvme1n1 | 1TB WD Blue SN580 | **OS** (mount: /mnt/storage) |
| /dev/sda | 180GB Intel SATA SSD | **Software** (mount: /mnt/software) |
| /dev/sdb | 2TB WD Red | **Backup** (mount: /mnt/backups) |
| /dev/md0 | ~700GB RAID | **Projects** (mount: /mnt/raid) |

**Rule**: OS = smaller drive. Games = larger/faster drive.

---

## Repository Structure

```
linux-workstation/
├── config/
│   ├── defaults.env      # Portable defaults (tracked)
│   └── packages/         # Package lists
├── ansible/
│   ├── inventory.yml
│   ├── site.yml          # Tagged roles by profile
│   └── roles/            # base, gaming, cad, printing, dev, security
├── scripts/
│   ├── popos-auto.sh     # Guided wrapper (recommended)
│   ├── full-setup.sh     # Main orchestrator
│   ├── agent-configure.sh
│   ├── post-install-check.sh
│   └── drive-recommend.sh
└── logs/               # Setup logs
```

---

## Setup Commands

```bash
# 1. Clone repo
git clone https://github.com/ReverendRhyme/linux-workstation.git
cd linux-workstation

# 2. Full setup (run this)
./scripts/full-setup.sh --profile full

# 3. Profile-based setup options
./scripts/full-setup.sh --profile gaming   # Gaming only
./scripts/full-setup.sh --profile dev      # Dev tools only
./scripts/full-setup.sh --profile minimal  # Core utilities only

# 4. Drive detection & recommendations
./scripts/drive-recommend.sh --detect
```

---

## Software Installed by Profile

| Profile | Software |
|---------|----------|
| **full** | All software: gaming, CAD, 3D printing, dev, productivity |
| **gaming** | Steam, Heroic, MangoHud, OrcaSlicer, Bambu Studio |
| **dev** | Docker, ZSH, Git, Python, security tools |
| **minimal** | Core utilities only |

---

## Post-Install Steps

1. **Configure drives**:
   ```bash
   sudo blkid  # Get UUIDs
   sudo nano /etc/fstab
   # Add: UUID=xxx /mnt/games ext4 defaults,nofail 0 2
   ```

2. **Steam**: Enable Steam Play, add library at `/mnt/games`, set launch: `mangohud gamemoderun %command%`

3. **Cloud storage**: Run `./scripts/cloud-setup.sh` for Google Drive/OneDrive

4. **Fusion 360**: `curl -L https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/setup/autodesk_fusion_installer_x86-64.sh -o fusion_installer.sh && chmod +x fusion_installer.sh && ./fusion_installer.sh --install --default`

---

## Troubleshooting

- **GPU check**: `glxinfo | grep "OpenGL renderer"`
- **Steam reset**: `rm -rf ~/.local/share/Steam/steam/cached && steam --reset`
- **Flatpak issue**: `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`

---

## Safety Rules
- Never wipe disks without confirmation
- Use `nofail` in fstab for game drives
- AMD GPU = Mesa drivers only (no proprietary)

---

**Repo**: https://github.com/ReverendRhyme/linux-workstation
