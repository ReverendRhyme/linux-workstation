#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$REPO_DIR/logs/hardware"
SANITIZE=0
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
    cat <<'EOF'
Usage: ./scripts/hardware-report.sh [OPTIONS] [OUT_DIR]

OPTIONS:
  --sanitize        Redact hostname, disk serials, and network interface details
  --output-dir DIR  Write reports to DIR
  -h, --help        Show this help

Examples:
  ./scripts/hardware-report.sh
  ./scripts/hardware-report.sh --sanitize
  ./scripts/hardware-report.sh --output-dir /tmp/hardware-report
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sanitize)
            SANITIZE=1
            ;;
        --output-dir)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "[ERROR] --output-dir requires a value" >&2
                exit 1
            fi
            OUT_DIR="$2"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            echo "[ERROR] Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            OUT_DIR="$1"
            ;;
    esac
    shift
done

mkdir -p "$OUT_DIR"

REPORT_TXT="$OUT_DIR/hardware-report-$TIMESTAMP.txt"
REPORT_JSON="$OUT_DIR/hardware-report-$TIMESTAMP.json"
LATEST_TXT="$OUT_DIR/hardware-report-latest.txt"
LATEST_JSON="$OUT_DIR/hardware-report-latest.json"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] python3 is required to generate JSON report" >&2
    exit 1
fi

OS_NAME="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Unknown}" || echo "Unknown")"
KERNEL="$(uname -r)"
HOSTNAME_VAL="$(hostname)"
CPU_MODEL="$(lscpu | awk -F: '/Model name/ {gsub(/^ +/, "", $2); print $2; exit}')"
CPU_CORES="$(nproc --all 2>/dev/null || echo "unknown")"
RAM_TOTAL="$(free -h | awk '/^Mem:/ {print $2}')"
GPU_PRIMARY="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/^[^:]*: //' || true)"

if [[ -z "${CPU_MODEL:-}" ]]; then
    CPU_MODEL="Unknown"
fi
if [[ -z "${GPU_PRIMARY:-}" ]]; then
    GPU_PRIMARY="Unknown"
fi

HOSTNAME_FOR_REPORT="$HOSTNAME_VAL"
if [[ $SANITIZE -eq 1 ]]; then
    HOSTNAME_FOR_REPORT="redacted"
fi

lsblk -J -O > "$OUT_DIR/lsblk-$TIMESTAMP.json"
lscpu -J > "$OUT_DIR/lscpu-$TIMESTAMP.json"
free -h > "$OUT_DIR/memory-$TIMESTAMP.txt"
lspci > "$OUT_DIR/lspci-$TIMESTAMP.txt" 2>/dev/null || true

if [[ $SANITIZE -eq 1 ]]; then
    STORAGE_SUMMARY="$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT -e7)"
    NETWORK_SUMMARY="(redacted in --sanitize mode)"
else
    STORAGE_SUMMARY="$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL -e7)"
    NETWORK_SUMMARY="$(ip -br link)"
fi

cat > "$REPORT_TXT" <<EOF
Hardware Report
Generated: $(date -Iseconds)

System
- Hostname: $HOSTNAME_FOR_REPORT
- OS: $OS_NAME
- Kernel: $KERNEL

CPU
- Model: $CPU_MODEL
- Logical cores: $CPU_CORES

Memory
- Total RAM: $RAM_TOTAL

GPU
- Primary display adapter: $GPU_PRIMARY

Storage (from lsblk)
$STORAGE_SUMMARY

Network (interfaces)
$NETWORK_SUMMARY
EOF

python3 - <<'PY' "$REPORT_JSON" "$HOSTNAME_FOR_REPORT" "$OS_NAME" "$KERNEL" "$CPU_MODEL" "$CPU_CORES" "$RAM_TOTAL" "$GPU_PRIMARY" "$OUT_DIR/lsblk-$TIMESTAMP.json" "$SANITIZE"
import json
import sys
from datetime import datetime, timezone

out, hostname, os_name, kernel, cpu_model, cpu_cores, ram_total, gpu_primary, lsblk_path, sanitize = sys.argv[1:]
sanitize_mode = sanitize == "1"

with open(lsblk_path, "r", encoding="utf-8") as fh:
    lsblk_data = json.load(fh)

disks = []
for dev in lsblk_data.get("blockdevices", []):
    if dev.get("type") in {"disk", "nvme"}:
        disks.append(
            {
                "name": dev.get("name"),
                "path": f"/dev/{dev.get('name')}",
                "size": dev.get("size"),
                "model": dev.get("model"),
                "serial": None if sanitize_mode else dev.get("serial"),
                "rota": dev.get("rota"),
                "tran": dev.get("tran"),
                "fstype": dev.get("fstype"),
                "mountpoint": dev.get("mountpoint"),
            }
        )

payload = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "sanitized": sanitize_mode,
    "system": {
        "hostname": hostname,
        "os": os_name,
        "kernel": kernel,
    },
    "cpu": {
        "model": cpu_model,
        "logical_cores": cpu_cores,
    },
    "memory": {
        "total": ram_total,
    },
    "gpu": {
        "primary": gpu_primary,
    },
    "storage": {
        "disks": disks,
    },
}

with open(out, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
PY

cp "$REPORT_TXT" "$LATEST_TXT"
cp "$REPORT_JSON" "$LATEST_JSON"

echo "[+] Hardware report generated"
if [[ $SANITIZE -eq 1 ]]; then
    echo "    Mode: sanitized"
fi
echo "    Text: $REPORT_TXT"
echo "    JSON: $REPORT_JSON"
echo "    Latest text: $LATEST_TXT"
echo "    Latest JSON: $LATEST_JSON"
