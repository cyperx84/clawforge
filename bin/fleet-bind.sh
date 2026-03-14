#!/usr/bin/env bash
# fleet-bind.sh — Wire agent to Discord channel
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

usage() {
  cat <<EOF
Usage: clawforge bind <id> <channel-id>
       clawforge unbind <id>

Wire agent to a Discord channel (adds binding to openclaw.json).

Arguments:
  <id>          Agent ID to bind/unbind
  <channel-id>  Discord channel ID (numeric) or channel name (e.g., #builder)

Options:
  --dry-run     Show what would happen without making changes
  --help        Show this help

Examples:
  clawforge bind scout 1476857455727345818
  clawforge bind scout "#scout"
  clawforge unbind scout
EOF
}

# Parse arguments
COMMAND=""
AGENT_ID=""
CHANNEL_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)   usage; exit 0 ;;
    -*)
      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$COMMAND" ]]; then
        COMMAND="$1"
      elif [[ -z "$AGENT_ID" ]]; then
        AGENT_ID="$1"
      elif [[ -z "$CHANNEL_ID" ]]; then
        CHANNEL_ID="$1"
      else
        log_error "Unexpected argument: $1"; usage; exit 1
      fi
      shift ;;
  esac
done

# Validate command
if [[ -z "$COMMAND" ]]; then
  log_error "Command required (bind or unbind)"
  usage; exit 1
fi

if [[ "$COMMAND" != "bind" && "$COMMAND" != "unbind" ]]; then
  log_error "Invalid command: $COMMAND (must be 'bind' or 'unbind')"
  usage; exit 1
fi

# Validate agent ID
if [[ -z "$AGENT_ID" ]]; then
  log_error "Agent ID required"
  usage; exit 1
fi

# Validate agent exists
if ! _agent_exists_in_config "$AGENT_ID"; then
  log_error "Agent '$AGENT_ID' not found in config"
  exit 1
fi

# For bind, validate channel ID
if [[ "$COMMAND" == "bind" ]]; then
  if [[ -z "$CHANNEL_ID" ]]; then
    log_error "Channel ID required for bind"
    usage; exit 1
  fi

  # Normalize channel ID (strip # if present, could be channel name)
  CHANNEL_ID="${CHANNEL_ID#\#}"
fi

# Read current config
CONFIG=$(_read_openclaw_config) || exit 1

if [[ "$COMMAND" == "bind" ]]; then
  # Check if binding already exists
  EXISTING=$(echo "$CONFIG" | jq --arg aid "$AGENT_ID" --arg cid "$CHANNEL_ID" \
    '.bindings[]? | select(.agentId == $aid and .channelId == $cid)' 2>/dev/null || true)

  if [[ -n "$EXISTING" ]]; then
    log_warn "Binding already exists for agent '$AGENT_ID' to channel '$CHANNEL_ID'"
    exit 0
  fi

  # Add binding
  if $DRY_RUN; then
    echo "[DRY-RUN] Would add binding:"
    echo "  Agent: $AGENT_ID"
    echo "  Channel: $CHANNEL_ID"
  else
    NEW_BINDING=$(jq -n \
      --arg aid "$AGENT_ID" \
      --arg cid "$CHANNEL_ID" \
      '{"agentId": $aid, "channelId": $cid}')

    NEW_CONFIG=$(echo "$CONFIG" | jq --argjson binding "$NEW_BINDING" \
      '.bindings = (.bindings // []) + [$binding]')

    _write_openclaw_config "$NEW_CONFIG"
    log_info "✓ Bound agent '$AGENT_ID' to channel '$CHANNEL_ID'"
    echo ""
    echo "Run 'clawforge apply' to activate changes and restart gateway."
  fi

elif [[ "$COMMAND" == "unbind" ]]; then
  # Check if binding exists
  EXISTING_BINDINGS=$(echo "$CONFIG" | jq --arg aid "$AGENT_ID" \
    '[.bindings[]? | select(.agentId == $aid)]' 2>/dev/null || echo "[]")
  BINDING_COUNT=$(echo "$EXISTING_BINDINGS" | jq 'length')

  if [[ "$BINDING_COUNT" -eq 0 ]]; then
    log_warn "No bindings found for agent '$AGENT_ID'"
    exit 0
  fi

  if $DRY_RUN; then
    echo "[DRY-RUN] Would remove $BINDING_COUNT binding(s) for agent '$AGENT_ID':"
    echo "$EXISTING_BINDINGS" | jq -r '.[] | "  Channel: \(.channelId)"'
  else
    # Remove all bindings for this agent
    NEW_CONFIG=$(echo "$CONFIG" | jq --arg aid "$AGENT_ID" \
      '.bindings = [.bindings[]? | select(.agentId != $aid)]')

    _write_openclaw_config "$NEW_CONFIG"
    log_info "✓ Removed $BINDING_COUNT binding(s) for agent '$AGENT_ID'"
    echo ""
    echo "Run 'clawforge apply' to activate changes and restart gateway."
  fi
fi
