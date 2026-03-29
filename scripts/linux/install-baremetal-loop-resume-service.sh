#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

STATE_DIR="${STATE_DIR:-$REPO_DIR/automation/test-loop}"
UNIT_PATH="/etc/systemd/system/baremetal-test-loop-resume.service"

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/install-baremetal-loop-resume-service.sh [OPTIONS]

Installs a systemd oneshot service that resumes the bare-metal test loop after reboot.

Options:
  --state-dir PATH   Durable state/log dir (default: automation/test-loop)
  --disable          Disable and remove installed service
  -h, --help         Show help
EOF
}

DISABLE=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --state-dir)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --state-dir requires a value" >&2
                    exit 1
                fi
                STATE_DIR="$2"
                shift
                ;;
            --disable)
                DISABLE=1
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
}

install_unit() {
    sudo tee "$UNIT_PATH" >/dev/null <<EOF
[Unit]
Description=Resume linux-workstation bare-metal test loop
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$REPO_DIR
ExecStart=/bin/bash -lc '$REPO_DIR/scripts/linux/run-baremetal-test-loop.sh --resume --state-dir "$STATE_DIR"'

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable baremetal-test-loop-resume.service
    echo "[+] Installed and enabled baremetal-test-loop-resume.service"
}

remove_unit() {
    sudo systemctl disable baremetal-test-loop-resume.service >/dev/null 2>&1 || true
    sudo rm -f "$UNIT_PATH"
    sudo systemctl daemon-reload
    echo "[+] Removed baremetal-test-loop-resume.service"
}

main() {
    parse_args "$@"
    if [[ $DISABLE -eq 1 ]]; then
        remove_unit
        exit 0
    fi

    install_unit
}

main "$@"
