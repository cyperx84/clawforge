#!/usr/bin/env bash
# fleet-logs.sh — View agent conversation logs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge logs <agent-id> [options]

View agent conversation logs.

Arguments:
  agent-id     Agent ID (required)

Options:
  --follow     Follow log output (tail -f style)
  --tail N     Show last N lines (default: 50)
  --json       Machine-readable JSON output
  --help       Show this help
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

JSON_OUTPUT=false
FOLLOW=false
TAIL_LINES=50
AGENT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --follow)     FOLLOW=true; shift ;;
    --tail)       TAIL_LINES="$2"; shift 2 ;;
    --json)       JSON_OUTPUT=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    -*)           log_error "Unknown option: $1"; usage; exit 1 ;;
    *)            AGENT_ID="$1"; shift ;;
  esac
done

if [[ -z "$AGENT_ID" ]]; then
  log_error "Agent ID is required"
  usage
  exit 1
fi

_require_jq

# ── Find agent logs ────────────────────────────────────────────────────
workspace=$(_get_workspace "$AGENT_ID" 2>/dev/null) || {
  log_error "Agent '$AGENT_ID' not found or no workspace"
  exit 1
}

# Try to find logs in OpenClaw session directory or agent workspace
log_search_paths=(
  "${OPENCLAW_AGENTS_DIR}/${AGENT_ID}/logs"
  "${workspace}/logs"
  "${workspace}/../${AGENT_ID}/logs"
)

log_file=""
for path in "${log_search_paths[@]}"; do
  if [[ -f "$path/session.log" ]]; then
    log_file="$path/session.log"
    break
  elif [[ -f "$path/conversation.log" ]]; then
    log_file="$path/conversation.log"
    break
  elif [[ -f "$path/agent.log" ]]; then
    log_file="$path/agent.log"
    break
  fi
done

# Fallback: look for .claude files or transcripts
if [[ -z "$log_file" ]]; then
  if [[ -f "${workspace}/.claude/transcript.txt" ]]; then
    log_file="${workspace}/.claude/transcript.txt"
  elif [[ -f "${workspace}/transcript.md" ]]; then
    log_file="${workspace}/transcript.md"
  elif [[ -d "${workspace}" ]]; then
    # No log file found, check if workspace has recent files
    log_file="${workspace}/activity.log"
  fi
fi

# ── Output logs ────────────────────────────────────────────────────────
if [[ ! -f "$log_file" ]]; then
  if $JSON_OUTPUT; then
    echo '{"agent": "'$AGENT_ID'", "logs": [], "error": "No logs found"}'
  else
    echo "No logs found for agent '$AGENT_ID'"
    echo "Looked in:"
    for path in "${log_search_paths[@]}"; do
      echo "  - $path/"
    done
  fi
  exit 0
fi

if $JSON_OUTPUT; then
  # Read log file and output as JSON
  logs=$(tail -n "$TAIL_LINES" "$log_file" | jq -R . | jq -s .)
  jq -n --arg agent "$AGENT_ID" --argjson logs "$logs" '{agent: $agent, logs: $logs}'
  exit 0
fi

if $FOLLOW; then
  tail -f "$log_file"
else
  tail -n "$TAIL_LINES" "$log_file"
fi
