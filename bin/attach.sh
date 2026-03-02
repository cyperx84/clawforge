#!/usr/bin/env bash
# attach.sh — Attach to a running agent's tmux session
# Usage: clawforge attach <id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge attach <id>

Attach to a running agent's tmux session.

Arguments:
  <id>    Task short ID (#1), full ID, or sub-agent ID (3.2)

For swarm tasks, use the parent ID to see a picker for which agent session.

Examples:
  clawforge attach 1
  clawforge attach 3.2
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
  VERSION_FILE="${SCRIPT_DIR}/../VERSION"
  if [[ -f "$VERSION_FILE" ]]; then
    cat "$VERSION_FILE"
  else
    echo "Version file not found"
    exit 1
  fi
  exit 0
fi

if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  usage
  [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && exit 0 || exit 1
fi

TASK_REF="$1"

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

MODE=$(echo "$TASK" | jq -r '.mode // ""')
TMUX_SESSION=$(echo "$TASK" | jq -r '.tmuxSession')

# ── Swarm parent: show picker ─────────────────────────────────────────
if [[ "$MODE" == "swarm" ]] && [[ -z "$TMUX_SESSION" || "$TMUX_SESSION" == "" ]]; then
  # This is a swarm parent — find sub-agents
  SUB_TASKS=$(jq --arg pid "$TASK_ID" '[.tasks[] | select(.parent_id == $pid)]' "$REGISTRY_FILE" 2>/dev/null || echo "[]")
  SUB_COUNT=$(echo "$SUB_TASKS" | jq 'length')

  if [[ "$SUB_COUNT" == "0" ]]; then
    log_error "No sub-agents found for swarm task $TASK_REF"
    exit 1
  fi

  echo "Swarm task #$(echo "$TASK" | jq -r '.short_id') — select agent to attach:"
  echo ""
  echo "$SUB_TASKS" | jq -r '.[] | "  \(.sub_index). [\(.status)] \(.description // .id)[0:50] (tmux: \(.tmuxSession))"'
  echo ""

  # Use fzf if available, otherwise prompt
  if command -v fzf &>/dev/null; then
    SELECTION=$(echo "$SUB_TASKS" | jq -r '.[].sub_index' | fzf --prompt="Select agent: ")
  else
    echo -n "Enter agent number: "
    read -r SELECTION
  fi

  if [[ -z "$SELECTION" ]]; then
    echo "Cancelled."
    exit 0
  fi

  TMUX_SESSION=$(echo "$SUB_TASKS" | jq -r --argjson idx "$SELECTION" '.[] | select(.sub_index == $idx) | .tmuxSession')
fi

# ── Validate tmux session ─────────────────────────────────────────────
if [[ -z "$TMUX_SESSION" ]]; then
  log_error "No tmux session for task $TASK_REF"
  exit 1
fi

if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  log_error "tmux session not found: $TMUX_SESSION"
  echo "  The agent may have finished or crashed."
  echo "  Use 'clawforge status' to check."
  exit 1
fi

# ── Attach ────────────────────────────────────────────────────────────
echo "Attaching to: $TMUX_SESSION"
exec tmux attach -t "$TMUX_SESSION"
