#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_DIR/config/deployment.local.env"
DEFAULTS_FILE="$REPO_DIR/config/defaults.env"

DRY_RUN=0
SKIP_GUIDED=0
RUN_VERIFY=1
PROFILE_OVERRIDE=""
NON_INTERACTIVE=0
PRESET=""
GENERATE_FSTAB=0

usage() {
    cat <<'EOF'
Usage: ./scripts/popos-auto.sh [OPTIONS]

End-to-end Pop!_OS workstation setup wrapper.

OPTIONS:
  --profile NAME   Force profile (full|gaming|dev|minimal)
  --skip-guided    Skip guided questions and use saved/default profile
  --non-interactive  Generate config with no prompts
  --preset NAME    Preset for non-interactive config (single-disk|dual-disk|dual-boot)
  --generate-fstab Generate fstab proposal when writing config
  --no-verify      Skip Ansible verification role at the end
  --dry-run        Show plan and run setup preview only
  -h, --help       Show this help

Examples:
  ./scripts/popos-auto.sh
  ./scripts/popos-auto.sh --profile gaming
  ./scripts/popos-auto.sh --skip-guided --profile dev
  ./scripts/popos-auto.sh --non-interactive --preset dual-disk
  ./scripts/popos-auto.sh --dry-run
EOF
}

resolve_profile() {
    local profile="${PROFILE_OVERRIDE:-}"

    if [[ -z "$profile" && $NON_INTERACTIVE -eq 1 ]]; then
        case "$PRESET" in
            dual-disk|dual-boot)
                profile="gaming"
                ;;
            single-disk)
                profile="full"
                ;;
        esac
    fi

    if [[ -z "$profile" && -f "$DEFAULTS_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$DEFAULTS_FILE"
        profile="${DEPLOY_PROFILE:-}"
    fi

    if [[ -z "$profile" && -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        profile="${DEPLOY_PROFILE:-}"
    fi

    if [[ -z "$profile" ]]; then
        profile="full"
    fi

    case "$profile" in
        full|gaming|dev|minimal)
            printf '%s\n' "$profile"
            ;;
        *)
            echo "[ERROR] Invalid profile: $profile" >&2
            echo "Allowed: full, gaming, dev, minimal" >&2
            exit 1
            ;;
    esac
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --profile requires a value" >&2
                    exit 1
                fi
                PROFILE_OVERRIDE="$2"
                shift
                ;;
            --skip-guided)
                SKIP_GUIDED=1
                ;;
            --non-interactive)
                NON_INTERACTIVE=1
                ;;
            --preset)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --preset requires a value" >&2
                    exit 1
                fi
                PRESET="$2"
                shift
                ;;
            --generate-fstab)
                GENERATE_FSTAB=1
                ;;
            --no-verify)
                RUN_VERIFY=0
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "[ERROR] Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
        shift
    done

    echo ""
    echo "=============================================="
    echo "  Pop!_OS Automated Setup Wrapper"
    echo "=============================================="

    if [[ $DRY_RUN -eq 1 ]]; then
        local preview_profile
        preview_profile="$(resolve_profile)"

        echo ""
        echo "Dry-run mode enabled"
        if [[ $SKIP_GUIDED -eq 1 ]]; then
            echo "Would run configuration step: no"
        elif [[ $NON_INTERACTIVE -eq 1 ]]; then
            echo "Would run configuration step: non-interactive"
        else
            echo "Would run configuration step: guided"
        fi
        echo "Resolved profile: $preview_profile"
        echo "Would run post-install verification: $([[ $RUN_VERIFY -eq 1 ]] && echo yes || echo no)"
        echo ""

        if [[ $SKIP_GUIDED -eq 0 && $NON_INTERACTIVE -eq 0 ]]; then
            echo "Would run: ./scripts/agent-configure.sh --guided"
        fi
        if [[ $SKIP_GUIDED -eq 0 && $NON_INTERACTIVE -eq 1 ]]; then
            local cfg_cmd
            cfg_cmd="./scripts/agent-configure.sh --non-interactive"
            if [[ -n "$PRESET" ]]; then
                cfg_cmd+=" --preset $PRESET"
            fi
            if [[ $GENERATE_FSTAB -eq 1 ]]; then
                cfg_cmd+=" --generate-fstab"
            fi
            echo "Would run: $cfg_cmd"
        fi
        echo "Would run: ./scripts/full-setup.sh --profile $preview_profile --dry-run"
        if [[ $RUN_VERIFY -eq 1 ]]; then
            echo "Would run: ./scripts/full-setup.sh --verify"
        fi
        echo ""

        "$REPO_DIR/scripts/full-setup.sh" --profile "$preview_profile" --dry-run
        exit 0
    fi

    if [[ $SKIP_GUIDED -eq 0 && $NON_INTERACTIVE -eq 0 ]]; then
        "$REPO_DIR/scripts/agent-configure.sh" --guided
    fi

    if [[ $SKIP_GUIDED -eq 0 && $NON_INTERACTIVE -eq 1 ]]; then
        if [[ -n "$PRESET" && $GENERATE_FSTAB -eq 1 ]]; then
            "$REPO_DIR/scripts/agent-configure.sh" --non-interactive --preset "$PRESET" --generate-fstab
        elif [[ -n "$PRESET" ]]; then
            "$REPO_DIR/scripts/agent-configure.sh" --non-interactive --preset "$PRESET"
        elif [[ $GENERATE_FSTAB -eq 1 ]]; then
            "$REPO_DIR/scripts/agent-configure.sh" --non-interactive --generate-fstab
        else
            "$REPO_DIR/scripts/agent-configure.sh" --non-interactive
        fi
    fi

    local profile
    profile="$(resolve_profile)"

    echo ""
    echo "[+] Provisioning profile: $profile"
    "$REPO_DIR/scripts/full-setup.sh" --profile "$profile"

    if [[ $RUN_VERIFY -eq 1 ]]; then
        echo ""
        echo "[+] Running Ansible verification"
        "$REPO_DIR/scripts/full-setup.sh" --verify
    fi

    echo ""
    echo "[+] Pop!_OS setup wrapper complete"
}

main "$@"
