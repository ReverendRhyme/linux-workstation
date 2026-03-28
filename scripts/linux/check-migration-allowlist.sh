#!/usr/bin/env bash
set -euo pipefail

MODE="staged"

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/check-migration-allowlist.sh [--staged|--all]

Validates file allowlist under migration/context.
EOF
}

is_allowed_name() {
    local name="$1"
    case "$name" in
        .gitkeep)
            return 0
            ;;
        machine-profile.json|software-map.json|paths.json|backup-manifest.json|deployment.seed.env|summary.md)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

collect_files() {
    if [[ "$MODE" == "staged" ]]; then
        git diff --cached --name-only --diff-filter=ACMR
    else
        git ls-files
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --staged)
                MODE="staged"
                ;;
            --all)
                MODE="all"
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

    local invalid=0
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        [[ "$path" != migration/context/* ]] && continue

        local base
        base="$(basename "$path")"
        if ! is_allowed_name "$base"; then
            echo "[ERROR] Disallowed migration context file: $path" >&2
            invalid=1
        fi

        if [[ "$path" == */raw/* || "$path" == */sensitive/* ]]; then
            echo "[ERROR] Raw or sensitive path is not committable: $path" >&2
            invalid=1
        fi
    done < <(collect_files)

    if [[ $invalid -ne 0 ]]; then
        echo "[ERROR] Migration allowlist check failed" >&2
        exit 1
    fi

    echo "[+] Migration allowlist check passed"
}

main "$@"
