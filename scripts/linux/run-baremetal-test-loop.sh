#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SNAPSHOT_HELPER="$REPO_DIR/scripts/linux/btrfs-snapshot-loop.sh"

STATE_DIR="${STATE_DIR:-$REPO_DIR/automation/test-loop}"
STATE_FILE=""
RUN_ID=""
ITERATION=0
SNAPSHOT_LABEL="baseline-clean"
SNAPPER_CONFIG="root"
CONTEXT_DIR=""

PREPARE_BASELINE=0
PULL_LATEST=0
PREPARE_FIX_BRANCH=0
ROLLBACK_AFTER=0
ROLLBACK_REBOOT=0
RESUME_MODE=0

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/run-baremetal-test-loop.sh [OPTIONS]

Runs one bare-metal test-loop iteration and writes durable logs/state.

Options:
  --state-dir PATH          Durable state/log dir (default: automation/test-loop)
  --snapshot-label NAME     Baseline snapshot label (default: baseline-clean)
  --snapper-config NAME     Snapper config (default: root)
  --context-dir PATH        Optional migration context dir for import step
  --prepare-baseline        Create baseline snapshot and exit
  --pull-latest             Pull latest main before running iteration
  --prepare-fix-branch      Create fix branch on failure
  --rollback-after          Stage rollback to baseline after iteration
  --rollback-reboot         Reboot immediately after rollback staging
  --resume                  Resume mode for boot-time continuation
  -h, --help                Show help

Examples:
  ./scripts/linux/run-baremetal-test-loop.sh --prepare-baseline
  ./scripts/linux/run-baremetal-test-loop.sh --context-dir migration/context/<machine-id> --pull-latest --rollback-after --rollback-reboot
EOF
}

require_tools() {
    if ! command -v git >/dev/null 2>&1; then
        echo "[ERROR] git is required" >&2
        exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "[ERROR] python3 is required" >&2
        exit 1
    fi
}

classify_failure() {
    local text="${1,,}"
    if [[ "$text" == *"permission"* || "$text" == *"denied"* || "$text" == *"unauthorized"* ]]; then
        echo "permissions"
    elif [[ "$text" == *"not found"* || "$text" == *"no such file"* || "$text" == *"path"* ]]; then
        echo "path"
    elif [[ "$text" == *"network"* || "$text" == *"connection"* || "$text" == *"timed out"* || "$text" == *"tls"* ]]; then
        echo "network"
    elif [[ "$text" == *"json"* || "$text" == *"schema"* || "$text" == *"invalid"* ]]; then
        echo "schema"
    elif [[ "$text" == *"git"* || "$text" == *"merge"* || "$text" == *"branch"* ]]; then
        echo "git"
    else
        echo "script"
    fi
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR/runs"
    STATE_FILE="$STATE_DIR/state.env"
}

init_or_load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE"
        RUN_ID="${RUN_ID:-run-$(date +%Y%m%d-%H%M%S)}"
        ITERATION="${ITERATION:-0}"
        SNAPSHOT_LABEL="${SNAPSHOT_LABEL:-$SNAPSHOT_LABEL}"
        SNAPPER_CONFIG="${SNAPPER_CONFIG:-$SNAPPER_CONFIG}"
    else
        RUN_ID="run-$(date +%Y%m%d-%H%M%S)"
        ITERATION=0
    fi
}

write_state() {
    local status="$1"
    local stage="$2"
    local failure_class="${3:-}"
    local failure_step="${4:-}"
    local log_path="${5:-}"
    local pending_resume="${6:-0}"

    cat > "$STATE_FILE" <<EOF
RUN_ID=$RUN_ID
ITERATION=$ITERATION
SNAPSHOT_LABEL=$SNAPSHOT_LABEL
SNAPPER_CONFIG=$SNAPPER_CONFIG
LAST_STATUS=$status
LAST_STAGE=$stage
LAST_FAILURE_CLASS=$failure_class
LAST_FAILURE_STEP=$failure_step
LAST_LOG_PATH=$log_path
PENDING_RESUME=$pending_resume
UPDATED_AT=$(date -Iseconds)
EOF
}

run_step() {
    local name="$1"
    local command="$2"
    local log_file="$3"

    echo "## $name" >> "$log_file"
    echo '```text' >> "$log_file"
    echo "$ $command" >> "$log_file"

    set +e
    bash -lc "$command" >> "$log_file" 2>&1
    local rc=$?
    set -e

    echo '```' >> "$log_file"
    echo "" >> "$log_file"
    return $rc
}

prepare_fix_branch() {
    local failure_class="$1"
    local date_tag
    date_tag="$(date +%Y%m%d)"
    local branch="fix/baremetal-loop/${date_tag}-${failure_class}"

    echo "[+] Creating fix branch: $branch"
    if git checkout -b "$branch" >/dev/null 2>&1; then
        echo "[+] Created: $branch"
    else
        echo "[WARN] Could not create fix branch automatically"
    fi
}

append_latest_summary() {
    local status="$1"
    local log_file="$2"
    local failure_class="${3:-}"
    local failure_step="${4:-}"

    cat > "$STATE_DIR/LATEST.md" <<EOF
# Bare-Metal Test Loop Latest

- Run ID: $RUN_ID
- Iteration: $ITERATION
- Status: $status
- Snapshot label: $SNAPSHOT_LABEL
- Failure class: ${failure_class:-none}
- Failure step: ${failure_step:-none}
- Log: $log_file
- Updated: $(date -Iseconds)
EOF
}

run_iteration() {
    ITERATION=$((ITERATION + 1))
    local run_dir="$STATE_DIR/runs/$RUN_ID"
    mkdir -p "$run_dir"
    local log_file="$run_dir/iteration-$ITERATION.md"

    echo "# Bare-Metal Test Loop Iteration $ITERATION" > "$log_file"
    echo "" >> "$log_file"
    echo "- Run ID: $RUN_ID" >> "$log_file"
    echo "- Started: $(date -Iseconds)" >> "$log_file"
    echo "- Snapshot label: $SNAPSHOT_LABEL" >> "$log_file"
    echo "" >> "$log_file"

    write_state "running" "iteration-start" "" "" "$log_file" 0

    if [[ $PULL_LATEST -eq 1 ]]; then
        if ! run_step "git pull main" "git fetch origin && git checkout main && git pull --ff-only origin main" "$log_file"; then
            local out
            out="$(tail -n 50 "$log_file")"
            local cls
            cls="$(classify_failure "$out")"
            write_state "blocked" "git-pull" "$cls" "git pull main" "$log_file" 0
            append_latest_summary "BLOCKED" "$log_file" "$cls" "git pull main"
            [[ $PREPARE_FIX_BRANCH -eq 1 ]] && prepare_fix_branch "$cls"
            return 1
        fi
    fi

    if [[ -n "$CONTEXT_DIR" ]]; then
        if ! run_step "import migration context" "./scripts/linux/import-migration-context.sh --context-dir '$CONTEXT_DIR' --write-local-env --print-restore-plan" "$log_file"; then
            local out
            out="$(tail -n 50 "$log_file")"
            local cls
            cls="$(classify_failure "$out")"
            write_state "blocked" "import-context" "$cls" "import migration context" "$log_file" 0
            append_latest_summary "BLOCKED" "$log_file" "$cls" "import migration context"
            [[ $PREPARE_FIX_BRANCH -eq 1 ]] && prepare_fix_branch "$cls"
            return 1
        fi
    fi

    if ! run_step "setup check" "./scripts/full-setup.sh --check" "$log_file"; then
        local out
        out="$(tail -n 50 "$log_file")"
        local cls
        cls="$(classify_failure "$out")"
        write_state "blocked" "setup-check" "$cls" "full-setup --check" "$log_file" 0
        append_latest_summary "BLOCKED" "$log_file" "$cls" "full-setup --check"
        [[ $PREPARE_FIX_BRANCH -eq 1 ]] && prepare_fix_branch "$cls"
        return 1
    fi

    if ! run_step "setup profile" "source ./config/defaults.env && test -f ./config/deployment.local.env && source ./config/deployment.local.env; ./scripts/full-setup.sh --profile \"\${DEPLOY_PROFILE:-full}\"" "$log_file"; then
        local out
        out="$(tail -n 80 "$log_file")"
        local cls
        cls="$(classify_failure "$out")"
        write_state "blocked" "setup-profile" "$cls" "full-setup --profile" "$log_file" 0
        append_latest_summary "BLOCKED" "$log_file" "$cls" "full-setup --profile"
        [[ $PREPARE_FIX_BRANCH -eq 1 ]] && prepare_fix_branch "$cls"
        return 1
    fi

    if ! run_step "setup verify" "./scripts/full-setup.sh --verify" "$log_file"; then
        local out
        out="$(tail -n 80 "$log_file")"
        local cls
        cls="$(classify_failure "$out")"
        write_state "blocked" "setup-verify" "$cls" "full-setup --verify" "$log_file" 0
        append_latest_summary "BLOCKED" "$log_file" "$cls" "full-setup --verify"
        [[ $PREPARE_FIX_BRANCH -eq 1 ]] && prepare_fix_branch "$cls"
        return 1
    fi

    write_state "pass" "iteration-complete" "" "" "$log_file" 0
    append_latest_summary "PASS" "$log_file"
    echo "[+] Iteration $ITERATION PASSED"
    echo "[+] Log: $log_file"
    return 0
}

schedule_rollback() {
    local pending_resume="0"
    if [[ $RESUME_MODE -eq 0 ]]; then
        pending_resume="1"
    fi
    write_state "rolling-back" "rollback" "" "" "${LAST_LOG_PATH:-}" "$pending_resume"

    local reboot_flag=""
    if [[ $ROLLBACK_REBOOT -eq 1 ]]; then
        reboot_flag="--reboot"
    fi

    "$SNAPSHOT_HELPER" rollback --label "$SNAPSHOT_LABEL" --config "$SNAPPER_CONFIG" $reboot_flag
}

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
            --snapshot-label)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --snapshot-label requires a value" >&2
                    exit 1
                fi
                SNAPSHOT_LABEL="$2"
                shift
                ;;
            --snapper-config)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --snapper-config requires a value" >&2
                    exit 1
                fi
                SNAPPER_CONFIG="$2"
                shift
                ;;
            --context-dir)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    echo "[ERROR] --context-dir requires a value" >&2
                    exit 1
                fi
                CONTEXT_DIR="$2"
                shift
                ;;
            --prepare-baseline)
                PREPARE_BASELINE=1
                ;;
            --pull-latest)
                PULL_LATEST=1
                ;;
            --prepare-fix-branch)
                PREPARE_FIX_BRANCH=1
                ;;
            --rollback-after)
                ROLLBACK_AFTER=1
                ;;
            --rollback-reboot)
                ROLLBACK_REBOOT=1
                ;;
            --resume)
                RESUME_MODE=1
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
    ensure_state_dir
    init_or_load_state

    cd "$REPO_DIR"

    if [[ $PREPARE_BASELINE -eq 1 ]]; then
        "$SNAPSHOT_HELPER" create-baseline --label "$SNAPSHOT_LABEL" --config "$SNAPPER_CONFIG"
        write_state "baseline-ready" "baseline-create" "" "" "" 0
        echo "[+] Baseline snapshot ready: $SNAPSHOT_LABEL"
        exit 0
    fi

    if [[ $RESUME_MODE -eq 1 ]]; then
        if [[ "${PENDING_RESUME:-0}" != "1" ]]; then
            echo "[+] Resume mode: no pending resume marker, exiting"
            exit 0
        fi
        echo "[+] Resume mode active: continuing loop"
        PULL_LATEST=1
        write_state "resuming" "resume" "" "" "${LAST_LOG_PATH:-}" 0
    fi

    if run_iteration; then
        if [[ $ROLLBACK_AFTER -eq 1 ]]; then
            schedule_rollback
        fi
        echo "Status: PASS"
    else
        echo "Status: BLOCKED"
        if [[ $ROLLBACK_AFTER -eq 1 ]]; then
            schedule_rollback
        fi
        exit 1
    fi
}

main "$@"
