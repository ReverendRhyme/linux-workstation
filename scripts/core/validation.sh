#!/usr/bin/env bash
# Validation library
# Provides verification functions for post-install checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
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

# Track results
CHECKS_PASSED=0
CHECKS_FAILED=0

check() {
    local name="$1"
    local cmd="$2"
    
    if eval "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $name"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_output() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    
    local result
    result=$(eval "$cmd" 2>/dev/null)
    
    if echo "$result" | grep -q "$expected"; then
        echo -e "  ${GREEN}✓${NC} $name"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        echo -e "    Expected: $expected"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_file() {
    local name="$1"
    local file="$2"
    
    if [[ -f "$file" ]] || [[ -x "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $name"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_dir() {
    local name="$1"
    local dir="$2"
    
    if [[ -d "$dir" ]]; then
        echo -e "  ${GREEN}✓${NC} $name"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        ((CHECKS_FAILED++))
        return 1
    fi
}

validate_system() {
    log_section "System Validation"
    
    echo ""
    echo "Core System:"
    check "apt" "command -v apt"
    check "git" "command -v git"
    check "curl" "command -v curl"
    
    echo ""
    echo "GPU & Graphics:"
    check_output "AMD GPU" "glxinfo 2>/dev/null | grep 'OpenGL renderer'" "AMD\|Radeon"
    check "Vulkan" "vulkan-smoke 2>/dev/null || command -v vulkaninfo"
    
    echo ""
    echo "Shell:"
    check "ZSH" "command -v zsh"
    check "Oh My Zsh" "[[ -d \"\$HOME/.oh-my-zsh\" ]]"
}

validate_gaming() {
    log_section "Gaming Stack"
    
    echo ""
    check "Steam" "command -v steam"
    check "Gamemode" "command -v gamemoderun"
    check "MangoHud" "command -v mangohud"
    check "Heroic (flatpak)" "flatpak list 2>/dev/null | grep -q heroic"
}

validate_cad() {
    log_section "CAD/3D Design"
    
    echo ""
    check "Blender" "command -v blender"
    check "FreeCAD" "command -v freecad"
    check "OpenSCAD" "command -v openscad"
}

validate_printing() {
    log_section "3D Printing"
    
    echo ""
    check_file "OrcaSlicer" "/opt/OrcaSlicer.AppImage"
    check "PrusaSlicer" "command -v prusaslicer"
    check "Cura" "command -v cura"
}

validate_dev() {
    log_section "Development"
    
    echo ""
    check "Docker" "command -v docker"
    check "Python" "command -v python3"
    check "Git" "command -v git"
}

validate_productivity() {
    log_section "Productivity"
    
    echo ""
    check "LibreOffice" "command -v libreoffice"
    check "rclone" "command -v rclone"
}

validate_storage() {
    log_section "Storage"
    
    echo ""
    check_dir "$MOUNT_GAMES" "$MOUNT_GAMES"
    check "fstab configured" "grep -q '$MOUNT_GAMES' /etc/fstab 2>/dev/null"
}

validate_results() {
    echo ""
    echo "=========================================="
    echo "Results: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
    echo "=========================================="
    
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}
