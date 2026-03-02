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
  --template <name>    Apply a task template (overrides defaults, CLI flags override template)
  --ci-loop            Enable CI auto-fix feedback loop
  --max-ci-retries <N> Max CI auto-fix retries (default: 3)
  --budget <dollars>   Kill agent if cost exceeds budget
  --json               Output structured JSON
  --notify             Send OpenClaw event on completion
  --webhook <url>      POST completion payload to URL
  --dry-run            Preview what would happen
  --help               Show this help

Examples:
  clawforge sprint "Add JWT authentication middleware"
  clawforge sprint ~/github/api "Fix null pointer in UserService" --quick
  clawforge sprint "Add rate limiter" --branch feat/rate-limit --agent codex
  clawforge sprint --template refactor "Refactor auth module"
  clawforge sprint "Fix login bug" --ci-loop --budget 5.00
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
REPO="" TASK="" BRANCH="" AGENT="" MODEL="" QUICK=false AUTO_MERGE=false DRY_RUN=false
TEMPLATE="" CI_LOOP=false MAX_CI_RETRIES=3 BUDGET="" JSON_OUTPUT=false NOTIFY=false WEBHOOK=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)          QUICK=true; shift ;;
    --branch)         BRANCH="$2"; shift 2 ;;
    --agent)          AGENT="$2"; shift 2 ;;
    --model)          MODEL="$2"; shift 2 ;;
    --auto-merge)     AUTO_MERGE=true; shift ;;
    --template)       TEMPLATE="$2"; shift 2 ;;
    --ci-loop)        CI_LOOP=true; shift ;;
    --max-ci-retries) MAX_CI_RETRIES="$2"; shift 2 ;;
    --budget)         BUDGET="$2"; shift 2 ;;
    --json)           JSON_OUTPUT=true; shift ;;
    --notify)         NOTIFY=true; shift ;;
    --webhook)        WEBHOOK="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    --help|-h)        usage; exit 0 ;;
    --*)              log_error "Unknown option: $1"; usage; exit 1 ;;
    *)                POSITIONAL+=("$1"); shift ;;
  esac
done

# ── Apply template (template < CLI flags) ─────────────────────────────
if [[ -n "$TEMPLATE" ]]; then
  TMPL_FILE=""
  if [[ -f "${CLAWFORGE_DIR}/lib/templates/${TEMPLATE}.json" ]]; then
    TMPL_FILE="${CLAWFORGE_DIR}/lib/templates/${TEMPLATE}.json"
  elif [[ -f "${HOME}/.clawforge/templates/${TEMPLATE}.json" ]]; then
    TMPL_FILE="${HOME}/.clawforge/templates/${TEMPLATE}.json"
  else
    log_error "Template '$TEMPLATE' not found"; exit 1
  fi
  log_info "Applying template: $TEMPLATE"
  # Template sets defaults; CLI flags override
  TMPL_AUTO_MERGE=$(jq -r '.autoMerge // false' "$TMPL_FILE")
  TMPL_CI_LOOP=$(jq -r '.ciLoop // false' "$TMPL_FILE")
  TMPL_QUICK=$(jq -r '.quick // false' "$TMPL_FILE")
  # Only apply template values if CLI didn't set them explicitly
  [[ "$TMPL_AUTO_MERGE" == "true" ]] && AUTO_MERGE=true
  [[ "$TMPL_CI_LOOP" == "true" ]] && CI_LOOP=true
  [[ "$TMPL_QUICK" == "true" ]] && QUICK=true
fi

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
registry_update "$SAFE_BRANCH" "max_ci_retries" "$MAX_CI_RETRIES"
$AUTO_MERGE && registry_update "$SAFE_BRANCH" "auto_merge" 'true'
$QUICK && registry_update "$SAFE_BRANCH" "skip_review" 'true'
$CI_LOOP && registry_update "$SAFE_BRANCH" "ci_loop" 'true'
[[ -n "$BUDGET" ]] && registry_update "$SAFE_BRANCH" "budget" "$BUDGET"

# ── Step 4: Notify ────────────────────────────────────────────────────
"${SCRIPT_DIR}/notify.sh" --type task-started --description "$TASK" --dry-run 2>/dev/null || true

# ── OpenClaw notify ──────────────────────────────────────────────────
if $NOTIFY; then
  openclaw system event --text "ClawForge: sprint started — $TASK (#$SHORT_ID)" --mode now 2>/dev/null || true
fi

# ── Webhook ──────────────────────────────────────────────────────────
if [[ -n "$WEBHOOK" ]]; then
  local payload
  payload=$(jq -cn \
    --arg taskId "$SAFE_BRANCH" \
    --argjson shortId "$SHORT_ID" \
    --arg mode "$MODE" \
    --arg status "spawned" \
    --arg branch "$BRANCH" \
    --arg description "$TASK" \
    --arg repo "$REPO_ABS" \
    '{taskId: $taskId, shortId: $shortId, mode: $mode, status: $status, branch: $branch, description: $description, repo: $repo}')
  curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK" >/dev/null 2>&1 || log_warn "Webhook POST failed"
fi

# ── Output ────────────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  jq -cn \
    --arg taskId "$SAFE_BRANCH" \
    --argjson shortId "$SHORT_ID" \
    --arg mode "$MODE" \
    --arg status "spawned" \
    --arg branch "$BRANCH" \
    --arg description "$TASK" \
    --arg repo "$REPO_ABS" \
    --arg agent "$RESOLVED_AGENT" \
    --arg model "$MODEL" \
    --argjson autoMerge "$AUTO_MERGE" \
    --argjson ciLoop "$CI_LOOP" \
    '{taskId: $taskId, shortId: $shortId, mode: $mode, status: $status, branch: $branch, description: $description, repo: $repo, agent: $agent, model: $model, autoMerge: $autoMerge, ciLoop: $ciLoop}'
else
  echo ""
  echo "  #${SHORT_ID}  ${MODE}  spawned  $(basename "$REPO_ABS")  \"$(echo "$TASK" | head -c 50)\""
  echo ""
  echo "  Agent running in tmux session: agent-${SAFE_BRANCH}"
  echo "  Attach: clawforge attach $SHORT_ID"
  echo "  Steer:  clawforge steer $SHORT_ID \"<message>\""
  echo "  Status: clawforge status"
  echo ""
  $CI_LOOP && echo "  CI feedback loop: enabled (max retries: $MAX_CI_RETRIES)"
  [[ -n "$BUDGET" ]] && echo "  Budget cap: \$$BUDGET"
  echo "  Tip: Run 'clawforge watch --daemon' in another pane for auto-monitoring"
fi
