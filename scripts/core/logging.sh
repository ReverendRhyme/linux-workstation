#!/usr/bin/env bash
# Core logging library
# Provides standardized logging functions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[+]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "${LOG_FILE:-/tmp/setup.log}"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "${LOG_FILE:-/tmp/setup.log}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "${LOG_FILE:-/tmp/setup.log}"
}

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SECTION] $1" >> "${LOG_FILE:-/tmp/setup.log}"
}

log_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

log_footer() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# Initialize log file
init_logging() {
    export LOG_FILE="${LOG_DIR:-./logs}/setup-$(date '+%Y%m%d-%H%M%S').log"
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [START] Logging initialized" >> "$LOG_FILE"
}
