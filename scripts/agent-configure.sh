#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/config"
LOG_DIR="$REPO_DIR/logs/hardware"
CONFIG_FILE="$CONFIG_DIR/deployment.local.env"
DEFAULTS_FILE="$CONFIG_DIR/defaults.env"
FSTAB_PLAN_FILE="$LOG_DIR/fstab-plan-$(date +%Y%m%d-%H%M%S).txt"
MODE="guided"
PRESET=""
GENERATE_FSTAB=0

if [[ -f "$DEFAULTS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$DEFAULTS_FILE"
fi

MOUNT_GAMES="${MOUNT_GAMES:-/mnt/games}"
MOUNT_STORAGE="${MOUNT_STORAGE:-/mnt/storage}"
MOUNT_BACKUPS="${MOUNT_BACKUPS:-/mnt/backups}"
DEPLOY_PROFILE="${DEPLOY_PROFILE:-full}"
INSTALL_MODE="${INSTALL_MODE:-fresh}"
USE_FUSION360="${USE_FUSION360:-no}"
ENABLE_CLOUD_SETUP="${ENABLE_CLOUD_SETUP:-no}"

mkdir -p "$CONFIG_DIR" "$LOG_DIR"

usage() {
    cat <<'EOF'
Usage: ./scripts/agent-configure.sh [OPTIONS]

OPTIONS:
  --guided         Run interactive configuration wizard (default)
  --non-interactive  Write config from defaults/env without prompts
  --preset NAME    Apply preset (single-disk|dual-disk|dual-boot)
  --generate-fstab Generate fstab proposal after writing config
  --show           Show saved deployment answers
  -h, --help       Show this help
EOF
}

apply_preset() {
    local preset="$1"

    case "$preset" in
        single-disk)
            DEPLOY_PROFILE="full"
            INSTALL_MODE="fresh"
            MOUNT_GAMES="/mnt/games"
            MOUNT_STORAGE="/mnt/storage"
            MOUNT_BACKUPS="/mnt/backups"
            ;;
        dual-disk)
            DEPLOY_PROFILE="gaming"
            INSTALL_MODE="fresh"
            MOUNT_GAMES="/mnt/games"
            MOUNT_STORAGE="/mnt/storage"
            MOUNT_BACKUPS="/mnt/backups"
            ;;
        dual-boot)
            DEPLOY_PROFILE="gaming"
            INSTALL_MODE="dualboot"
            MOUNT_GAMES="/mnt/games"
            MOUNT_STORAGE="/mnt/storage"
            MOUNT_BACKUPS="/mnt/backups"
            ;;
        "")
            ;;
        *)
            echo "Unknown preset: $preset" >&2
            echo "Allowed presets: single-disk, dual-disk, dual-boot" >&2
            exit 1
            ;;
    esac
}

write_config_value() {
    local key="$1"
    local value="$2"
    printf '%s=%q\n' "$key" "$value" >> "$CONFIG_FILE"
}

read_saved_value() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        awk -F= -v k="$key" '$1==k {print $2}' "$CONFIG_FILE" | tail -1 | tr -d "'\""
    fi
}

prompt_default() {
    local key="$1"
    local question="$2"
    local default_value="$3"
    local response

    read -r -p "$question [$default_value]: " response
    if [[ -z "$response" ]]; then
        response="$default_value"
    fi
    printf '%s=%q\n' "$key" "$response" >> "$CONFIG_FILE"
}

show_disk_inventory() {
    echo ""
    echo "Detected disks:"
    lsblk -dn -o NAME,SIZE,TYPE,MODEL | awk '$3 == "disk" {printf "  /dev/%-10s %-8s %-6s %s\n", $1, $2, $3, substr($0, index($0,$4))}'
    echo ""
    echo "Mounted filesystems:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,MODEL
}

build_fstab_plan() {
    local games_partition="$1"
    local storage_partition="$2"
    local backup_partition="$3"

    {
        echo "# Proposed fstab entries"
        echo "# Generated: $(date -Iseconds)"
        echo "# Review before applying"
        echo ""
    } > "$FSTAB_PLAN_FILE"

    if [[ -n "$games_partition" ]]; then
        local games_uuid
        games_uuid="$(sudo blkid -s UUID -o value "$games_partition" 2>/dev/null || true)"
        if [[ -n "$games_uuid" ]]; then
            echo "UUID=$games_uuid $MOUNT_GAMES ext4 defaults,nofail 0 2" >> "$FSTAB_PLAN_FILE"
        fi
    fi

    if [[ -n "$storage_partition" ]]; then
        local storage_uuid
        storage_uuid="$(sudo blkid -s UUID -o value "$storage_partition" 2>/dev/null || true)"
        if [[ -n "$storage_uuid" ]]; then
            echo "UUID=$storage_uuid $MOUNT_STORAGE ext4 defaults,nofail 0 2" >> "$FSTAB_PLAN_FILE"
        fi
    fi

    if [[ -n "$backup_partition" ]]; then
        local backup_uuid
        backup_uuid="$(sudo blkid -s UUID -o value "$backup_partition" 2>/dev/null || true)"
        if [[ -n "$backup_uuid" ]]; then
            echo "UUID=$backup_uuid $MOUNT_BACKUPS ext4 defaults,nofail 0 2" >> "$FSTAB_PLAN_FILE"
        fi
    fi

    echo ""
    echo "Saved fstab proposal: $FSTAB_PLAN_FILE"
}

run_guided() {
    echo "=============================================="
    echo " Linux Workstation Guided Configuration"
    echo "=============================================="

    local saved_os_drive saved_games_drive saved_storage_drive saved_backup_drive
    saved_os_drive="$(read_saved_value "OS_DRIVE")"
    saved_games_drive="$(read_saved_value "GAMES_DRIVE")"
    saved_storage_drive="$(read_saved_value "STORAGE_DRIVE")"
    saved_backup_drive="$(read_saved_value "BACKUP_DRIVE")"

    apply_preset "$PRESET"

    : > "$CONFIG_FILE"

    if [[ -x "$REPO_DIR/scripts/hardware-report.sh" ]]; then
        "$REPO_DIR/scripts/hardware-report.sh"
    fi

    show_disk_inventory

    echo "Answer these prompts to create a local deployment profile."
    echo "This file is intended for AI-assisted setup decisions."
    echo ""

    prompt_default "DEPLOY_PROFILE" "Setup profile (full|gaming|dev|minimal)" "$DEPLOY_PROFILE"
    prompt_default "INSTALL_MODE" "Install mode (fresh|dualboot|existing-pop)" "$INSTALL_MODE"
    prompt_default "OS_DRIVE" "OS drive device (example: /dev/nvme0n1, or leave as-is)" "${OS_DRIVE:-$saved_os_drive}"
    prompt_default "GAMES_DRIVE" "Games drive partition (example: /dev/nvme1n1p1)" "${GAMES_DRIVE:-$saved_games_drive}"
    prompt_default "STORAGE_DRIVE" "Storage drive partition (example: /dev/sda1)" "${STORAGE_DRIVE:-$saved_storage_drive}"
    prompt_default "BACKUP_DRIVE" "Backup drive partition (example: /dev/sdb1)" "${BACKUP_DRIVE:-$saved_backup_drive}"
    prompt_default "MOUNT_GAMES" "Games mount point" "$MOUNT_GAMES"
    prompt_default "MOUNT_STORAGE" "Storage mount point" "$MOUNT_STORAGE"
    prompt_default "MOUNT_BACKUPS" "Backup mount point" "$MOUNT_BACKUPS"
    prompt_default "USE_FUSION360" "Install Fusion 360 via Wine? (yes|no)" "$USE_FUSION360"
    prompt_default "ENABLE_CLOUD_SETUP" "Configure cloud sync now? (yes|no)" "$ENABLE_CLOUD_SETUP"

    if [[ $GENERATE_FSTAB -eq 1 ]]; then
        local games_partition storage_partition backup_partition
        games_partition="$(awk -F= '/^GAMES_DRIVE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
        storage_partition="$(awk -F= '/^STORAGE_DRIVE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
        backup_partition="$(awk -F= '/^BACKUP_DRIVE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
        build_fstab_plan "$games_partition" "$storage_partition" "$backup_partition"
    else
        echo ""
        read -r -p "Generate fstab proposal from current UUIDs? [y/N]: " generate_fstab
        if [[ "$generate_fstab" =~ ^[Yy]$ ]]; then
            local games_partition storage_partition backup_partition
            games_partition="$(awk -F= '/^GAMES_DRIVE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
            storage_partition="$(awk -F= '/^STORAGE_DRIVE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
            backup_partition="$(awk -F= '/^BACKUP_DRIVE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
            build_fstab_plan "$games_partition" "$storage_partition" "$backup_partition"
        fi
    fi

    echo ""
    echo "Saved deployment answers: $CONFIG_FILE"
    echo ""
    echo "Recommended next commands:"
    echo "  ./scripts/full-setup.sh --check"
    echo "  ./scripts/full-setup.sh --profile $(awk -F= '/^DEPLOY_PROFILE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
    echo "  ./scripts/post-install-check.sh"
}

run_non_interactive() {
    local existing_profile existing_install existing_os existing_games existing_storage existing_backup
    local existing_mount_games existing_mount_storage existing_mount_backups
    local existing_fusion existing_cloud

    existing_profile="$(read_saved_value "DEPLOY_PROFILE")"
    existing_install="$(read_saved_value "INSTALL_MODE")"
    existing_os="$(read_saved_value "OS_DRIVE")"
    existing_games="$(read_saved_value "GAMES_DRIVE")"
    existing_storage="$(read_saved_value "STORAGE_DRIVE")"
    existing_backup="$(read_saved_value "BACKUP_DRIVE")"
    existing_mount_games="$(read_saved_value "MOUNT_GAMES")"
    existing_mount_storage="$(read_saved_value "MOUNT_STORAGE")"
    existing_mount_backups="$(read_saved_value "MOUNT_BACKUPS")"
    existing_fusion="$(read_saved_value "USE_FUSION360")"
    existing_cloud="$(read_saved_value "ENABLE_CLOUD_SETUP")"

    apply_preset "$PRESET"

    DEPLOY_PROFILE="${DEPLOY_PROFILE:-$existing_profile}"
    INSTALL_MODE="${INSTALL_MODE:-$existing_install}"
    OS_DRIVE="${OS_DRIVE:-$existing_os}"
    GAMES_DRIVE="${GAMES_DRIVE:-$existing_games}"
    STORAGE_DRIVE="${STORAGE_DRIVE:-$existing_storage}"
    BACKUP_DRIVE="${BACKUP_DRIVE:-$existing_backup}"
    MOUNT_GAMES="${MOUNT_GAMES:-$existing_mount_games}"
    MOUNT_STORAGE="${MOUNT_STORAGE:-$existing_mount_storage}"
    MOUNT_BACKUPS="${MOUNT_BACKUPS:-$existing_mount_backups}"
    USE_FUSION360="${USE_FUSION360:-$existing_fusion}"
    ENABLE_CLOUD_SETUP="${ENABLE_CLOUD_SETUP:-$existing_cloud}"

    DEPLOY_PROFILE="${DEPLOY_PROFILE:-full}"
    INSTALL_MODE="${INSTALL_MODE:-fresh}"
    MOUNT_GAMES="${MOUNT_GAMES:-/mnt/games}"
    MOUNT_STORAGE="${MOUNT_STORAGE:-/mnt/storage}"
    MOUNT_BACKUPS="${MOUNT_BACKUPS:-/mnt/backups}"
    USE_FUSION360="${USE_FUSION360:-no}"
    ENABLE_CLOUD_SETUP="${ENABLE_CLOUD_SETUP:-no}"

    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    : > "$CONFIG_FILE"

    write_config_value "DEPLOY_PROFILE" "$DEPLOY_PROFILE"
    write_config_value "INSTALL_MODE" "$INSTALL_MODE"
    write_config_value "OS_DRIVE" "${OS_DRIVE:-}"
    write_config_value "GAMES_DRIVE" "${GAMES_DRIVE:-}"
    write_config_value "STORAGE_DRIVE" "${STORAGE_DRIVE:-}"
    write_config_value "BACKUP_DRIVE" "${BACKUP_DRIVE:-}"
    write_config_value "MOUNT_GAMES" "$MOUNT_GAMES"
    write_config_value "MOUNT_STORAGE" "$MOUNT_STORAGE"
    write_config_value "MOUNT_BACKUPS" "$MOUNT_BACKUPS"
    write_config_value "USE_FUSION360" "$USE_FUSION360"
    write_config_value "ENABLE_CLOUD_SETUP" "$ENABLE_CLOUD_SETUP"

    if [[ $GENERATE_FSTAB -eq 1 ]]; then
        local games_partition storage_partition backup_partition
        games_partition="${GAMES_DRIVE:-}"
        storage_partition="${STORAGE_DRIVE:-}"
        backup_partition="${BACKUP_DRIVE:-}"
        build_fstab_plan "$games_partition" "$storage_partition" "$backup_partition"
    fi

    echo ""
    echo "Wrote deployment answers (non-interactive): $CONFIG_FILE"
    if [[ -n "$PRESET" ]]; then
        echo "Applied preset: $PRESET"
    fi
    echo "Profile: $DEPLOY_PROFILE"
    echo "Install mode: $INSTALL_MODE"
    echo "Mounts: $MOUNT_GAMES, $MOUNT_STORAGE, $MOUNT_BACKUPS"
    echo ""
    echo "Saved deployment answers: $CONFIG_FILE"
    echo ""
    echo "Recommended next commands:"
    echo "  ./scripts/full-setup.sh --check"
    echo "  ./scripts/full-setup.sh --profile $(awk -F= '/^DEPLOY_PROFILE=/{print $2}' "$CONFIG_FILE" | tr -d "'\"")"
    echo "  ./scripts/post-install-check.sh"
}

show_saved() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Saved deployment answers:"
        cat "$CONFIG_FILE"
    else
        echo "No saved deployment answers found at: $CONFIG_FILE"
        exit 1
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --guided)
                MODE="guided"
                ;;
            --non-interactive)
                MODE="non-interactive"
                ;;
            --preset)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "--preset requires a value" >&2
                    exit 1
                fi
                PRESET="$2"
                shift
                ;;
            --generate-fstab)
                GENERATE_FSTAB=1
                ;;
            --show)
                MODE="show"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
        shift
    done

    case "$MODE" in
        guided)
            run_guided
            ;;
        non-interactive)
            run_non_interactive
            ;;
        show)
            show_saved
            ;;
        *)
            echo "Unknown mode: $MODE" >&2
            exit 1
            ;;
    esac
}

main "$@"
