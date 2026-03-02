#!/usr/bin/env bash
# steer.sh — Send course correction to a running agent
# Usage: clawforge steer <id> "<message>"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge steer <id> "<message>"

Send a course correction to a running agent via tmux.

Arguments:
  <id>          Task short ID (#1), full ID, or sub-agent ID (3.2)
  "<message>"   Course correction message

Examples:
  clawforge steer 1 "Use bcrypt instead of md5 for password hashing"
  clawforge steer 3.2 "Skip the legacy migration files"
  clawforge steer myapp-auth "Add rate limiting too"
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  usage
  [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && exit 0 || exit 1
fi

TASK_REF="$1"
shift

MESSAGE="${*:-}"
if [[ -z "$MESSAGE" ]]; then
  log_error "Message is required"
  usage
  exit 1
fi

# ── Resolve task ──────────────────────────────────────────────────────
TASK_ID=$(resolve_task_id "$TASK_REF")
if [[ -z "$TASK_ID" ]]; then
  log_error "Could not resolve task: $TASK_REF"
  exit 1
fi

TASK=$(registry_get "$TASK_ID")
if [[ -z "$TASK" ]]; then
  log_error "Task not found: $TASK_ID"
  exit 1
fi

STATUS=$(echo "$TASK" | jq -r '.status')
TMUX_SESSION=$(echo "$TASK" | jq -r '.tmuxSession')
DESCRIPTION=$(echo "$TASK" | jq -r '.description' | head -c 50)

# ── Check task state ──────────────────────────────────────────────────
case "$STATUS" in
  done|archived)
    log_warn "Task $TASK_REF is already $STATUS."
    echo "  Tip: Run 'clawforge review --pr <num>' instead."
    exit 0
    ;;
  failed)
    log_warn "Task $TASK_REF has failed. Consider restarting it."
    exit 1
    ;;
  stopped)
    log_warn "Task $TASK_REF is stopped. Start it first."
    exit 1
    ;;
esac

# ── Check tmux session ────────────────────────────────────────────────
if [[ -z "$TMUX_SESSION" ]] || ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  log_error "tmux session not found: ${TMUX_SESSION:-none}"
  echo "  The agent may have finished or crashed."
  echo "  Use 'clawforge status' to check."
  exit 1
fi

# ── Send message ──────────────────────────────────────────────────────
# For long messages (>200 chars), use tmux load-buffer to avoid truncation
if [[ ${#MESSAGE} -gt 200 ]]; then
  TMPFILE=$(mktemp)
  echo "$MESSAGE" > "$TMPFILE"
  tmux load-buffer "$TMPFILE"
  tmux paste-buffer -t "$TMUX_SESSION"
  tmux send-keys -t "$TMUX_SESSION" Enter
  rm -f "$TMPFILE"
else
  tmux send-keys -t "$TMUX_SESSION" "$MESSAGE" Enter
fi

# ── Log steer event in registry ───────────────────────────────────────
NOW=$(epoch_ms)
STEER_LOG=$(registry_get "$TASK_ID" | jq -r '.steer_log // "[]"')
STEER_ENTRY=$(jq -n --argjson ts "$NOW" --arg msg "$MESSAGE" '{timestamp: $ts, message: $msg}')
NEW_LOG=$(echo "$STEER_LOG" | jq --argjson entry "$STEER_ENTRY" '. += [$entry]')
registry_update "$TASK_ID" "steer_log" "$NEW_LOG" 2>/dev/null || true

log_info "Steered task $TASK_REF ($DESCRIPTION): $(echo "$MESSAGE" | head -c 60)..."
echo "  Sent to: $TMUX_SESSION"
echo "  Attach:  clawforge attach $TASK_REF"
