#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# linux-workstation automated setup
# 
# Run this after cloning the repo to provision your entire Pop!_OS system.
# This script is designed to be run by an AI agent or manually.
#
# Usage:
#   ./scripts/full-setup.sh              # Full setup (all steps)
#   ./scripts/full-setup.sh --check       # Check system readiness
#   ./scripts/full-setup.sh --hardware   # Generate hardware report
#   ./scripts/full-setup.sh --bootstrap  # Run Ansible bootstrap only
#   ./scripts/full-setup.sh --profile    # Run profile-based setup
#   ./scripts/full-setup.sh --all --dry-run  # Preview only
#   ./scripts/full-setup.sh --verify     # Verify installation
#
# Profiles:
#   ./scripts/full-setup.sh --profile full       # Complete setup
#   ./scripts/full-setup.sh --profile gaming     # Gaming stack
#   ./scripts/full-setup.sh --profile dev        # Development tools
#   ./scripts/full-setup.sh --profile minimal    # Core utilities only
#
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$REPO_DIR/logs/setup-$(date +%Y%m%d-%H%M%S).log"
DRY_RUN=0

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
USE_FUSION360="${USE_FUSION360:-no}"
FUSION360_PROVIDER="${FUSION360_PROVIDER:-codeberg-script}"
FUSION360_FALLBACK_PROVIDER="${FUSION360_FALLBACK_PROVIDER:-bottles}"
FUSION360_CHANNEL="${FUSION360_CHANNEL:-stable}"
FUSION360_ENABLE_PROTON="${FUSION360_ENABLE_PROTON:-no}"
FUSION360_PROTON_VERSION="${FUSION360_PROTON_VERSION:-GE-Proton10-32}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[+]${NC} $1"
    echo "[+] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    echo "[!] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[ERROR] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[i]${NC} $1"
    echo "[i] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"
}

header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "" >> "$LOG_FILE"
    log "$1"
}

footer() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "" >> "$LOG_FILE"
    log "$1"
}

generate_hardware_report() {
    header "Step 0.5: Hardware Report"

    local report_script="$REPO_DIR/scripts/hardware-report.sh"
    if [[ -x "$report_script" ]]; then
        "$report_script"
        log "Hardware report generated for agent decision-making"
    else
        warn "Hardware report script not found or not executable: $report_script"
    fi

    footer "Hardware report complete"
}

log_section() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo "[✓] $1" >> "$LOG_FILE"
}

# Create logs directory
mkdir -p "$REPO_DIR/logs"

###############################################################################
# STEP 0: System Check
###############################################################################

check_system() {
    header "Step 0: System Readiness Check"
    
    local errors=0
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "pop" ]] || [[ "$ID" == "ubuntu" ]]; then
            log "OS: $PRETTY_NAME"
        else
            warn "This script is designed for Pop!_OS/Ubuntu. Detected: $PRETTY_NAME"
        fi
    else
        error "Cannot detect OS"
        ((errors++))
    fi
    
    # Check user
    if [[ $EUID -eq 0 ]]; then
        error "Do not run as root. Run as regular user with sudo."
        ((errors++))
    fi
    
    # Check sudo
    if ! sudo -v 2>/dev/null; then
        error "Cannot sudo. Fix permissions first."
        ((errors++))
    fi
    
    # Check git
    if ! command -v git &>/dev/null; then
        warn "Git not installed. Installing..."
        sudo apt update && sudo apt install -y git
    fi
    
    # Check disk space (need ~20GB free)
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $free_space -lt 20 ]]; then
        warn "Low disk space: ${free_space}GB free. Recommend 20GB+."
    else
        log "Disk space: ${free_space}GB free"
    fi
    
    # GPU check
    if command -v lspci &>/dev/null; then
        local gpu=$(lspci | grep -iE "vga|3d|display" | head -1)
        log "GPU: $gpu"
    fi
    
    # Internet check
    if curl -s --max-time 5 https://github.com > /dev/null; then
        log "Internet: Connected"
    else
        warn "Internet: Check connection"
    fi
    
    if [[ $errors -gt 0 ]]; then
        error "$errors errors found. Fix before continuing."
        exit 1
    fi
    
    footer "System check passed"
}

###############################################################################
# STEP 1: Bootstrap (Ansible + Roles)
###############################################################################

profile_to_ansible_tags() {
    local profile="${1:-full}"

    case "$profile" in
        full)
            echo "base,gaming,cad,printing,dev,security,storage,cloud,desktop,fusion360"
            ;;
        gaming)
            echo "base,gaming,printing,security,storage"
            ;;
        dev)
            echo "base,dev,security,storage,cloud"
            ;;
        minimal)
            echo "base,storage"
            ;;
        *)
            error "Unknown profile: $profile"
            echo "Available profiles: full, gaming, dev, minimal"
            exit 1
            ;;
    esac
}

run_bootstrap() {
    local profile="${1:-full}"
    local ansible_tags
    ansible_tags="$(profile_to_ansible_tags "$profile")"
    local fusion360_bool="false"
    local fusion360_proton_bool="false"
    case "${USE_FUSION360,,}" in
        1|true|yes|on)
            fusion360_bool="true"
            ;;
    esac
    case "${FUSION360_ENABLE_PROTON,,}" in
        1|true|yes|on)
            fusion360_proton_bool="true"
            ;;
    esac
    local extra_vars
    extra_vars="mount_games=$MOUNT_GAMES mount_storage=$MOUNT_STORAGE mount_backups=$MOUNT_BACKUPS use_fusion360=$fusion360_bool fusion360_provider=$FUSION360_PROVIDER fusion360_fallback_provider=$FUSION360_FALLBACK_PROVIDER fusion360_channel=$FUSION360_CHANNEL fusion360_enable_proton=$fusion360_proton_bool fusion360_proton_version=$FUSION360_PROTON_VERSION"

    header "Step 1: Ansible Bootstrap"
    
    cd "$REPO_DIR"
    
    # Check if repo is properly cloned
    if [[ ! -f "bootstrap/bootstrap.sh" ]]; then
        error "Run this command from the repository root."
        exit 1
    fi
    
    # Install Ansible if needed
    if ! command -v ansible &>/dev/null; then
        log "Installing Ansible..."
        sudo apt update
        sudo apt install -y ansible git
    else
        log "Ansible already installed: $(ansible --version | head -1)"
    fi
    
    # Run bootstrap
    if [[ -n "$ansible_tags" ]]; then
        log "Running Ansible playbook for profile '$profile' with tags: $ansible_tags"
        if ! sudo ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags "$ansible_tags" --extra-vars "$extra_vars" --ask-become-pass; then
            error "Bootstrap failed"
            return 1
        fi
    else
        log "Running full Ansible playbook for profile '$profile'"
        if ! sudo ansible-playbook -i ansible/inventory.yml ansible/site.yml --extra-vars "$extra_vars" --ask-become-pass; then
            error "Bootstrap failed"
            return 1
        fi
    fi

    footer "Bootstrap complete"
}

run_verify_ansible() {
    local extra_vars
    local fusion360_bool="false"
    case "${USE_FUSION360,,}" in
        1|true|yes|on)
            fusion360_bool="true"
            ;;
    esac
    extra_vars="mount_games=$MOUNT_GAMES mount_storage=$MOUNT_STORAGE mount_backups=$MOUNT_BACKUPS use_fusion360=$fusion360_bool fusion360_provider=$FUSION360_PROVIDER"

    header "Verification"
    log "Running Ansible verification role"

    if ! sudo ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags "verify" --extra-vars "$extra_vars" --ask-become-pass; then
        error "Verification failed"
        return 1
    fi

    footer "Verification complete"
}

###############################################################################
# PROFILE SUPPORT
###############################################################################

describe_profile_steps() {
    local profile="$1"
    local tags
    tags="$(profile_to_ansible_tags "$profile")"

    if [[ -n "$tags" ]]; then
        echo "  - ansible-playbook --tags $tags"
    else
        echo "  - ansible-playbook (all roles)"
    fi
}

dry_run_plan() {
    local action="$1"
    local profile="$2"

    header "Dry Run Plan"
    info "No changes will be made. Commands are not executed."
    echo ""
    echo "Action: $action"
    [[ "$action" == "--profile" ]] && echo "Profile: $profile"
    echo ""

    case "$action" in
        --all)
            echo "Would run steps in order:"
            echo "  1. check_system"
            echo "  2. generate_hardware_report"
            echo "  3. run_bootstrap full"
            echo "  4. run_verify_ansible"
            ;;
        --profile)
            echo "Would run steps in order:"
            echo "  1. check_system"
            echo "  2. generate_hardware_report"
            echo "  3. run_bootstrap $profile"
            echo "  4. run_verify_ansible"
            echo ""
            echo "Profile Ansible actions:"
            describe_profile_steps "$profile"
            ;;
        --check)
            echo "Would run: check_system"
            ;;
        --hardware)
            echo "Would run: scripts/hardware-report.sh"
            ;;
        --bootstrap)
            echo "Would run: ansible-playbook -i ansible/inventory.yml ansible/site.yml"
            ;;
        --verify)
            echo "Would run: ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags verify"
            ;;
        --cloud)
            echo "Would run: ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags cloud"
            ;;
        --desktop)
            echo "Would run: ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags desktop"
            ;;
        *)
            error "Unknown option for dry run: $action"
            return 1
            ;;
    esac

    echo ""
    info "Use the same command without --dry-run to execute."
}

###############################################################################
# USAGE
###############################################################################

usage() {
    cat << EOF
linux-workstation automated setup

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    --all           Run full setup (equivalent to --profile full)
    --check         System readiness check
    --hardware      Generate hardware report only
    --bootstrap     Run Ansible bootstrap only
    --profile NAME  Run named profile (full, gaming, dev, minimal)
    --verify        Verify installation
    --dry-run       Show plan without making changes
    -h, --help      Show this help

PROFILES:
    full            Complete workstation setup (all software)
    gaming          Gaming stack (Steam, Heroic, slicers)
    dev             Development tools (Docker, ZSH, Python)
    minimal         Core utilities only

EXAMPLES:
    # Full automated setup (recommended)
    ./full-setup.sh --profile full
    
    # Gaming workstation
    ./full-setup.sh --profile gaming
    
    # Dev workstation
    ./full-setup.sh --profile dev

    # Preview full run without changes
    ./full-setup.sh --all --dry-run
    
    # Check system before anything
    ./full-setup.sh --check

    # Generate hardware report for AI planning
    ./full-setup.sh --hardware

For AI Agents:
    Say "run the full setup" and execute:
    ./scripts/full-setup.sh --profile full

EOF
}

###############################################################################
# MAIN
###############################################################################

main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   linux-workstation Automated Setup      ║${NC}"
    echo -e "${BLUE}║   For Pop!_OS with COSMIC              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    log "Setup started at $(date)"
    log "Log file: $LOG_FILE"
    
    local action="--help"
    local profile_name="full"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|--check|--hardware|--bootstrap|--verify|--cloud|--desktop)
                action="$1"
                ;;
            --profile)
                action="--profile"
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    error "--profile requires a value: full|gaming|dev|minimal"
                    exit 1
                fi
                profile_name="$2"
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            -h|--help)
                action="--help"
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        dry_run_plan "$action" "$profile_name"
        return 0
    fi
    
    case "$action" in
        --all)
            check_system
            generate_hardware_report
            run_bootstrap "full"
            run_verify_ansible
            ;;
        --profile)
            check_system
            generate_hardware_report
            run_bootstrap "$profile_name"
            run_verify_ansible
            ;;
        --check)
            check_system
            ;;
        --hardware)
            generate_hardware_report
            ;;
        --bootstrap)
            run_bootstrap
            ;;
        --verify)
            run_verify_ansible
            ;;
        --cloud)
            sudo ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags cloud --extra-vars "mount_games=$MOUNT_GAMES mount_storage=$MOUNT_STORAGE mount_backups=$MOUNT_BACKUPS" --ask-become-pass
            ;;
        --desktop)
            sudo ansible-playbook -i ansible/inventory.yml ansible/site.yml --tags desktop --extra-vars "mount_games=$MOUNT_GAMES mount_storage=$MOUNT_STORAGE mount_backups=$MOUNT_BACKUPS" --ask-become-pass
            ;;
        -h|--help|"")
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
