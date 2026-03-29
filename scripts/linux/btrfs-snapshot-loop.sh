#!/usr/bin/env bash
set -euo pipefail

SNAPPER_CONFIG="root"
ACTION=""
LABEL="baseline-clean"
REBOOT_AFTER=0

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/btrfs-snapshot-loop.sh <action> [options]

Actions:
  create-baseline    Create a named baseline snapshot
  rollback           Roll back to a named snapshot (snapper rollback)
  list               List snapshots and descriptions

Options:
  --label NAME       Snapshot description label (default: baseline-clean)
  --config NAME      Snapper config name (default: root)
  --reboot           Reboot after rollback
  -h, --help         Show help

Examples:
  ./scripts/linux/btrfs-snapshot-loop.sh create-baseline --label baseline-clean
  ./scripts/linux/btrfs-snapshot-loop.sh rollback --label baseline-clean --reboot
  ./scripts/linux/btrfs-snapshot-loop.sh list
EOF
}

require_tools() {
    if ! command -v snapper >/dev/null 2>&1; then
        echo "[ERROR] snapper is not installed" >&2
        exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "[ERROR] python3 is required" >&2
        exit 1
    fi
}

find_snapshot_id_by_label() {
    local label="$1"
    sudo snapper -c "$SNAPPER_CONFIG" list --csvout | python3 - "$label" <<'PY'
import csv
import io
import sys

label = sys.argv[1]
text = sys.stdin.read()
reader = csv.reader(io.StringIO(text))

rows = list(reader)
if not rows:
    sys.exit(1)

header = [h.strip() for h in rows[0]]
idx_num = None
idx_desc = None
for i, name in enumerate(header):
    low = name.lower()
    if low in {"#", "number", "num"}:
        idx_num = i
    if low == "description":
        idx_desc = i

if idx_num is None or idx_desc is None:
    sys.exit(1)

matches = []
for row in rows[1:]:
    if len(row) <= max(idx_num, idx_desc):
        continue
    desc = row[idx_desc].strip()
    num = row[idx_num].strip()
    if desc == label:
        try:
            matches.append(int(num))
        except ValueError:
            pass

if not matches:
    sys.exit(2)

print(max(matches))
PY
}

create_baseline() {
    echo "[+] Creating baseline snapshot: $LABEL"
    sudo snapper -c "$SNAPPER_CONFIG" create --description "$LABEL" --userdata "kind=baseline"
    echo "[+] Baseline snapshot created"
}

list_snapshots() {
    echo "[+] Snapper snapshots (config=$SNAPPER_CONFIG)"
    sudo snapper -c "$SNAPPER_CONFIG" list
}

rollback_to_label() {
    echo "[+] Looking up snapshot label: $LABEL"
    local snapshot_id
    if ! snapshot_id="$(find_snapshot_id_by_label "$LABEL")"; then
        echo "[ERROR] Could not find snapshot with label: $LABEL" >&2
        exit 1
    fi

    echo "[+] Rolling back to snapshot #$snapshot_id ($LABEL)"
    sudo snapper -c "$SNAPPER_CONFIG" rollback "$snapshot_id"
    echo "[+] Rollback staged. A reboot is required to enter rolled-back state."

    if [[ $REBOOT_AFTER -eq 1 ]]; then
        echo "[+] Rebooting now..."
        sudo systemctl reboot
    fi
}

parse_args() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    ACTION="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --label)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --label requires a value" >&2
                    exit 1
                fi
                LABEL="$2"
                shift
                ;;
            --config)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --config requires a value" >&2
                    exit 1
                fi
                SNAPPER_CONFIG="$2"
                shift
                ;;
            --reboot)
                REBOOT_AFTER=1
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

main() {
    parse_args "$@"
    require_tools

    case "$ACTION" in
        create-baseline)
            create_baseline
            ;;
        rollback)
            rollback_to_label
            ;;
        list)
            list_snapshots
            ;;
        *)
            echo "[ERROR] Unknown action: $ACTION" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
