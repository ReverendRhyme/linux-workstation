#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "  Google Drive Setup with rclone"
echo "=============================================="
echo ""

echo "This script sets up rclone for Google Drive sync."
echo ""

echo "=== 1. Install rclone (if not installed) ==="
if ! command -v rclone &>/dev/null; then
    echo "[+] Installing rclone..."
    curl https://rclone.org/install.sh | sudo bash
else
    echo "[✓] rclone already installed: $(rclone version | head -1)"
fi

echo ""
echo "=== 2. Configure Google Drive ==="
echo "[+] Running rclone config..."
rclone config

echo ""
echo "=== 3. Create mount point ==="
mkdir -p ~/GoogleDrive

echo ""
echo "=== 4. Test mount ==="
echo "To mount Google Drive manually:"
echo "  rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full &"
echo ""
echo "To unmount:"
echo "  fusermount -u ~/GoogleDrive"
echo ""

echo "=== 5. Auto-mount with systemd (optional) ==="
echo "To set up automatic mounting, run:"
echo "  rclone --vfs-cache-mode full mount gdrive: ~/GoogleDrive &"
echo ""

echo "=== 6. OneDrive sync (if needed) ==="
echo "You can also configure OneDrive:"
echo "  rclone config"
echo "  # Choose 'onedrive' as the cloud storage type"
echo ""

echo "=============================================="
echo "  Useful rclone Commands"
echo "=============================================="
echo ""
echo "# List files"
echo "  rclone ls gdrive:"
echo ""
echo "# Copy files to Google Drive"
echo "  rclone copy /path/to/files gdrive:backup/"
echo ""
echo "# Sync local folder to Google Drive"
echo "  rclone sync ~/Documents gdrive:Documents"
echo ""
echo "# Mount as network drive"
echo "  rclone mount gdrive: ~/GoogleDrive --allow-other &"
echo ""

echo "=============================================="
echo "  OneDrive Configuration"
echo "=============================================="
echo ""
echo "Your Windows side uses OneDrive. Options on Linux:"
echo ""
echo "1. rclone (recommended):"
echo "   rclone config  # Add OneDrive"
echo "   rclone sync ~/OneDrive onedrive:"
echo ""
echo "2. OneDrive FreeClient (native):"
echo "   sudo apt install onedrive"
echo "   onedrive --synchronize"
echo ""
echo "3. Cloud sync apps:"
echo "   - Insync (paid, polished)"
echo "   - rclone (free, CLI)"
echo ""

echo "Done! Run 'rclone config' to set up your cloud storage."
