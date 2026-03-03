#!/usr/bin/env bash
# logs.sh — Capture and display agent output from tmux pane
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge logs <id> [options]

Capture output from a running agent's tmux session without attaching.

Arguments:
  <id>                 Task ID or short ID (e.g., 1 or sprint-add-jwt)

Options:
  --lines <N>          Number of lines to capture (default: 50)
  --follow             Stream output continuously (Ctrl+C to stop)
  --raw                Don't strip ANSI escape codes
  --save <path>        Save output to file
  --help               Show this help

Examples:
  clawforge logs 1
  clawforge logs 1 --lines 100
  clawforge logs 1 --follow
  clawforge logs sprint-jwt --save /tmp/agent-output.log
EOF
}

TASK_REF="" LINES=50 FOLLOW=false RAW=false SAVE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lines)    LINES="$2"; shift 2 ;;
    --follow)   FOLLOW=true; shift ;;
    --raw)      RAW=true; shift ;;
    --save)     SAVE_PATH="$2"; shift 2 ;;
    --help|-h)  usage; exit 0 ;;
    --*)        log_error "Unknown option: $1"; usage; exit 1 ;;
    *)          TASK_REF="$1"; shift ;;
  esac
done

[[ -z "$TASK_REF" ]] && { log_error "Task ID required"; usage; exit 1; }

# Resolve task: try short ID first, then full ID
_ensure_registry
TASK_DATA=""
if [[ "$TASK_REF" =~ ^[0-9]+$ ]]; then
  TASK_DATA=$(jq -r --argjson sid "$TASK_REF" '.tasks[] | select(.short_id == $sid)' "$REGISTRY_FILE" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  TASK_DATA=$(registry_get "$TASK_REF" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  log_error "Task '$TASK_REF' not found in registry"
  exit 1
fi

TMUX_SESSION=$(echo "$TASK_DATA" | jq -r '.tmuxSession // empty')
TASK_ID=$(echo "$TASK_DATA" | jq -r '.id')

if [[ -z "$TMUX_SESSION" ]]; then
  TMUX_SESSION="agent-${TASK_ID}"
fi

# Check tmux session exists
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  log_error "tmux session '$TMUX_SESSION' not found (agent may have exited)"
  echo "Tip: Use 'clawforge history' to see completed task records."
  exit 1
fi

# Capture function
capture_output() {
  local output
  output=$(tmux capture-pane -t "$TMUX_SESSION" -p -S "-${LINES}" 2>/dev/null || true)
  if [[ -z "$output" ]]; then
    echo "(no output captured)"
    return
  fi
  if ! $RAW; then
    # Strip ANSI escape codes
    output=$(printf '%s' "$output" | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g')
  fi
  echo "$output"
}

# Follow mode
if $FOLLOW; then
  echo "Following output from agent #${TASK_REF} (${TMUX_SESSION}). Ctrl+C to stop."
  echo "────────────────────────────────────────"
  LAST_HASH=""
  while true; do
    OUTPUT=$(capture_output)
    HASH=$(printf '%s' "$OUTPUT" | md5 2>/dev/null || printf '%s' "$OUTPUT" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "x")
    if [[ "$HASH" != "$LAST_HASH" ]]; then
      clear 2>/dev/null || true
      echo "Following agent #${TASK_REF} (${TMUX_SESSION}) — $(date +%H:%M:%S)"
      echo "────────────────────────────────────────"
      echo "$OUTPUT"
      LAST_HASH="$HASH"
    fi
    sleep 1
    # Stop if session dies
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      echo ""
      echo "── Session ended ──"
      break
    fi
  done
  exit 0
fi

# One-shot capture
OUTPUT=$(capture_output)

if [[ -n "$SAVE_PATH" ]]; then
  echo "$OUTPUT" > "$SAVE_PATH"
  echo "Saved ${LINES} lines to $SAVE_PATH"
else
  echo "── Agent #${TASK_REF} (${TMUX_SESSION}) ──"
  echo "$OUTPUT"
fi
