# Pre-Installation Checklist (Windows Side)

Complete this checklist **before** installing Pop_OS! to ensure a smooth migration.

---

## 1. Data Backup

### Essential Files to Copy
- [ ] **Documents** - `C:\Users\<your-username>\Documents`
- [ ] **Desktop** - `C:\Users\<your-username>\OneDrive\Desktop`
- [ ] **Downloads** - `C:\Users\<your-username>\Downloads` (optional)
- [ ] **Browser Bookmarks** - Chrome/Firefox
- [ ] **Game Save Files** - Usually in `Documents\My Games`
- [ ] **1Password Vault** - Export from 1Password app

### Backup Location
Copy to external drive or cloud:
- External SSD/HDD
- Backblaze (if installed)
- OneDrive (already synced)

### Game Save Backup Locations
```
Steam:           C:\Program Files (x86)\Steam\userdata\
Epic Games:      C:\ProgramData\Epic\EpgData\
GOG Galaxy:      C:\Program Files (x86)\GOG Galaxy\Games\
Manual Games:    Check individual game settings
```

---

## 2. Software Inventory

### Must-Have on Linux
| Software | Status | Linux Alternative |
|----------|--------|-------------------|
| Steam | [ ] | Steam (native) |
| Discord | [ ] | Discord (native) |
| 1Password | [ ] | 1Password (native) |
| Git | [ ] | Git (native) |
| Docker | [ ] | Docker Engine |
| VS Code / Cursor | [ ] | Same apps |
| OBS Studio | [ ] | OBS Studio (native) |
| PowerShell | [ ] | PowerShell (native) |

### Nice-to-Have
| Software | Status | Linux Alternative |
|----------|--------|-------------------|
| Epic Games | [ ] | Heroic Games Launcher |
| GOG Galaxy | [ ] | Heroic Games Launcher |
| VirtualBox | [ ] | VirtualBox / GNOME Boxes |
| Notion | [ ] | Notion (web) |
| Spotify | [ ] | Spotify (native) |
| VLC | [ ] | VLC (native) |

### Won't Work on Linux
| Software | Status | Notes |
|----------|--------|-------|
| Autodesk AutoCAD | [ ] | Windows only - use VM |
| Microsoft Office | [ ] | Use LibreOffice or web |
| Adobe CC | [ ] | Some apps work via PlayOnLinux |
| Vendor hardware suites | [ ] | Usually not needed on Linux |
| Nahimic | [ ] | Not needed |

---

## 3. Steam Library Assessment

### List Your Games
1. Open Steam → Library
2. Note which games you play most
3. Check ProtonDB for compatibility

### High Priority Games (Check First)
```
[ ] Game 1: _____________  | ProtonDB Rating: _______
[ ] Game 2: _____________  | ProtonDB Rating: _______
[ ] Game 3: _____________  | ProtonDB Rating: _______
```

### Games Likely to Work (Proton)
- Most single-player games
- Indie games
- Games without anti-cheat
- Most DirectX 11/12 titles rated Gold/Platinum on ProtonDB

Example titles (reference only):
- Elder Scrolls V: Skyrim
- Baldur's Gate 3
- Cyberpunk 2077

### Games That May NOT Work
- Call of Duty (anti-cheat)
- Fortnite (anti-cheat)
- Valorant (anti-cheat)
- Destiny 2 (anti-cheat)

---

## 4. Account Information

### Verify Access To
- [ ] Steam account (login + password)
- [ ] Epic Games account (login + password)
- [ ] GOG account (login + password)
- [ ] 1Password account (login + password)
- [ ] Discord account (login + password)
- [ ] GitHub account (login + password)

### Enable 2FA
- [ ] Steam Mobile Authenticator
- [ ] Epic Games 2FA
- [ ] GitHub 2FA
- [ ] Discord 2FA

---

## 5. Hardware Verification

### Boot from USB Test
Before installation day:
1. Create Pop_OS! USB (8GB+ drive)
2. Restart computer
3. Press **F8** or **DEL** to enter boot menu
4. Select USB drive
5. Verify it boots to Pop_OS! live environment

### Check These Work in Live Environment
- [ ] WiFi connects
- [ ] Display uses native monitor resolution
- [ ] Keyboard/mouse work
- [ ] Sound plays
- [ ] Files can be accessed

---

## 6. Download Required Files

### Pop_OS! ISO
- [ ] Download from: https://pop.system76.com
- [ ] Verify ISO checksum (optional)
- [ ] Create bootable USB with Rufus or Balena Etcher

### Recommended USB Size
8GB minimum (ISO is ~4GB)

### Tools for USB Creation
- **Windows**: Rufus (https://rufus.ie)
- **macOS/Linux**: Balena Etcher (https://etcher.balena.io)
- **From Windows**: Pop official installer

---

## 7. Partition Planning

### Example Current Drives
```
Primary SSD/NVMe         -> Target for Linux
Secondary SSD/NVMe       -> Optional games/storage
SATA SSD/HDD             -> Legacy/archive
External/backup drive    -> Offline backup
```

### Decision: Fresh Install or Dual Boot?

#### Option A: Fresh Install (Recommended)
```
Target Linux disk:
  - Entire drive for Linux
  - Windows will be wiped
  - Need to backup Windows data first
```

#### Option B: Dual Boot
```
Target Linux disk:
  - Keep Windows partition (~500GB)
  - Linux partition (~1.5TB)
  - Requires careful partitioning
```

### Recommendation
**Option A: Fresh Install**

Reasons:
1. You're switching to Linux
2. Easier to manage
3. No Windows bloat
4. Full NVMe for Linux

---

## 8. Windows Cleanup (Optional)

### Before Wiping
1. **Uninstall unnecessary apps** - Reduce bloat
2. **Clear browser caches** - Save space
3. **Empty recycle bin** - Free space
4. **Defragment drives** - Not needed for SSD

### License Keys (Usually Digital)
- Windows license is tied to Microsoft account
- Office 365 is subscription-based
- Most games are digital (Steam/Epic)

---

## 9. Day-Of Checklist

### Before You Start Installation
- [ ] External backup drive connected
- [ ] Pop_OS! USB created and tested
- [ ] External monitor available (if needed)
- [ ] Backup of essential files verified
- [ ] Account credentials noted
- [ ] Several hours set aside

### Time Estimate
- Backup: 30-60 min
- Installation: 15-30 min
- Initial setup: 1-2 hours
- Game library setup: 1-2 hours
- **Total: ~3-5 hours**

---

## 10. Emergency Contacts

### If Things Go Wrong
- **Pop_OS! Documentation**: https://pop.system76.com/docs
- **Ask Ubuntu**: https://askubuntu.com
- **Reddit r/pop_os**: https://reddit.com/r/pop_os
- **Discord Pop_OS!**: https://discord.gg/pop

---

## Checklist Complete?

Once you've completed all sections above:

1. ✅ All important data backed up
2. ✅ Pop_OS! USB created
3. ✅ Games identified
4. ✅ Accounts verified
5. ✅ Decision made (fresh install vs dual boot)

**You're ready for installation day!**

---

*Print or save this file for reference during installation.*
