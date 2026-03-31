#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
INNER_LOOP_SCRIPT="$REPO_DIR/scripts/linux/run-baremetal-test-loop.sh"

STATE_DIR="${STATE_DIR:-$REPO_DIR/automation/test-loop}"
CONTEXT_DIR=""
BASE_BRANCH="main"
MAX_CYCLES=5
INNER_MAX_ATTEMPTS=3
AUTO_MERGE_METHOD="squash"
AUTO_PR=1
ALLOW_NON_BTRFS=0
PULL_LATEST=1
ROLLBACK_AFTER=0
ROLLBACK_REBOOT=0
LAST_HEAL_BRANCH=""
LAST_HEAL_COMMIT=""
LAST_HEAL_PR_URL=""

usage() {
    cat <<'EOF'
Usage: ./scripts/linux/run-self-healing-loop.sh [OPTIONS]

Runs the bare-metal loop, and when BLOCKED with code changes, automatically:
1) creates a fix branch
2) commits current repo changes
3) opens a PR
4) merges PR
5) returns to main and reruns until PASS or max cycles

Options:
  --context-dir PATH          Migration context directory
  --state-dir PATH            Loop state/log directory
  --base-branch NAME          Base branch for PRs (default: main)
  --max-cycles N              Max heal cycles (default: 5)
  --max-attempts N            Inner loop attempts per cycle (default: 3)
  --merge-method METHOD       squash|rebase|none (default: squash)
  --no-auto-pr                Do not create PR/merge automatically
  --allow-non-btrfs           Allow degraded loop mode without rollback
  --no-pull-latest            Do not pass --pull-latest to inner loop
  --rollback-after            Pass rollback flag to inner loop
  --rollback-reboot           Pass rollback reboot flag to inner loop
  -h, --help                  Show help

Notes:
- This script only commits repo changes currently present in git status.
- It excludes loop runtime artifacts under automation/test-loop and logs.
- It writes per-run AI feedback to runs/<run-id>/AI_FEEDBACK.md.
EOF
}

require_tools() {
    command -v git >/dev/null 2>&1 || { echo "[ERROR] git is required" >&2; exit 1; }
    command -v gh >/dev/null 2>&1 || { echo "[ERROR] gh is required" >&2; exit 1; }
    command -v bash >/dev/null 2>&1 || { echo "[ERROR] bash is required" >&2; exit 1; }
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
            --base-branch)
                BASE_BRANCH="$2"
                shift
                ;;
            --max-cycles)
                MAX_CYCLES="$2"
                shift
                ;;
            --max-attempts)
                INNER_MAX_ATTEMPTS="$2"
                shift
                ;;
            --merge-method)
                AUTO_MERGE_METHOD="$2"
                shift
                ;;
            --no-auto-pr)
                AUTO_PR=0
                ;;
            --allow-non-btrfs)
                ALLOW_NON_BTRFS=1
                ;;
            --no-pull-latest)
                PULL_LATEST=0
                ;;
            --rollback-after)
                ROLLBACK_AFTER=1
                ;;
            --rollback-reboot)
                ROLLBACK_REBOOT=1
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

sync_base_branch() {
    git checkout "$BASE_BRANCH" >/dev/null 2>&1
    git pull --ff-only origin "$BASE_BRANCH" >/dev/null 2>&1
}

load_state_metadata() {
    local state_file="$STATE_DIR/state.env"
    if [[ -f "$state_file" ]]; then
        # shellcheck disable=SC1090
        source "$state_file"
        return 0
    fi
    return 1
}

feedback_file_path() {
    if ! load_state_metadata; then
        return 1
    fi
    printf '%s/runs/%s/AI_FEEDBACK.md\n' "$STATE_DIR" "$RUN_ID"
}

ensure_feedback_file() {
    local fp
    if ! fp="$(feedback_file_path)"; then
        return 1
    fi
    mkdir -p "$(dirname "$fp")"
    if [[ ! -f "$fp" ]]; then
        cat > "$fp" <<EOF
# AI Loop Feedback

- Run ID: ${RUN_ID:-unknown}
- Created: $(date -Iseconds)

EOF
    fi
}

append_feedback_entry() {
    local cycle="$1"
    local outcome="$2"
    local worked="$3"
    local failed="$4"
    local changes="$5"
    local reason="$6"

    local fp
    if ! fp="$(feedback_file_path)"; then
        return 0
    fi
    ensure_feedback_file || true

    cat >> "$fp" <<EOF
## Cycle $cycle - $outcome

- Timestamp: $(date -Iseconds)
- Iteration: ${ITERATION:-unknown}
- Worked: $worked
- Did not work: $failed
- Why: $reason
- Changes made: $changes
- Latest log: ${LAST_LOG_PATH:-n/a}

EOF
}

write_handoff_doc() {
    local phase="$1"
    load_state_metadata || true

    local run_id="${RUN_ID:-unknown}"
    local iteration="${ITERATION:-unknown}"
    local status="${LAST_STATUS:-unknown}"
    local failure_class="${LAST_FAILURE_CLASS:-none}"
    local failure_step="${LAST_FAILURE_STEP:-none}"
    local log_path="${LAST_LOG_PATH:-n/a}"
    local loop_mode="snapshot"
    if [[ $ALLOW_NON_BTRFS -eq 1 ]]; then
        loop_mode="non-btrfs validation (no rollback)"
    fi

    local run_handoff="$STATE_DIR/runs/$run_id/HANDOFF.md"
    local latest_handoff="$STATE_DIR/HANDOFF.md"
    mkdir -p "$(dirname "$run_handoff")"

    cat > "$run_handoff" <<EOF
# Bare-Metal Loop AI Handoff

- Generated: $(date -Iseconds)
- Phase: $phase
- Run ID: $run_id
- Iteration: $iteration
- Last status: $status
- Loop mode: $loop_mode
- Last failure class: $failure_class
- Last failure step: $failure_step
- Last log: $log_path
- Last patch branch: ${LAST_HEAL_BRANCH:-n/a}
- Last patch commit: ${LAST_HEAL_COMMIT:-n/a}
- Last patch PR: ${LAST_HEAL_PR_URL:-n/a}

## What Worked
- Preflight + loop orchestration executed through run-self-healing-loop.sh.
- Feedback journal is maintained in AI_FEEDBACK.md for this run.

## What Did Not Work
- If status is blocked, see failure class/step and the iteration log path above.

## Next Round Instructions
- Resume self-healing loop:
  - STATE_DIR=$STATE_DIR ./scripts/linux/run-self-healing-loop.sh --context-dir ${CONTEXT_DIR:-migration/context/<machine-id>} --max-cycles $MAX_CYCLES --max-attempts $INNER_MAX_ATTEMPTS$( [[ $ALLOW_NON_BTRFS -eq 1 ]] && printf ' --allow-non-btrfs' )
- Review latest summary:
  - $STATE_DIR/LATEST.md
- Review AI run journal:
  - $STATE_DIR/runs/$run_id/AI_FEEDBACK.md
EOF

    cp "$run_handoff" "$latest_handoff"
}

collect_status_lines() {
    local state_rel=""
    if [[ "$STATE_DIR" == "$REPO_DIR"/* ]]; then
        state_rel="${STATE_DIR#"$REPO_DIR"/}"
    fi

    if [[ -n "$state_rel" ]]; then
        git status --porcelain --untracked-files=all -- . \
            ":(exclude)$state_rel/**" \
            ":(exclude)automation/test-loop/**" \
            ":(exclude)logs/**"
    else
        git status --porcelain --untracked-files=all -- . \
            ":(exclude)automation/test-loop/**" \
            ":(exclude)logs/**"
    fi
}

create_heal_pr() {
    local cycle="$1"
    local state_file="$STATE_DIR/state.env"
    local failure_class="script"
    local failure_step="unknown"
    local log_path=""

    if [[ -f "$state_file" ]]; then
        # shellcheck disable=SC1090
        source "$state_file"
        failure_class="${LAST_FAILURE_CLASS:-script}"
        failure_step="${LAST_FAILURE_STEP:-unknown}"
        log_path="${LAST_LOG_PATH:-}"
    fi

    local date_tag
    date_tag="$(date +%Y%m%d)"
    local branch="fix/baremetal-heal/${date_tag}-${failure_class}-c${cycle}"
    LAST_HEAL_BRANCH="$branch"

    git checkout -b "$branch" >/dev/null 2>&1 || git checkout "$branch" >/dev/null 2>&1

    local state_rel=""
    if [[ "$STATE_DIR" == "$REPO_DIR"/* ]]; then
        state_rel="${STATE_DIR#"$REPO_DIR"/}"
    fi

    if [[ -n "$state_rel" ]]; then
        git add -A -- . \
            ":(exclude)$state_rel/**" \
            ":(exclude)automation/test-loop/**" \
            ":(exclude)logs/**"
    else
        git add -A -- . \
            ":(exclude)automation/test-loop/**" \
            ":(exclude)logs/**"
    fi

    if git diff --cached --quiet; then
        echo "[WARN] No code changes to commit for blocker '$failure_step'"
        return 1
    fi

    local msg
    msg="Fix bare-metal loop blocker: $failure_step ($failure_class)."
    git commit -m "$msg" >/dev/null
    LAST_HEAL_COMMIT="$(git rev-parse --short HEAD)"
    git push -u origin "$branch" >/dev/null

    local pr_title="Fix bare-metal loop blocker: $failure_step"
    local pr_body
    pr_body="$(cat <<EOF
## Summary
- unblock bare-metal self-healing loop blocker
- failure class: $failure_class
- failure step: $failure_step
- loop log: ${log_path:-n/a}

## Validation
- rerun: $INNER_LOOP_SCRIPT
EOF
)"

    local pr_url
    pr_url="$(gh pr create --title "$pr_title" --body "$pr_body" --base "$BASE_BRANCH" --head "$branch")"
    LAST_HEAL_PR_URL="$pr_url"
    echo "[+] Opened PR: $pr_url"

    case "$AUTO_MERGE_METHOD" in
        squash)
            gh pr merge "$pr_url" --squash --delete-branch >/dev/null
            ;;
        rebase)
            gh pr merge "$pr_url" --rebase --delete-branch >/dev/null
            ;;
        none)
            echo "[i] Auto-merge disabled; merge PR manually: $pr_url"
            return 2
            ;;
        *)
            echo "[ERROR] Unsupported --merge-method: $AUTO_MERGE_METHOD" >&2
            return 1
            ;;
    esac

    echo "[+] Merged PR: $pr_url"
    return 0
}

run_inner_loop() {
    local cmd=("$INNER_LOOP_SCRIPT" --state-dir "$STATE_DIR")

    [[ -n "$CONTEXT_DIR" ]] && cmd+=(--context-dir "$CONTEXT_DIR")
    [[ $PULL_LATEST -eq 1 ]] && cmd+=(--pull-latest)
    [[ $ROLLBACK_AFTER -eq 1 ]] && cmd+=(--rollback-after)
    [[ $ROLLBACK_REBOOT -eq 1 ]] && cmd+=(--rollback-reboot)
    [[ $ALLOW_NON_BTRFS -eq 1 ]] && cmd+=(--allow-non-btrfs)

    cmd+=(--prepare-fix-branch --loop-until-pass --max-attempts "$INNER_MAX_ATTEMPTS")

    STATE_DIR="$STATE_DIR" "${cmd[@]}"
}

main() {
    parse_args "$@"
    require_tools

    cd "$REPO_DIR"
    sync_base_branch

    local cycle=1
    while [[ $cycle -le $MAX_CYCLES ]]; do
        echo "[+] Self-heal cycle $cycle/$MAX_CYCLES"

        if run_inner_loop; then
            load_state_metadata || true
            append_feedback_entry "$cycle" "PASS" \
                "loop completed successfully" \
                "none" \
                "no code changes required in this cycle" \
                "all required setup and verification steps passed"
            write_handoff_doc "pass"
            echo "[+] Self-healing loop completed with PASS"
            exit 0
        fi

        echo "[WARN] Loop returned BLOCKED"
        load_state_metadata || true
        if [[ $AUTO_PR -eq 0 ]]; then
            append_feedback_entry "$cycle" "BLOCKED" \
                "partial loop execution" \
                "${LAST_FAILURE_STEP:-unknown}" \
                "none (auto PR disabled)" \
                "auto repair workflow disabled"
            write_handoff_doc "blocked-no-auto-pr"
            echo "[i] Auto PR disabled; apply a fix and rerun"
            exit 1
        fi

        if [[ -z "$(collect_status_lines)" ]]; then
            append_feedback_entry "$cycle" "BLOCKED" \
                "loop diagnostics and blocker classification" \
                "${LAST_FAILURE_STEP:-unknown}" \
                "none (no patch detected)" \
                "no code diff available for automated commit"
            write_handoff_doc "blocked-no-diff"
            echo "[WARN] No code changes detected to heal automatically"
            echo "[i] Last blocker is in: $STATE_DIR/LATEST.md"
            exit 1
        fi

        if ! create_heal_pr "$cycle"; then
            local pr_rc=$?
            if [[ $pr_rc -eq 2 ]]; then
                append_feedback_entry "$cycle" "BLOCKED" \
                    "patch branch and PR created" \
                    "merge pending" \
                    "branch=${LAST_HEAL_BRANCH:-n/a}, commit=${LAST_HEAL_COMMIT:-n/a}, pr=${LAST_HEAL_PR_URL:-n/a}" \
                    "auto-merge disabled by configuration"
                write_handoff_doc "blocked-waiting-merge"
                echo "[i] Waiting on manual PR merge before continuing"
                exit 1
            fi
            append_feedback_entry "$cycle" "BLOCKED" \
                "patch preparation started" \
                "automatic PR creation/merge" \
                "branch=${LAST_HEAL_BRANCH:-n/a}, commit=${LAST_HEAL_COMMIT:-n/a}, pr=${LAST_HEAL_PR_URL:-n/a}" \
                "GitHub step failed"
            write_handoff_doc "blocked-pr-failure"
            echo "[WARN] Failed to auto-create and merge heal PR"
            exit 1
        fi

        append_feedback_entry "$cycle" "HEALED" \
            "fix committed and merged" \
            "${LAST_FAILURE_STEP:-unknown}" \
            "branch=${LAST_HEAL_BRANCH:-n/a}, commit=${LAST_HEAL_COMMIT:-n/a}, pr=${LAST_HEAL_PR_URL:-n/a}" \
            "blocker patched and merged; continuing loop"
        write_handoff_doc "healed-continue"

        sync_base_branch
        cycle=$((cycle + 1))
    done

    echo "[ERROR] Reached max cycles ($MAX_CYCLES) without PASS" >&2
    exit 1
}

main "$@"
