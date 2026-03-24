#!/usr/bin/env bash
set -euo pipefail

# Windows Backup Helper
# Run this BEFORE installing Pop_OS! on Windows

echo "=============================================="
echo "  Windows Backup Helper"
echo "=============================================="
echo ""
echo "This script helps you identify files to backup"
echo "BEFORE migrating to Pop_OS!"
echo ""

BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"
echo ""

echo "=== Important Paths to Backup ==="
echo ""

check_path() {
    local path="$1"
    local desc="$2"
    if [ -e "$path" ]; then
        local size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "unknown")
        echo -e "  [\033[0;32mOK\033[0m] $desc"
        echo "         $path ($size)"
    else
        echo -e "  [\033[0;33m--\033[0m] $desc (not found)"
        echo "         $path"
    fi
}

check_path "$USERPROFILE/Desktop" "Desktop"
check_path "$USERPROFILE/Documents" "Documents"
check_path "$USERPROFILE/Downloads" "Downloads"
check_path "$USERPROFILE/Favorites" "Favorites"
check_path "$APPDATA/Local/Google/Chrome/User Data" "Chrome Profile"
check_path "$APPDATA/Mozilla/Firefox/Profiles" "Firefox Profiles"

echo ""
echo "=== Game Save Locations ==="

check_path "C:/Program Files (x86)/Steam/userdata" "Steam Saves"
check_path "$LOCALAPPDATA/EpicGamesLauncher/Saved" "Epic Games Saves"
check_path "C:/ProgramData/Epic" "Epic Data"

echo ""
echo "=== Recommended Copy Commands ==="
echo ""
echo "# Run these to backup to external drive (E: in this example):"
echo ""
echo 'xcopy /E /I /Y "%USERPROFILE%\Desktop" "E:\backups\Desktop\\"'
echo 'xcopy /E /I /Y "%USERPROFILE%\Documents" "E:\backups\Documents\\"'
echo 'xcopy /E /I /Y "%LOCALAPPDATA%\Google\Chrome\User Data\Default" "E:\backups\Chrome\\"'
echo ""

echo "=== Quick Steam Library Backup ==="
echo ""
echo "# Steam library locations:"
if [ -d "C:/Program Files (x86)/Steam/steamapps/common" ]; then
    echo "  C:/Program Files (x86)/Steam/steamapps/"
fi
if [ -d "D:/SteamLibrary/steamapps" ]; then
    echo "  D:/SteamLibrary/steamapps/"
fi
echo ""
echo "Note: You can also use Steam's Backup feature:"
echo "  Steam → Settings → Backup and Restore"
echo ""

echo "=============================================="
echo "  Post-Backup Checklist"
echo "=============================================="
echo ""
echo "[ ] Desktop files copied"
echo "[ ] Documents copied"
echo "[ ] Browser bookmarks exported"
echo "[ ] Game save locations noted"
echo "[ ] 1Password vault exported"
echo "[ ] External drive verified"
echo ""

echo "After Pop_OS! install, see:"
echo "  - PREFLIGHT_CHECKLIST.md"
echo "  - SETUP_GUIDE.md"
echo ""
