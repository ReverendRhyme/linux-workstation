#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DEFAULTS_FILE="$REPO_DIR/config/defaults.env"
LOCAL_CONFIG_FILE="$REPO_DIR/config/deployment.local.env"
VALIDATOR="$REPO_DIR/scripts/linux/validate-migration-context.py"

CONTEXT_DIR=""
WRITE_LOCAL_ENV=0
PRINT_RESTORE_PLAN=0

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/import-migration-context.sh --context-dir <path> [OPTIONS]

Import Windows migration context for Pop!_OS setup.

OPTIONS:
  --context-dir PATH   Path to migration context directory
  --write-local-env    Write config/deployment.local.env using imported seed values
  --print-restore-plan Print restore guidance from software-map/paths context
  -h, --help           Show this help
EOF
}

require_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] Required file missing: $file" >&2
        exit 1
    fi
}

load_env_file() {
    local file="$1"
    while IFS='=' read -r key value; do
        [[ -z "${key:-}" ]] && continue
        [[ "$key" == \#* ]] && continue
        value="${value%$'\r'}"
        value="${value%\"}"
        value="${value#\"}"
        export "$key=$value"
    done < "$file"
}

print_restore_plan() {
    local software_map="$1"
    local paths_json="$2"

    python3 - "$software_map" "$paths_json" <<'PY'
import json
import sys

software_path, paths_path = sys.argv[1:3]

with open(software_path, "r", encoding="utf-8") as f:
    software = json.load(f)
with open(paths_path, "r", encoding="utf-8") as f:
    paths = json.load(f)

apps = software.get("apps", [])
native = [a["name"] for a in apps if a.get("linux_target") in {"native", "flatpak"}]
manual = [a["name"] for a in apps if a.get("linux_target") in {"manual", "wine", "web"}]

print("\nRestore Plan")
print("------------")
if native:
    print("- Likely covered by automation:")
    for name in native[:15]:
        print(f"  - {name}")
if manual:
    print("- Manual follow-up candidates:")
    for name in manual[:15]:
        print(f"  - {name}")

print("- Browser profile sources:")
for profile in paths.get("browser_profiles", []):
    print(f"  - {profile.get('name')}: {profile.get('path')}")

print("- Steam library sources:")
for entry in paths.get("steam_libraries", []):
    print(f"  - {entry}")

print("- Dev config sources:")
for entry in paths.get("dev_paths", []):
    print(f"  - {entry}")
PY
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --context-dir)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --context-dir requires a value" >&2
                    exit 1
                fi
                CONTEXT_DIR="$2"
                shift
                ;;
            --write-local-env)
                WRITE_LOCAL_ENV=1
                ;;
            --print-restore-plan)
                PRINT_RESTORE_PLAN=1
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

    if [[ -z "$CONTEXT_DIR" ]]; then
        echo "[ERROR] --context-dir is required" >&2
        usage
        exit 1
    fi

    if [[ ! -d "$CONTEXT_DIR" ]]; then
        echo "[ERROR] Context directory not found: $CONTEXT_DIR" >&2
        exit 1
    fi

    if [[ ! -x "$VALIDATOR" ]]; then
        echo "[ERROR] Migration validator is missing or not executable: $VALIDATOR" >&2
        exit 1
    fi

    "$VALIDATOR" --context-dir "$CONTEXT_DIR"

    local seed_file="$CONTEXT_DIR/deployment.seed.env"
    local software_map="$CONTEXT_DIR/software-map.json"
    local paths_json="$CONTEXT_DIR/paths.json"
    local machine_profile="$CONTEXT_DIR/machine-profile.json"

    require_file "$seed_file"
    require_file "$software_map"
    require_file "$paths_json"
    require_file "$machine_profile"

    if [[ -f "$DEFAULTS_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$DEFAULTS_FILE"
    fi
    load_env_file "$seed_file"

    DEPLOY_PROFILE="${DEPLOY_PROFILE:-full}"
    INSTALL_MODE="${INSTALL_MODE:-fresh}"
    OS_DRIVE="${OS_DRIVE:-}"
    GAMES_DRIVE="${GAMES_DRIVE:-}"
    STORAGE_DRIVE="${STORAGE_DRIVE:-}"
    BACKUP_DRIVE="${BACKUP_DRIVE:-}"
    MOUNT_GAMES="${MOUNT_GAMES:-/mnt/games}"
    MOUNT_STORAGE="${MOUNT_STORAGE:-/mnt/storage}"
    MOUNT_BACKUPS="${MOUNT_BACKUPS:-/mnt/backups}"
    USE_FUSION360="${USE_FUSION360:-no}"
    FUSION360_PROVIDER="${FUSION360_PROVIDER:-codeberg-script}"
    FUSION360_FALLBACK_PROVIDER="${FUSION360_FALLBACK_PROVIDER:-bottles}"
    FUSION360_CHANNEL="${FUSION360_CHANNEL:-stable}"
    FUSION360_ENABLE_PROTON="${FUSION360_ENABLE_PROTON:-no}"
    FUSION360_PROTON_VERSION="${FUSION360_PROTON_VERSION:-GE-Proton10-32}"
    ENABLE_CLOUD_SETUP="${ENABLE_CLOUD_SETUP:-no}"
    WINDOWS_GAMES_DRIVE_HINT="${WINDOWS_GAMES_DRIVE_HINT:-}"

    case "$DEPLOY_PROFILE" in
        full|gaming|dev|minimal) ;;
        *)
            echo "[ERROR] Invalid DEPLOY_PROFILE in seed: $DEPLOY_PROFILE" >&2
            exit 1
            ;;
    esac

    case "$INSTALL_MODE" in
        fresh|dualboot|existing-pop) ;;
        *)
            echo "[ERROR] Invalid INSTALL_MODE in seed: $INSTALL_MODE" >&2
            exit 1
            ;;
    esac

    case "$FUSION360_PROVIDER" in
        codeberg-script|bottles|web|vm) ;;
        *)
            echo "[ERROR] Invalid FUSION360_PROVIDER in seed: $FUSION360_PROVIDER" >&2
            exit 1
            ;;
    esac

    case "$FUSION360_CHANNEL" in
        stable|dev) ;;
        *)
            echo "[ERROR] Invalid FUSION360_CHANNEL in seed: $FUSION360_CHANNEL" >&2
            exit 1
            ;;
    esac

    echo "[+] Imported migration context from: $CONTEXT_DIR"
    echo "[+] Resolved profile: $DEPLOY_PROFILE"
    echo "[+] Mounts: $MOUNT_GAMES, $MOUNT_STORAGE, $MOUNT_BACKUPS"
    echo "[+] Optional flags: USE_FUSION360=$USE_FUSION360 FUSION360_PROVIDER=$FUSION360_PROVIDER ENABLE_CLOUD_SETUP=$ENABLE_CLOUD_SETUP"

    if [[ -z "$GAMES_DRIVE" && -n "$WINDOWS_GAMES_DRIVE_HINT" ]]; then
        echo "[i] Windows games drive hint detected: $WINDOWS_GAMES_DRIVE_HINT"
        if [[ -t 0 ]]; then
            local games_input
            read -r -p "Enter Linux games partition for GAMES_DRIVE (example: /dev/nvme1n1p1, leave blank to skip): " games_input
            if [[ -n "$games_input" ]]; then
                GAMES_DRIVE="$games_input"
                echo "[+] Using GAMES_DRIVE=$GAMES_DRIVE"
            else
                echo "[i] Leaving GAMES_DRIVE empty; set it later in config/deployment.local.env"
            fi
        else
            echo "[i] Non-interactive session; leaving GAMES_DRIVE empty"
            echo "[i] Suggested follow-up: set GAMES_DRIVE in config/deployment.local.env"
        fi
    fi

    if [[ $WRITE_LOCAL_ENV -eq 1 ]]; then
        mkdir -p "$(dirname "$LOCAL_CONFIG_FILE")"
        cat > "$LOCAL_CONFIG_FILE" <<EOF
# Generated from migration context: $CONTEXT_DIR
DEPLOY_PROFILE=$DEPLOY_PROFILE
INSTALL_MODE=$INSTALL_MODE
OS_DRIVE=$OS_DRIVE
GAMES_DRIVE=$GAMES_DRIVE
STORAGE_DRIVE=$STORAGE_DRIVE
BACKUP_DRIVE=$BACKUP_DRIVE
MOUNT_GAMES=$MOUNT_GAMES
MOUNT_STORAGE=$MOUNT_STORAGE
MOUNT_BACKUPS=$MOUNT_BACKUPS
USE_FUSION360=$USE_FUSION360
FUSION360_PROVIDER=$FUSION360_PROVIDER
FUSION360_FALLBACK_PROVIDER=$FUSION360_FALLBACK_PROVIDER
FUSION360_CHANNEL=$FUSION360_CHANNEL
FUSION360_ENABLE_PROTON=$FUSION360_ENABLE_PROTON
FUSION360_PROTON_VERSION=$FUSION360_PROTON_VERSION
ENABLE_CLOUD_SETUP=$ENABLE_CLOUD_SETUP
WINDOWS_GAMES_DRIVE_HINT=$WINDOWS_GAMES_DRIVE_HINT
EOF
        echo "[+] Wrote local deployment config: $LOCAL_CONFIG_FILE"
    fi

    if [[ $PRINT_RESTORE_PLAN -eq 1 ]]; then
        print_restore_plan "$software_map" "$paths_json"
    fi

    echo ""
    echo "Recommended next commands:"
    echo "  ./scripts/full-setup.sh --check"
    echo "  ./scripts/full-setup.sh --profile $DEPLOY_PROFILE"
    echo "  ./scripts/full-setup.sh --verify"
}

main "$@"
