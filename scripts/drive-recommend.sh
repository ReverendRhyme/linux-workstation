#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Drive Detection & Recommendation Script
# 
# Detects all drives, analyzes them, and makes recommendations for:
# - OS installation
# - Game storage
# - General storage
#
# Usage:
#   ./scripts/drive-recommend.sh          # Interactive mode
#   ./scripts/drive-recommend.sh --auto  # Auto mode (no prompts)
#   ./scripts/drive-recommend.sh --list   # List drives only
#
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRIVES=()
RECOMMENDATIONS=()

log() { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
header() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

###############################################################################
# Drive Classification
###############################################################################

classify_drive() {
    local device="$1"
    local size_gb="$2"
    local drive_type="$3"  # nvme, ssd, or hdd
    local speed="" speed_class=""
    
    # Check for NVMe
    if [[ "$device" == *"nvme"* ]]; then
        drive_type="nvme"
    elif [[ -f /sys/block/${device}/queue/rotational ]]; then
        if [[ $(cat /sys/block/${device}/queue/rotational) == "0" ]]; then
            drive_type="ssd"
        else
            drive_type="hdd"
        fi
    fi
    
    # Classify by size
    if [[ $size_gb -lt 500 ]]; then
        size_class="small"
    elif [[ $size_gb -lt 2000 ]]; then
        size_class="medium"
    else
        size_class="large"
    fi
    
    echo "$drive_type|$size_class"
}

get_drive_speed() {
    local device="$1"
    local speed=""
    
    # Try to get NVMe speed
    if [[ "$device" == *"nvme"* ]]; then
        if [[ -f /sys/block/${device}/device/subsystem_vendor ]]; then
            # NVMe typically has better speeds
            speed="fast"
        fi
    fi
    
    # Check rotation speed for HDDs
    if [[ -f /sys/block/${device}/queue/rotation_rate ]]; then
        local rpm=$(cat /sys/block/${device}/queue/rotation_rate 2>/dev/null || echo "0")
        if [[ $rpm -gt 5000 ]]; then
            speed="fast_hdd"
        elif [[ $rpm -gt 0 ]]; then
            speed="slow_hdd"
        fi
    fi
    
    echo "${speed:-unknown}"
}

get_drive_model() {
    local device="$1"
    local model=""
    
    if [[ -f /sys/block/${device}/device/model ]]; then
        model=$(cat /sys/block/${device}/device/model 2>/dev/null | tr -d ' ')
    elif [[ -f /sys/block/${device}/device/name ]]; then
        model=$(cat /sys/block/${device}/device/name 2>/dev/null | tr -d ' ')
    fi
    
    echo "${model:-Unknown}"
}

###############################################################################
# Analyze Drives
###############################################################################

analyze_drives() {
    header "Drive Analysis"
    
    log "Scanning all block devices..."
    echo ""
    
    local index=1
    DRIVES=()
    
    # Get all block devices except loop and ram
    for device in $(lsblk -d -n -o NAME,SIZE,TYPE | grep -E "disk|nvme" | awk '{print $1}'); do
        # Skip loop and ram devices
        [[ "$device" == loop* ]] && continue
        [[ "$device" == ram* ]] && continue
        
        # Get drive info
        local size=$(lsblk -d -n -o SIZE /dev/${device} 2>/dev/null | head -1)
        local size_gb=$(echo "$size" | numfmt --from=auto --to=iec 2>/dev/null | grep -oP '\d+' || echo "0")
        local model=$(get_drive_model "$device")
        local drive_speed=$(get_drive_speed "$device")
        local mount_point=$(lsblk -d -n -o MOUNTPOINT /dev/${device} 2>/dev/null | head -1 | tr -d ' ')
        local fstype=$(lsblk -d -n -o FSTYPE /dev/${device} 2>/dev/null | head -1 | tr -d ' ')
        local uuid=$(blkid -s UUID -o value /dev/${device}* 2>/dev/null | head -1 || echo "none")
        
        # Classify
        local classification=$(classify_drive "$device" "$size_gb" "")
        local drive_type=$(echo "$classification" | cut -d'|' -f1)
        local size_class=$(echo "$classification" | cut -d'|' -f2)
        
        # Format size for display
        local size_display=$(lsblk -d -n -o SIZE /dev/${device} 2>/dev/null | head -1)
        
        # Store drive info
        DRIVES+=("$device|$size_display|$drive_type|$size_class|$drive_speed|$model|$mount_point|$fstype")
        
        # Display
        echo -e "${BLUE}[$index] /dev/$device${NC}"
        echo "    Model: $model"
        echo "    Size: $size_display ($drive_type, $size_class)"
        echo "    Speed Class: $drive_speed"
        
        if [[ -n "$mount_point" ]]; then
            echo -e "    ${GREEN}Mounted: $mount_point${NC}"
        else
            echo -e "    ${YELLOW}Not mounted${NC}"
        fi
        
        if [[ -n "$fstype" && "$fstype" != "null" ]]; then
            echo "    Filesystem: $fstype"
        fi
        
        echo ""
        ((index++))
    done
    
    if [[ ${#DRIVES[@]} -eq 0 ]]; then
        error "No drives detected!"
        return 1
    fi
    
    log "Found ${#DRIVES[@]} drives"
}

###############################################################################
# Make Recommendations
###############################################################################

make_recommendations() {
    header "Recommended Configuration"
    
    echo "Based on your hardware, here's the optimal setup:"
    echo ""
    
    local os_drive=""
    local game_drive=""
    local storage_drive=""
    
    # Sort drives by type and size
    local nvme_drives=()
    local ssd_drives=()
    local hdd_drives=()
    
    for drive in "${DRIVES[@]}"; do
        local type=$(echo "$drive" | cut -d'|' -f3)
        local size=$(echo "$drive" | cut -d'|' -f2)
        
        case "$type" in
            nvme) nvme_drives+=("$drive") ;;
            ssd) ssd_drives+=("$drive") ;;
            hdd) hdd_drives+=("$drive") ;;
        esac
    done
    
    echo -e "${CYAN}Recommended Layout:${NC}"
    echo ""
    
    # Strategy:
    # - OS Drive: Use SMALLER drive (OS doesn't need much space)
    # - Game Drive: Use LARGER drive (games need space + fast NVMe is great)
    # - Storage: Use HDDs for bulk storage
    
    # Collect all drives with sizes
    local all_drives=()
    for drive in "${DRIVES[@]}"; do
        all_drives+=("$drive")
    done
    
    # Find smallest fast drive for OS
    echo -e "${GREEN}OS Drive (Pop!_OS):${NC}"
    local smallest_fast=""
    local smallest_size=""
    local smallest_device=""
    
    # Get sizes as numbers for comparison
    for drive in "${all_drives[@]}"; do
        local type=$(echo "$drive" | cut -d'|' -f3)
        local device=$(echo "$drive" | cut -d'|' -f1)
        local size_str=$(echo "$drive" | cut -d'|' -f2)
        local model=$(echo "$drive" | cut -d'|' -f6)
        
        # Convert to GB for comparison
        local size_gb=0
        if [[ "$size_str" == *"T"* ]]; then
            size_gb=$(echo "$size_str" | tr -d 'A-Z' | awk '{print $1 * 1000}')
        else
            size_gb=$(echo "$size_str" | tr -d 'A-Z' | awk '{print $1}')
        fi
        
        # Skip HDDs for OS/Games
        [[ "$type" == "hdd" ]] && continue
        
        if [[ -z "$smallest_fast" ]] || [[ $size_gb -lt $smallest_size ]]; then
            smallest_fast="$drive"
            smallest_size=$size_gb
            smallest_device="$device"
        fi
    done
    
    if [[ -n "$smallest_fast" ]]; then
        local os_size=$(echo "$smallest_fast" | cut -d'|' -f2)
        local os_model=$(echo "$smallest_fast" | cut -d'|' -f6)
        local os_type=$(echo "$smallest_fast" | cut -d'|' -f3)
        echo "  → /dev/$smallest_device ($os_size - $os_type)"
        echo "    Model: $os_model"
        echo "    Recommendation: Use smaller/faster drive for OS"
        os_drive="/dev/$smallest_device"
    fi
    echo ""
    
    # Find LARGEST fast drive for Games
    echo -e "${GREEN}Game Drive:${NC}"
    local largest_fast=""
    local largest_size=0
    local largest_device=""
    
    for drive in "${all_drives[@]}"; do
        local type=$(echo "$drive" | cut -d'|' -f3)
        local device=$(echo "$drive" | cut -d'|' -f1)
        local size_str=$(echo "$drive" | cut -d'|' -f2)
        
        # Skip OS drive and HDDs
        [[ "$device" == "$smallest_device" ]] && continue
        [[ "$type" == "hdd" ]] && continue
        
        # Convert to GB for comparison
        local size_gb=0
        if [[ "$size_str" == *"T"* ]]; then
            size_gb=$(echo "$size_str" | tr -d 'A-Z' | awk '{print $1 * 1000}')
        else
            size_gb=$(echo "$size_str" | tr -d 'A-Z' | awk '{print $1}')
        fi
        
        if [[ $size_gb -gt $largest_size ]]; then
            largest_fast="$drive"
            largest_size=$size_gb
            largest_device="$device"
        fi
    done
    
    if [[ -n "$largest_fast" ]]; then
        local game_size=$(echo "$largest_fast" | cut -d'|' -f2)
        local game_model=$(echo "$largest_fast" | cut -d'|' -f6)
        local game_type=$(echo "$largest_fast" | cut -d'|' -f3)
        echo "  → /dev/$largest_device ($game_size - $game_type)"
        echo "    Model: $game_model"
        echo "    Recommendation: Use LARGER drive for games (space + speed)"
        game_drive="/dev/$largest_device"
    else
        echo "  → No dedicated game drive found"
        echo "    Install games on OS drive or add additional SSD"
    fi
    echo ""
    
    # Storage Drive
    echo -e "${GREEN}Storage Drive:${NC}"
    local found_storage=0
    
    if [[ ${#hdd_drives[@]} -gt 0 ]]; then
        local storage="${hdd_drives[0]}"
        local device=$(echo "$storage" | cut -d'|' -f1)
        local size=$(echo "$storage" | cut -d'|' -f2)
        local speed=$(echo "$storage" | cut -d'|' -f5)
        echo "  → /dev/$device ($size - HDD)"
        echo "    Recommendation: Bulk storage, backups"
        storage_drive="/dev/$device"
        found_storage=1
    fi
    
    if [[ $found_storage -eq 0 ]]; then
        echo "  → No HDDs found"
        echo "    Recommendation: Consider adding HDD for backups"
    fi
    echo ""
    
    # Check for RAID arrays
    local raid_found=0
    echo -e "${GREEN}RAID Arrays:${NC}"
    if [[ -d /dev/md ]]; then
        local raid_devices=$(ls /dev/md* 2>/dev/null | grep -v "p" | wc -l)
        if [[ $raid_devices -gt 0 ]]; then
            echo "  Found $raid_devices RAID array(s):"
            for raid in $(ls /dev/md* 2>/dev/null | grep -v "p"); do
                local raid_size=$(cat /sys/block/$(basename $raid)/size 2>/dev/null)
                if [[ -n "$raid_size" ]]; then
                    local size_tb=$(echo "scale=2; $raid_size / 2 / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "?")
                    echo "    $raid (${size_tb}TB)"
                fi
            done
            echo "  → Use for software installs, projects, or backup"
            raid_found=1
        fi
    fi
    
    if [[ $raid_found -eq 0 ]]; then
        echo "  No RAID arrays detected"
        echo "  (If you have RAID configured, verify mdadm is installed)"
    fi
    echo ""
    
    # Summary
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Complete Drive Layout${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "OS:         $os_drive"
    echo "Games:      $game_drive"
    echo "Software:   SATA/RAID drives (software installs)"
    echo "Storage:    $storage_drive"
    echo ""
    echo "Mount Points:"
    echo "  /mnt/games    - Games library (990 PRO)"
    echo "  /mnt/software - Software installs (SATA SSD/RAID)"
    echo "  /mnt/storage  - Bulk storage (HDD)"
    echo ""
    
    # Store recommendations globally
    REC_OS_DRIVE="$os_drive"
    REC_GAME_DRIVE="$game_drive"
    REC_STORAGE_DRIVE="$storage_drive"
}

###############################################################################
# Interactive Partition Planning
###############################################################################

plan_partitions() {
    header "Partition Planning"
    
    echo "This will help you plan your partitions."
    echo ""
    
    echo -e "${CYAN}Recommended Partition Layout:${NC}"
    echo ""
    
    echo "Drive 1 - OS (1TB NVMe):"
    echo "  Device: $REC_OS_DRIVE"
    echo "  ├── /boot/efi   512MB  EFI System Partition"
    echo "  ├── /           200GB  Root (ext4)"
    echo "  ├── /home       300GB  Home (ext4)"
    echo "  └── /mnt/storage  500GB  Projects/Documents (ext4)"
    echo ""
    
    echo "Drive 2 - GAMES (2TB NVMe):"
    echo "  Device: $REC_GAME_DRIVE"
    echo "  └── /mnt/games  entire drive (ext4)"
    echo "      - Steam library"
    echo "      - GOG library"
    echo "      - Epic library"
    echo "      - Heroic downloads"
    echo ""
    
    echo "Drive 3 - SOFTWARE (SATA SSD/RAID):"
    echo "  Suggested mount: /mnt/software"
    echo "  - Docker volumes"
    echo "  - Flatpak apps (alternative)"
    echo "  - Development projects"
    echo "  - Software builds"
    echo ""
    
    echo "Drive 4+ - BULK STORAGE (HDD):"
    echo "  Suggested mount: /mnt/backup"
    echo "  - Archives"
    echo "  - Backups"
    echo "  - Media library"
    echo ""
    
    read -p "Would you like me to show fstab entries for your drives? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        show_fstab_examples
    fi
}

show_fstab_examples() {
    header "Example fstab Entries"
    
    echo "Add these to /etc/fstab for auto-mounting:"
    echo ""
    
    echo "# Games drive (fastest NVMe)"
    echo "# UUID=<uuid> /mnt/games ext4 defaults,nofail 0 2"
    echo ""
    
    echo "# Software installs (SATA SSD or RAID array)"
    echo "# UUID=<uuid> /mnt/software ext4 defaults,nofail 0 2"
    echo ""
    
    echo "# Bulk storage (HDD)"
    echo "# UUID=<uuid> /mnt/backup ext4 defaults,nofail 0 2"
    echo ""
    
    echo "To find UUIDs after installation:"
    echo "  sudo blkid"
    echo ""
    
    echo "For RAID arrays, use /dev/mdX instead of UUID:"
    echo "  /dev/md0 /mnt/software ext4 defaults,nofail 0 2"
}

###############################################################################
# Check Current Partitioning
###############################################################################

check_current_setup() {
    header "Current Partitioning"
    
    echo "Current mount points:"
    echo ""
    df -h --output=source,size,used,avail,target | grep -E "^/dev|nvme|ssd" | head -20 || echo "  (none mounted yet)"
    echo ""
    
    echo "Current /etc/fstab entries:"
    echo ""
    grep -v "^#" /etc/fstab 2>/dev/null | grep -v "^$" | head -10 || echo "  (no custom entries)"
    echo ""
}

###############################################################################
# Detect and Recommend
###############################################################################

detect_and_recommend() {
    analyze_drives
    make_recommendations
}

###############################################################################
# Auto Mode - No Prompts
###############################################################################

auto_mode() {
    detect_and_recommend
    
    echo ""
    info "To proceed with this setup:"
    echo ""
    echo "1. When installing Pop!_OS:"
    echo "   - Select '$REC_OS_DRIVE' for OS installation"
    echo "   - Use custom partitioning"
    echo ""
    echo "2. After installation, run:"
    echo "   mkdir -p /mnt/games /mnt/storage"
    echo "   # Add to /etc/fstab"
    echo ""
    echo "3. To regenerate recommendations anytime:"
    echo "   ./scripts/drive-recommend.sh --auto"
}

###############################################################################
# Usage
###############################################################################

usage() {
    cat << EOF
Drive Detection & Recommendation Tool

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    --detect    Analyze drives and make recommendations
    --auto      Auto mode (no interactive prompts)
    --list      List drives only
    --plan      Show partition planning
    --check     Check current setup
    -h, --help  Show this help

EXAMPLES:
    $(basename "$0") --detect    # Full analysis with recommendations
    $(basename "$0") --auto     # Auto mode
    $(basename "$0") --check    # Check current partitions

EOF
}

###############################################################################
# Main
###############################################################################

main() {
    local action="${1:-"--detect"}"
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Drive Detection & Recommendations           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    case "$action" in
        --detect|-d)
            detect_and_recommend
            plan_partitions
            ;;
        --auto|-a)
            auto_mode
            ;;
        --list|-l)
            analyze_drives
            ;;
        --plan|-p)
            detect_and_recommend
            plan_partitions
            ;;
        --check|-c)
            check_current_setup
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $action"
            usage
            exit 1
            ;;
    esac
}

main "$@"
