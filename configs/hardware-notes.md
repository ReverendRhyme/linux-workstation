# Example Hardware Specification
# Generated from exported hardware notes
# Last Updated: 2026-03-21

## System Summary
| Component | Model |
|-----------|-------|
| OS (Target) | Pop!_OS with COSMIC |
| CPU | AMD Ryzen 5 3600 (Matisse 7nm) |
| RAM | 32GB Dual-Channel DDR4 @ 1176MHz |
| Motherboard | ASUS ROG STRIX X570-F GAMING (AM4) |
| GPU | AMD Radeon RX 580 Series (8GB) |
| Monitor | 2560x1440 (QHD) |

## Desktop Environment
**COSMIC** - System76's Rust-based desktop (replaces GNOME)
- Lighter: ~400MB RAM (vs GNOME's ~800MB)
- Built-in tiling window management
- Wayland-native
- Download: https://pop.system76.com (COSMIC edition)

## Storage Layout & Assignments

| Drive | Size | Type | Recommended Use |
|-------|------|------|----------------|
| nvme0n1 | 2TB | Samsung SSD 990 PRO | **GAMES** (fastest!) |
| nvme1n1 | 1TB | WD Blue SN580 | **OS** (smaller, sufficient) |
| sda | 180GB | Intel SATA SSD | **Software** |
| sdb | 2TB | WD Red HDD | **Bulk storage** |
| sdc | 3x 232GB | Seagate (RAID) | **Software/Projects** |
| sdd | 4.6TB | Seagate USB | External backup |

## Recommended Partition Layout

### OS Drive (WD Blue SN580 1TB)
```
/dev/nvme1n1
├── /boot/efi   512MB  EFI System
├── /           200GB  Root (ext4)
├── /home       300GB  Home (ext4)
└── /mnt/storage  500GB  Projects (ext4)
```

### Games Drive (Samsung SSD 990 PRO 2TB)
```
/dev/nvme0n1
└── /mnt/games  2TB  Games (ext4)
```

### Software Drive (Intel SATA SSD or RAID)
```
/dev/sda  (or RAID array /dev/md0)
└── /mnt/software  ext4  Software installs, Docker
```

### Bulk Storage (WD Red 2TB)
```
/dev/sdb
└── /mnt/backups  ext4  Archives, backups
```

## Mount Points

| Mount | Drive | Purpose |
|-------|-------|---------|
| `/mnt/games` | 990 PRO (2TB) | All game libraries |
| `/mnt/software` | SATA SSD/RAID | Software, projects, Docker |
| `/mnt/storage` | OS drive | Frequently-accessed files |
| `/mnt/backups` | WD Red (2TB) | Archives, backups |

## Why This Layout?

- **Games on 990 PRO**: Fastest NVMe = best loading times
- **OS on SN580**: Smaller drive is fine (OS needs ~100GB)
- **Software on SATA/RAID**: Standard installs don't need NVMe speed
- **Bulk on HDD**: Cheap storage for archives

## GPU Notes
- AMD RX 580: Excellent Linux support via Mesa/open-source drivers
- No proprietary drivers needed
- Vulkan support: Excellent
- Proton compatibility: High

## Gaming Considerations
- Steam + Proton: Works great
- Heroic (Epic/GOG): Works great
- Anti-cheat games (CoD, Fortnite): May have issues
- Most other games: Full compatibility expected

## Power Management
- Current: AMD Ryzen Balanced power scheme
- Linux: Set CPU governor to `performance` via cpufrequtils
- Disable: Ondemand/powersave governors
