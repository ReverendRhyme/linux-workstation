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
REPO_NAME="${REPO_NAME:-linux-workstation}"
REPO_URL="${REPO_URL:-https://github.com/ReverendRhyme/linux-workstation}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECK_MARK="${GREEN}✓${NC}"
CROSS_MARK="${RED}✗${NC}"
INFO_MARK="${BLUE}→${NC}"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Pop_OS! Post-Install Checklist${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "  ${CHECK_MARK} $2"
    else
        echo -e "  ${CROSS_MARK} $2"
    fi
}

section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "${BLUE}System Checks${NC}"
echo "-----------------------------------"

echo -e "  ${INFO_MARK} Pop!_OS Version:"
cat /etc/os-release | grep PRETTY_NAME || echo "Unknown"

echo ""
echo -e "  ${INFO_MARK} Kernel:"
uname -r

echo ""
echo -e "  ${INFO_MARK} Uptime:"
uptime -p 2>/dev/null || uptime

section "System Updates"

sudo apt update -qq
check_result $? "Package lists updated"

sudo apt upgrade -y -qq
check_result $? "System packages updated"

section "GPU Verification"

if command -v glxinfo &>/dev/null; then
    GPU=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1)
    if [[ "$GPU" == *"AMD"* ]] || [[ "$GPU" == *"Radeon"* ]]; then
        echo -e "  ${CHECK_MARK} AMD GPU detected: ${GPU##*= }"
    else
        echo -e "  ${YELLOW}⚠ ${NC} GPU: ${GPU##*= }"
    fi
else
    echo -e "  ${CROSS_MARK} glxinfo not available"
fi

if command -v vulkan-smoke &>/dev/null; then
    vulkan-smoke 2>/dev/null | head -3 && check_result 0 "Vulkan working" || check_result 1 "Vulkan issue"
elif command -v vulkaninfo &>/dev/null; then
    vulkaninfo 2>/dev/null | head -10 && check_result 0 "Vulkan working" || check_result 1 "Vulkan issue"
else
    echo -e "  ${YELLOW}⚠ ${NC} Vulkan tools not installed (optional)"
fi

section "Gaming Stack"

command -v steam &>/dev/null
check_result $? "Steam installed"

command -v heroic &>/dev/null || flatpak list 2>/dev/null | grep -q heroic
check_result $? "Heroic Games Launcher"

command -v mangohud &>/dev/null
check_result $? "MangoHud"

command -v gamemoderun &>/dev/null
check_result $? "Gamemode"

command -v protonup-qt &>/dev/null || flatpak list 2>/dev/null | grep -q protonup
check_result $? "ProtonUp-Qt"

section "Development Tools"

command -v git &>/dev/null
check_result $? "Git"

command -v docker &>/dev/null
check_result $? "Docker"

if command -v docker &>/dev/null; then
    docker ps &>/dev/null && check_result 0 "Docker daemon running" || check_result 1 "Docker daemon not running"
fi

command -v zsh &>/dev/null
check_result $? "ZSH"

[ -d "$HOME/.oh-my-zsh" ] 2>/dev/null
check_result $? "Oh My Zsh"

command -v python3 &>/dev/null
check_result $? "Python 3"

section "System Utilities"

command -v btop &>/dev/null
check_result $? "btop"

command -v ncdu &>/dev/null
check_result $? "ncdu"

command -v bat &>/dev/null
check_result $? "bat"

command -v fzf &>/dev/null
check_result $? "fzf"

section "Storage"

echo -e "  ${INFO_MARK} Mounted drives:"
df -h --output=source,size,used,avail,mountpoint | grep -E "^/dev|nvme|mmc" | head -10 || echo "  (none found)"

echo ""
echo -e "  ${INFO_MARK} Game mount check:"
if [ -d "$MOUNT_GAMES" ]; then
    df -h "$MOUNT_GAMES" && check_result 0 "$MOUNT_GAMES accessible" || check_result 1 "$MOUNT_GAMES not mounted"
else
    echo -e "  ${YELLOW}⚠ ${NC} $MOUNT_GAMES not created"
fi

section "Security"

if command -v ufw &>/dev/null; then
    ufw status | grep -q "Status: active"
    check_result $? "UFW firewall enabled"
else
    echo -e "  ${YELLOW}⚠ ${NC} UFW not installed"
fi

section "Flatpak Apps"

FLATPAK_COUNT=$(flatpak list 2>/dev/null | wc -l)
if [ "$FLATPAK_COUNT" -gt 0 ]; then
    echo -e "  ${CHECK_MARK} Flatpak installed: ${FLATPAK_COUNT} apps"
    flatpak list 2>/dev/null | head -5 | while read line; do
        echo -e "      ${line}"
    done
else
    echo -e "  ${YELLOW}⚠ ${NC} No Flatpak apps installed"
fi

section "Repository Status"

if [ -d "$REPO_DIR/.git" ]; then
    echo -e "  ${CHECK_MARK} $REPO_NAME repo detected"
    cd "$REPO_DIR"
    if git fetch &>/dev/null; then
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "$LOCAL")
        if [ "$LOCAL" = "$REMOTE" ]; then
            echo -e "  ${CHECK_MARK} Repo is up to date"
        else
            echo -e "  ${YELLOW}⚠ ${NC} Repo has unpushed commits"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠ ${NC} repository metadata not found at $REPO_DIR"
    echo -e "      Run: git clone $REPO_URL"
fi

section "Next Steps"

cat << 'EOF'

  To complete setup:

  1. Clone repo (if not present):
     git clone <repo-url>

  2. Run bootstrap:
     cd <repo-directory>
     ./bootstrap/bootstrap.sh

  3. Configure game drives:
     ./scripts/mount-drives.sh

  4. Set ZSH as default:
     chsh -s /bin/zsh

  5. Launch Steam, enable Proton

  6. Launch Heroic, login to Epic/GOG

  7. Install Proton GE via ProtonUp-Qt

EOF

section "Resources"

cat << 'EOF'

  Documentation:
    - README.md          - Overview
    - SETUP_GUIDE.md     - Detailed walkthrough
    - configs/hardware-notes.md  - Hardware spec

  Useful Commands:
    - btop               - System monitor
    - ncdu -x /          - Disk usage
    - mangohud %command%  - FPS overlay
    - gamemoderun %cmd%   - Performance mode

EOF

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Checklist Complete${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
