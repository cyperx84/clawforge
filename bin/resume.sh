#!/usr/bin/env bash
# resume.sh — Resume a failed/timeout/cancelled agent from where it left off
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge resume <id> [options]

Resume a failed/timeout/cancelled task. Reuses the same worktree and branch,
spawns a fresh tmux session, and injects last N lines of output as context.

Arguments:
  <id>                 Task ID or short ID

Options:
  --context-lines <N>  Lines of previous output to inject (default: 30)
  --agent <name>       Override agent (claude/codex)
  --model <model>      Override model
  --message <msg>      Additional instructions for the resumed agent
  --dry-run            Show what would happen
  --help               Show this help

Examples:
  clawforge resume 1
  clawforge resume 1 --message "Focus on fixing the test failures"
  clawforge resume sprint-jwt --agent codex
EOF
}

TASK_REF="" CONTEXT_LINES=30 AGENT_OVERRIDE="" MODEL_OVERRIDE="" MESSAGE="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-lines) CONTEXT_LINES="$2"; shift 2 ;;
    --agent)         AGENT_OVERRIDE="$2"; shift 2 ;;
    --model)         MODEL_OVERRIDE="$2"; shift 2 ;;
    --message)       MESSAGE="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --help|-h)       usage; exit 0 ;;
    --*)             log_error "Unknown option: $1"; usage; exit 1 ;;
    *)               TASK_REF="$1"; shift ;;
  esac
done

[[ -z "$TASK_REF" ]] && { log_error "Task ID required"; usage; exit 1; }

_ensure_registry

# Resolve task
TASK_DATA=""
if [[ "$TASK_REF" =~ ^[0-9]+$ ]]; then
  TASK_DATA=$(jq -r --argjson sid "$TASK_REF" '.tasks[] | select(.short_id == $sid)' "$REGISTRY_FILE" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  TASK_DATA=$(registry_get "$TASK_REF" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  log_error "Task '$TASK_REF' not found"
  exit 1
fi

TASK_ID=$(echo "$TASK_DATA" | jq -r '.id')
STATUS=$(echo "$TASK_DATA" | jq -r '.status')
DESC=$(echo "$TASK_DATA" | jq -r '.description')
WORKTREE=$(echo "$TASK_DATA" | jq -r '.worktree // empty')
BRANCH=$(echo "$TASK_DATA" | jq -r '.branch // empty')
REPO=$(echo "$TASK_DATA" | jq -r '.repo // empty')
AGENT=$(echo "$TASK_DATA" | jq -r '.agent // "claude"')
MODEL=$(echo "$TASK_DATA" | jq -r '.model // "claude-sonnet-4-5"')
TMUX_SESSION=$(echo "$TASK_DATA" | jq -r '.tmuxSession // empty')
SHORT_ID=$(echo "$TASK_DATA" | jq -r '.short_id // 0')

# Validate status is resumable
case "$STATUS" in
  failed|timeout|cancelled) ;;
  running|spawned)
    log_error "Task #${SHORT_ID} is still $STATUS. Use 'steer' instead."
    exit 1 ;;
  done)
    log_error "Task #${SHORT_ID} is already done."
    exit 1 ;;
  *)
    log_error "Task #${SHORT_ID} has status '$STATUS' — not resumable."
    exit 1 ;;
esac

# Apply overrides
[[ -n "$AGENT_OVERRIDE" ]] && AGENT="$AGENT_OVERRIDE"
[[ -n "$MODEL_OVERRIDE" ]] && MODEL="$MODEL_OVERRIDE"

# Check worktree still exists
if [[ -z "$WORKTREE" || ! -d "$WORKTREE" ]]; then
  log_error "Worktree not found: ${WORKTREE:-'(none)'}. Cannot resume — worktree was cleaned."
  echo "Tip: Re-run as a fresh sprint instead."
  exit 1
fi

# Kill old tmux session if lingering
if [[ -n "$TMUX_SESSION" ]]; then
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
fi
[[ -z "$TMUX_SESSION" ]] && TMUX_SESSION="agent-${TASK_ID}"

# Capture previous output for context
PREV_OUTPUT=""
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  PREV_OUTPUT=$(tmux capture-pane -t "$TMUX_SESSION" -p -S "-${CONTEXT_LINES}" 2>/dev/null || true)
fi

# Build resume prompt
RESUME_PROMPT="You are resuming a previously ${STATUS} task.

Original task: ${DESC}
Branch: ${BRANCH}
"

if [[ -n "$PREV_OUTPUT" ]]; then
  RESUME_PROMPT+="
Previous session output (last ${CONTEXT_LINES} lines):
\`\`\`
${PREV_OUTPUT}
\`\`\`
"
fi

if [[ -n "$MESSAGE" ]]; then
  RESUME_PROMPT+="
Additional instructions: ${MESSAGE}
"
fi

RESUME_PROMPT+="
Continue from where the previous agent left off. Check git status and recent changes first.

When complete:
1. Commit your changes with a descriptive message
2. Push the branch: git push origin ${BRANCH}
3. Create a PR: gh pr create --fill --base main"

# Dry run
if $DRY_RUN; then
  echo "=== Resume Dry Run ==="
  echo "  Task:       #${SHORT_ID} ($TASK_ID)"
  echo "  Status:     $STATUS → running"
  echo "  Worktree:   $WORKTREE"
  echo "  Branch:     $BRANCH"
  echo "  Agent:      $AGENT ($MODEL)"
  echo "  tmux:       $TMUX_SESSION"
  echo "  Context:    ${CONTEXT_LINES} lines"
  [[ -n "$MESSAGE" ]] && echo "  Message:    $MESSAGE"
  echo ""
  echo "Resume prompt preview:"
  echo "$RESUME_PROMPT" | head -20
  exit 0
fi

# Spawn fresh agent in existing worktree
log_info "Resuming #${SHORT_ID} in $WORKTREE..."

if [[ "$AGENT" == "claude" ]]; then
  AGENT_CMD="claude --model ${MODEL} --dangerously-skip-permissions -p \"$(echo "$RESUME_PROMPT" | sed 's/"/\\"/g')\""
else
  AGENT_CMD="codex --model ${MODEL} --dangerously-bypass-approvals-and-sandbox \"$(echo "$RESUME_PROMPT" | sed 's/"/\\"/g')\""
fi

tmux new-session -d -s "$TMUX_SESSION" -c "$WORKTREE" "$AGENT_CMD"

# Update registry
registry_update "$TASK_ID" "status" '"running"'
registry_update "$TASK_ID" "resumedAt" "$(epoch_ms)"
RETRIES=$(echo "$TASK_DATA" | jq -r '.retries // 0')
registry_update "$TASK_ID" "retries" "$((RETRIES + 1))"

echo ""
echo "  #${SHORT_ID}  resumed  $(basename "$REPO")  \"$(echo "$DESC" | head -c 50)\""
echo ""
echo "  Agent running in tmux: $TMUX_SESSION"
echo "  Attach: clawforge attach $SHORT_ID"
echo "  Steer:  clawforge steer $SHORT_ID \"<message>\""
echo "  Logs:   clawforge logs $SHORT_ID"
