#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SELF_HEAL_SCRIPT="$REPO_DIR/scripts/linux/run-self-healing-loop.sh"

CERT_ROOT_DIR="${CERT_ROOT_DIR:-$REPO_DIR/automation/new-build-certification}"
RUN_ID="cert-$(date +%Y%m%d-%H%M%S)"
CERT_DIR="$CERT_ROOT_DIR/$RUN_ID"
STATE_DIR="${STATE_DIR:-$REPO_DIR/automation/test-loop-certification}"
CONTEXT_DIR=""
PROFILE="full"
MAX_CYCLES=1
MAX_ATTEMPTS=1
RUN_PROVISION=1
RUN_LOOP=1
AUTO_PR=0

ROOT_FS="unknown"
ALLOW_NON_BTRFS=0

CHECK_STATUS="pending"
DRY_RUN_STATUS="pending"
PROFILE_STATUS="pending"
VERIFY_STATUS="pending"
LOOP_STATUS="pending"

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/run-new-build-certification.sh [OPTIONS]

Validates repository readiness on a fresh Linux build and writes a
certification summary under automation/new-build-certification/<run-id>/.

Options:
  --context-dir PATH          Migration context directory for loop runs
  --state-dir PATH            State directory for loop runs
  --cert-root-dir PATH        Root directory for certification artifacts
  --profile NAME              Setup profile (default: full)
  --max-cycles N              Self-healing loop max cycles (default: 1)
  --max-attempts N            Inner loop max attempts (default: 1)
  --auto-pr                   Allow self-healing loop to open/merge PRs
  --skip-provision            Skip full setup profile + verify steps
  --skip-loop                 Skip self-healing loop validation
  -h, --help                  Show help

Outputs:
  - SUMMARY.md with pass/fail status for each phase
  - phase logs in the run directory
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --context-dir)
                CONTEXT_DIR="$2"
                shift
                ;;
            --state-dir)
                STATE_DIR="$2"
                shift
                ;;
            --cert-root-dir)
                CERT_ROOT_DIR="$2"
                shift
                ;;
            --profile)
                PROFILE="$2"
                shift
                ;;
            --max-cycles)
                MAX_CYCLES="$2"
                shift
                ;;
            --max-attempts)
                MAX_ATTEMPTS="$2"
                shift
                ;;
            --auto-pr)
                AUTO_PR=1
                ;;
            --skip-provision)
                RUN_PROVISION=0
                ;;
            --skip-loop)
                RUN_LOOP=0
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

run_phase() {
    local phase_name="$1"
    local log_path="$2"
    local command="$3"

    echo "[+] $phase_name"
    set +e
    bash -lc "$command" >"$log_path" 2>&1
    local rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
        echo "[+] $phase_name: PASS"
        return 0
    fi

    echo "[WARN] $phase_name: FAIL (see $log_path)"
    return 1
}

write_summary() {
    local summary_path="$CERT_DIR/SUMMARY.md"
    cat > "$summary_path" <<EOF
# New Build Certification Summary

- Run ID: $RUN_ID
- Generated: $(date -Iseconds)
- Root filesystem: $ROOT_FS
- Loop mode: $( [[ $ALLOW_NON_BTRFS -eq 1 ]] && echo "non-btrfs fallback" || echo "snapshot-strict" )
- Context dir: ${CONTEXT_DIR:-none}
- Loop state dir: $STATE_DIR

## Phase Status

- Check: $CHECK_STATUS
- Dry run: $DRY_RUN_STATUS
- Provision profile ($PROFILE): $PROFILE_STATUS
- Verify: $VERIFY_STATUS
- Self-healing loop: $LOOP_STATUS

## Logs

- check: $CERT_DIR/01-check.log
- dry-run: $CERT_DIR/02-dry-run.log
- profile: $CERT_DIR/03-profile.log
- verify: $CERT_DIR/04-verify.log
- loop: $CERT_DIR/05-loop.log

## Follow-up

- For loop state details: $STATE_DIR/LATEST.md
- For AI feedback (if loop ran): $STATE_DIR/runs/<run-id>/AI_FEEDBACK.md
- For AI handoff (if loop ran): $STATE_DIR/HANDOFF.md
EOF
}

main() {
    parse_args "$@"

    mkdir -p "$CERT_ROOT_DIR"
    CERT_DIR="$CERT_ROOT_DIR/$RUN_ID"
    mkdir -p "$CERT_DIR"

    cd "$REPO_DIR"

    ROOT_FS="$(findmnt -no FSTYPE / 2>/dev/null || echo unknown)"
    if [[ "$ROOT_FS" != "btrfs" ]]; then
        ALLOW_NON_BTRFS=1
    fi

    if run_phase "System check" "$CERT_DIR/01-check.log" "./scripts/full-setup.sh --check"; then
        CHECK_STATUS="pass"
    else
        CHECK_STATUS="fail"
    fi

    if run_phase "Dry-run plan" "$CERT_DIR/02-dry-run.log" "./scripts/full-setup.sh --all --dry-run"; then
        DRY_RUN_STATUS="pass"
    else
        DRY_RUN_STATUS="fail"
    fi

    if [[ $RUN_PROVISION -eq 1 ]]; then
        if run_phase "Provision profile" "$CERT_DIR/03-profile.log" "./scripts/full-setup.sh --profile '$PROFILE'"; then
            PROFILE_STATUS="pass"
        else
            PROFILE_STATUS="fail"
        fi

        if run_phase "Verify profile" "$CERT_DIR/04-verify.log" "./scripts/full-setup.sh --verify"; then
            VERIFY_STATUS="pass"
        else
            VERIFY_STATUS="fail"
        fi
    else
        PROFILE_STATUS="skipped"
        VERIFY_STATUS="skipped"
    fi

    if [[ $RUN_LOOP -eq 1 ]]; then
        local loop_cmd
        loop_cmd="STATE_DIR='$STATE_DIR' '$SELF_HEAL_SCRIPT'"
        if [[ -n "$CONTEXT_DIR" ]]; then
            loop_cmd+=" --context-dir '$CONTEXT_DIR'"
        fi
        loop_cmd+=" --max-cycles '$MAX_CYCLES' --max-attempts '$MAX_ATTEMPTS'"
        if [[ $ALLOW_NON_BTRFS -eq 1 ]]; then
            loop_cmd+=" --allow-non-btrfs"
        fi
        if [[ $AUTO_PR -eq 0 ]]; then
            loop_cmd+=" --no-auto-pr"
        fi

        if run_phase "Self-healing loop" "$CERT_DIR/05-loop.log" "$loop_cmd"; then
            LOOP_STATUS="pass"
        else
            LOOP_STATUS="fail"
        fi
    else
        LOOP_STATUS="skipped"
    fi

    write_summary
    echo "[+] Certification summary: $CERT_DIR/SUMMARY.md"

    if [[ "$CHECK_STATUS" == "fail" || "$DRY_RUN_STATUS" == "fail" || "$PROFILE_STATUS" == "fail" || "$VERIFY_STATUS" == "fail" || "$LOOP_STATUS" == "fail" ]]; then
        exit 1
    fi
}

main "$@"
