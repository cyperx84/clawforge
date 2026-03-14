#!/usr/bin/env bash
# fleet-deactivate.sh — Remove agent from config without deleting files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

usage() {
  cat <<EOF
Usage: clawforge deactivate <id> [options]

Remove agent from openclaw.json config without deleting workspace files.

Arguments:
  <id>          Agent ID to deactivate

Options:
  --dry-run     Show what would happen without making changes
  --help        Show this help

Notes:
  - Keeps workspace directory intact
  - Removes agent from agents.list[]
  - Removes any bindings for this agent
  - Removes from other agents' subagents.allowAgents
  - Refuses to deactivate 'main' agent
EOF
}

# Parse arguments
AGENT_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    -*)
      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$AGENT_ID" ]]; then
        AGENT_ID="$1"
      else
        log_error "Unexpected argument: $1"; usage; exit 1
      fi
      shift ;;
  esac
done

# Validate
if [[ -z "$AGENT_ID" ]]; then
  log_error "Agent ID required"
  usage; exit 1
fi

# Refuse to deactivate main
if [[ "$AGENT_ID" == "main" ]]; then
  log_error "Cannot deactivate 'main' agent"
  exit 1
fi

# Validate agent exists
if ! _agent_exists_in_config "$AGENT_ID"; then
  log_error "Agent '$AGENT_ID' not found in config"
  exit 1
fi

# Read current config
CONFIG=$(_read_openclaw_config) || exit 1

# Count what will be removed
AGENT_COUNT=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '[.agents.list[] | select(.id == $id)] | length')
BINDING_COUNT=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '[.bindings[]? | select(.agentId == $id)] | length')
ALLOWAGENTS_COUNT=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '[.agents.list[]? | select(.subagents.allowAgents[]? == $id)] | length')

if $DRY_RUN; then
  echo "[DRY-RUN] Would deactivate agent '$AGENT_ID':"
  echo ""
  echo "  Remove from agents.list: $AGENT_COUNT entry"
  echo "  Remove bindings:         $BINDING_COUNT binding(s)"
  echo "  Remove from allowAgents: $ALLOWAGENTS_COUNT agent(s)"
  echo ""
  echo "Workspace directory will be preserved."
  exit 0
fi

# Remove from agents.list
log_info "Removing agent from config..."
NEW_CONFIG=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '.agents.list = [.agents.list[] | select(.id != $id)]')

# Remove bindings
if [[ "$BINDING_COUNT" -gt 0 ]]; then
  log_info "Removing $BINDING_COUNT binding(s)..."
  NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg id "$AGENT_ID" \
    '.bindings = [.bindings[]? | select(.agentId != $id)]')
fi

# Remove from other agents' subagents.allowAgents
if [[ "$ALLOWAGENTS_COUNT" -gt 0 ]]; then
  log_info "Removing from $ALLOWAGENTS_COUNT agent(s) allowAgents lists..."
  NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg id "$AGENT_ID" '
    .agents.list = [.agents.list[] | 
      if .subagents.allowAgents then
        .subagents.allowAgents |= [.[] | select(. != $id)]
      else
        .
      end
    ]
  ')
fi

# Write updated config
_write_openclaw_config "$NEW_CONFIG"

log_info "✓ Deactivated agent '$AGENT_ID'"
echo ""
echo "Workspace preserved at: $(_get_workspace "$AGENT_ID")"
echo ""
echo "To fully remove including workspace files, run: clawforge destroy $AGENT_ID --yes"
echo "To reactivate, run: clawforge activate $AGENT_ID"
