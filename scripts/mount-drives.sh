#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULTS_FILE="$REPO_DIR/config/defaults.env"
LOCAL_CONFIG_FILE="$REPO_DIR/config/deployment.local.env"

if [[ -f "$DEFAULTS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$DEFAULTS_FILE"
fi
if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LOCAL_CONFIG_FILE"
fi

MOUNT_GAMES="${MOUNT_GAMES:-/mnt/games}"
MOUNT_STORAGE="${MOUNT_STORAGE:-/mnt/storage}"
MOUNT_BACKUPS="${MOUNT_BACKUPS:-/mnt/backups}"

echo "=========================================="
echo " Linux Drive Mount Helper"
echo "=========================================="
echo ""

echo "[+] Available block devices:"
lsblk -f
echo ""

echo "[+] To find UUIDs, run:"
echo "    sudo blkid"
echo ""

echo "[+] Example fstab entry:"
echo "    UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX $MOUNT_GAMES ext4 defaults,nofail 0 2"
echo ""

echo "[+] To mount a drive manually:"
echo "    sudo mount /dev/sdX1 $MOUNT_GAMES"
echo ""

echo "[+] Recommended mount points:"
echo "    $MOUNT_GAMES    - Steam/GOG game libraries"
echo "    $MOUNT_STORAGE  - General storage"
echo "    $MOUNT_BACKUPS  - Backup drives"
