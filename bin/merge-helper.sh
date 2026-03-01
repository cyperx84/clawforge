#!/usr/bin/env bash
# merge-helper.sh — Module 7: PR merge helper with safety checks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: merge-helper.sh --repo <path> --pr <number> [options]

Options:
  --repo <path>     Path to the git repository (required)
  --pr <number>     PR number (required)
  --auto            Auto-merge if CI passing and reviews approved
  --squash          Use squash merge
  --task-id <id>    Task ID to update in registry
  --dry-run         Show what would happen without executing
  --help            Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
REPO="" PR_NUMBER="" AUTO=false SQUASH=false TASK_ID="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     REPO="$2"; shift 2 ;;
    --pr)       PR_NUMBER="$2"; shift 2 ;;
    --auto)     AUTO=true; shift ;;
    --squash)   SQUASH=true; shift ;;
    --task-id)  TASK_ID="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    *)          log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -z "$REPO" ]]      && { log_error "--repo is required"; usage; exit 1; }
[[ -z "$PR_NUMBER" ]] && { log_error "--pr is required"; usage; exit 1; }

REPO_ABS=$(cd "$REPO" && pwd)

# ── Resolve task ID from registry if not given ────────────────────────
if [[ -z "$TASK_ID" ]]; then
  _ensure_registry
  TASK_ID=$(jq -r --argjson pr "$PR_NUMBER" '.tasks[] | select(.pr == $pr) | .id' "$REGISTRY_FILE" 2>/dev/null || true)
fi

# ── Fetch PR info ────────────────────────────────────────────────────
log_info "Fetching PR #${PR_NUMBER} info..."
PR_INFO=$(gh pr view "$PR_NUMBER" --repo "$REPO_ABS" --json title,body,state,mergeable,reviewDecision,statusCheckRollup,additions,deletions,changedFiles 2>/dev/null || echo '{}')

PR_TITLE=$(echo "$PR_INFO" | jq -r '.title // "unknown"')
PR_STATE=$(echo "$PR_INFO" | jq -r '.state // "unknown"')
PR_MERGEABLE=$(echo "$PR_INFO" | jq -r '.mergeable // "unknown"')
PR_REVIEW=$(echo "$PR_INFO" | jq -r '.reviewDecision // "none"')
ADDITIONS=$(echo "$PR_INFO" | jq -r '.additions // 0')
DELETIONS=$(echo "$PR_INFO" | jq -r '.deletions // 0')
CHANGED=$(echo "$PR_INFO" | jq -r '.changedFiles // 0')

# Check CI status
CI_STATUS="unknown"
CI_CHECKS=$(echo "$PR_INFO" | jq '.statusCheckRollup // []')
if [[ "$CI_CHECKS" != "null" && "$CI_CHECKS" != "[]" ]]; then
  FAILING=$(echo "$CI_CHECKS" | jq '[.[] | select(.conclusion != "SUCCESS" and .conclusion != null)] | length')
  PENDING=$(echo "$CI_CHECKS" | jq '[.[] | select(.conclusion == null)] | length')
  if [[ "$FAILING" -gt 0 ]]; then
    CI_STATUS="failing"
  elif [[ "$PENDING" -gt 0 ]]; then
    CI_STATUS="pending"
  else
    CI_STATUS="passing"
  fi
else
  CI_STATUS="no-checks"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo "=== PR #${PR_NUMBER} Summary ==="
echo "Title:     $PR_TITLE"
echo "State:     $PR_STATE"
echo "Mergeable: $PR_MERGEABLE"
echo "Reviews:   $PR_REVIEW"
echo "CI:        $CI_STATUS"
echo "Diff:      +${ADDITIONS} -${DELETIONS} (${CHANGED} files)"
echo ""

# ── Merge decision ───────────────────────────────────────────────────
MERGE_CMD="gh pr merge $PR_NUMBER --repo $REPO_ABS"
if $SQUASH; then
  MERGE_CMD+=" --squash"
else
  MERGE_CMD+=" --merge"
fi
MERGE_CMD+=" --delete-branch"

CAN_AUTO=true
REASONS=()

if [[ "$PR_STATE" != "OPEN" ]]; then
  CAN_AUTO=false
  REASONS+=("PR is not open (state: $PR_STATE)")
fi

if [[ "$CI_STATUS" == "failing" ]]; then
  CAN_AUTO=false
  REASONS+=("CI checks are failing")
elif [[ "$CI_STATUS" == "pending" ]]; then
  CAN_AUTO=false
  REASONS+=("CI checks still pending")
fi

if [[ "$PR_REVIEW" != "APPROVED" ]]; then
  CAN_AUTO=false
  REASONS+=("Not all reviews approved (status: $PR_REVIEW)")
fi

if [[ "$PR_MERGEABLE" == "CONFLICTING" ]]; then
  CAN_AUTO=false
  REASONS+=("PR has merge conflicts")
fi

if $AUTO; then
  if $CAN_AUTO; then
    log_info "All checks pass, proceeding with auto-merge"
    if $DRY_RUN; then
      echo "[dry-run] Would execute: $MERGE_CMD"
    else
      eval "$MERGE_CMD" || { log_error "Merge failed"; exit 1; }
      log_info "PR #${PR_NUMBER} merged successfully"

      # Update registry
      if [[ -n "$TASK_ID" ]]; then
        registry_update "$TASK_ID" "status" '"done"'
        registry_update "$TASK_ID" "completedAt" "$(epoch_ms)"
        log_info "Registry updated: $TASK_ID → done"
      fi

      # Trigger cleanup
      CLEAN_SCRIPT="${SCRIPT_DIR}/clean.sh"
      if [[ -n "$TASK_ID" && -x "$CLEAN_SCRIPT" ]]; then
        log_info "Triggering cleanup for task $TASK_ID"
        "$CLEAN_SCRIPT" --task-id "$TASK_ID" 2>/dev/null || log_warn "Cleanup had issues"
      fi

      # Trigger notification
      NOTIFY_SCRIPT="${SCRIPT_DIR}/notify.sh"
      if [[ -x "$NOTIFY_SCRIPT" ]]; then
        "$NOTIFY_SCRIPT" --type task-done --task-id "${TASK_ID:-}" --description "$PR_TITLE" 2>/dev/null || log_warn "Notification had issues"
      fi
    fi
  else
    log_warn "Cannot auto-merge:"
    for reason in "${REASONS[@]}"; do
      echo "  • $reason"
    done
    exit 1
  fi
else
  if $CAN_AUTO; then
    echo "Ready to merge. Run:"
    echo "  $MERGE_CMD"
  else
    echo "Not ready to merge:"
    for reason in "${REASONS[@]}"; do
      echo "  • $reason"
    done
    echo ""
    echo "Manual merge command (when ready):"
    echo "  $MERGE_CMD"
  fi
fi
