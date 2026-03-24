#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "  Drive & Partition Information"
echo "=============================================="
echo ""

echo "=== Block Devices ==="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID
echo ""

echo "=== Detailed Partition Info ==="
sudo fdisk -l 2>/dev/null | grep -E "^Disk /dev/|/dev/nvme|/dev/sd" | head -20
echo ""

echo "=== File System Details ==="
echo "NVMe Drives:"
ls -la /dev/nvme* 2>/dev/null || echo "  (none found)"
echo ""

echo "=== Mounted Filesystems ==="
df -h
echo ""

echo "=== GPU Information ==="
if command -v lspci &>/dev/null; then
    lspci | grep -iE "vga|3d|display|radeon"
else
    echo "  lspci not available"
fi
echo ""

echo "=== USB Bootable Drives ==="
lsblk -o NAME,SIZE,TYPE,MODEL | grep -i usb || echo "  (no USB drives detected)"
echo ""

echo "=============================================="
echo "  Next Steps"
echo "=============================================="
echo ""
echo "1. Identify target drive for Linux installation"
echo "2. Use 'sudo blkid' to get partition UUIDs"
echo "3. Edit /etc/fstab with proper UUIDs"
echo ""
echo "Example fstab entry:"
echo "  UUID=xxxx-xxxx  /mnt/games  ext4  defaults,nofail  0  2"
echo ""
