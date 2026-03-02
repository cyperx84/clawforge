#!/usr/bin/env bash
# sprint.sh — Sprint mode: single agent, full dev cycle
# Usage: clawforge sprint [repo] "<task>" [flags]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge sprint [repo] "<task>" [flags]

The workhorse. Single agent, full dev cycle.

Arguments:
  [repo]               Path to git repository (default: auto-detect from cwd)
  "<task>"             Task description (required)

Flags:
  --quick              Patch mode: auto-branch, auto-merge, skip review, targeted tests
  --branch <name>      Override auto-generated branch name
  --agent <name>       Agent to use: claude or codex (default: auto-detect)
  --model <model>      Model override
  --auto-merge         Merge automatically if CI + review pass
  --dry-run            Preview what would happen
  --help               Show this help

Examples:
  clawforge sprint "Add JWT authentication middleware"
  clawforge sprint ~/github/api "Fix null pointer in UserService" --quick
  clawforge sprint "Add rate limiter" --branch feat/rate-limit --agent codex
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
REPO="" TASK="" BRANCH="" AGENT="" MODEL="" QUICK=false AUTO_MERGE=false DRY_RUN=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)      QUICK=true; shift ;;
    --branch)     BRANCH="$2"; shift 2 ;;
    --agent)      AGENT="$2"; shift 2 ;;
    --model)      MODEL="$2"; shift 2 ;;
    --auto-merge) AUTO_MERGE=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    --*)          log_error "Unknown option: $1"; usage; exit 1 ;;
    *)            POSITIONAL+=("$1"); shift ;;
  esac
done

# Parse positional args: [repo] "<task>"
case ${#POSITIONAL[@]} in
  0) log_error "Task description is required"; usage; exit 1 ;;
  1) TASK="${POSITIONAL[0]}" ;;
  2) REPO="${POSITIONAL[0]}"; TASK="${POSITIONAL[1]}" ;;
  *) log_error "Too many positional arguments"; usage; exit 1 ;;
esac

# ── Resolve repo ──────────────────────────────────────────────────────
if [[ -z "$REPO" ]]; then
  REPO=$(detect_repo) || { log_error "No --repo and no git repo found from cwd"; exit 1; }
fi
REPO_ABS=$(cd "$REPO" && pwd)

# ── Resolve branch ────────────────────────────────────────────────────
if [[ -z "$BRANCH" ]]; then
  if $QUICK; then
    BRANCH=$(auto_branch_name "quick" "$TASK" "$REPO_ABS")
  else
    BRANCH=$(auto_branch_name "sprint" "$TASK" "$REPO_ABS")
  fi
fi

# ── Quick mode overrides ─────────────────────────────────────────────
if $QUICK; then
  AUTO_MERGE=true
fi

# ── Resolve agent + model ────────────────────────────────────────────
RESOLVED_AGENT=$(detect_agent "${AGENT:-}")
if [[ -z "$MODEL" ]]; then
  if [[ "$RESOLVED_AGENT" == "claude" ]]; then
    MODEL=$(config_get default_model_claude "claude-sonnet-4-5")
  else
    MODEL=$(config_get default_model_codex "gpt-5.3-codex")
  fi
fi

# ── Assign short ID ──────────────────────────────────────────────────
SHORT_ID=$(_next_short_id)
SAFE_BRANCH=$(sanitize_branch "$BRANCH")
MODE="sprint"
$QUICK && MODE="quick"

# ── Log intent ────────────────────────────────────────────────────────
log_info "Sprint mode ($MODE): $TASK"
log_info "Repo: $REPO_ABS"
log_info "Branch: $BRANCH (short ID: #$SHORT_ID)"
log_info "Agent: $RESOLVED_AGENT ($MODEL)"
$QUICK && log_info "Quick mode: auto-merge=true, skip-review=true"
$AUTO_MERGE && log_info "Auto-merge enabled"

# ── Dry-run ───────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo "=== Sprint Dry Run ==="
  echo "  Mode:       $MODE"
  echo "  Task:       $TASK"
  echo "  Repo:       $REPO_ABS"
  echo "  Branch:     $BRANCH"
  echo "  Agent:      $RESOLVED_AGENT ($MODEL)"
  echo "  Short ID:   #$SHORT_ID"
  echo "  Auto-merge: $AUTO_MERGE"
  echo "  Quick:      $QUICK"
  echo ""
  echo "Would execute:"
  echo "  1. Scope task"
  echo "  2. Create worktree + spawn agent"
  if $QUICK; then
    echo "  3. Auto-merge on CI pass (skip review)"
  else
    echo "  3. Wait for PR → review → merge"
  fi
  exit 0
fi

# ── Escalation check ──────────────────────────────────────────────────
# Quick mode: detect if task looks too complex for a patch
if $QUICK; then
  WORD_COUNT=$(echo "$TASK" | wc -w | tr -d ' ')
  if [[ "$WORD_COUNT" -gt 20 ]]; then
    log_warn "This task description is long for --quick mode."
    echo "  Tip: This looks bigger than a patch. Consider running as full sprint:"
    echo "        clawforge sprint $(printf '%q' "$TASK")"
  fi
fi

# ── Step 1: Scope ─────────────────────────────────────────────────────
log_info "Step 1: Scoping task..."
PROMPT=$("${SCRIPT_DIR}/scope-task.sh" --task "$TASK" 2>/dev/null || echo "$TASK")

# ── Step 2: Spawn ─────────────────────────────────────────────────────
log_info "Step 2: Spawning agent..."
SPAWN_ARGS=(--repo "$REPO_ABS" --branch "$BRANCH" --task "$PROMPT")
[[ -n "${AGENT:-}" ]] && SPAWN_ARGS+=(--agent "$AGENT")
[[ -n "${MODEL:-}" ]] && SPAWN_ARGS+=(--model "$MODEL")

TASK_JSON=$("${SCRIPT_DIR}/spawn-agent.sh" "${SPAWN_ARGS[@]}" 2>/dev/null || true)

# ── Step 3: Enhance registry with mode data ───────────────────────────
registry_update "$SAFE_BRANCH" "short_id" "$SHORT_ID"
registry_update "$SAFE_BRANCH" "mode" "\"$MODE\""
registry_update "$SAFE_BRANCH" "files_touched" '[]'
registry_update "$SAFE_BRANCH" "ci_retries" '0'
$AUTO_MERGE && registry_update "$SAFE_BRANCH" "auto_merge" 'true'
$QUICK && registry_update "$SAFE_BRANCH" "skip_review" 'true'

# ── Step 4: Notify ────────────────────────────────────────────────────
"${SCRIPT_DIR}/notify.sh" --type task-started --description "$TASK" --dry-run 2>/dev/null || true

# ── Output ────────────────────────────────────────────────────────────
echo ""
echo "  #${SHORT_ID}  ${MODE}  spawned  $(basename "$REPO_ABS")  \"$(echo "$TASK" | head -c 50)\""
echo ""
echo "  Agent running in tmux session: agent-${SAFE_BRANCH}"
echo "  Attach: clawforge attach $SHORT_ID"
echo "  Steer:  clawforge steer $SHORT_ID \"<message>\""
echo "  Status: clawforge status"
echo ""
echo "  Tip: Run 'clawforge watch --daemon' in another pane for auto-monitoring"
