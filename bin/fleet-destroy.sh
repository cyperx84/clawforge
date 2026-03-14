#!/usr/bin/env bash
# fleet-destroy.sh — Full removal of agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

usage() {
  cat <<EOF
Usage: clawforge destroy <id> --yes [options]

Full removal of agent: config cleanup + workspace deletion.

Arguments:
  <id>          Agent ID to destroy

Required:
  --yes         Explicit confirmation (no interactive prompt)

Options:
  --dry-run     Show what would happen without making changes
  --help        Show this help

Notes:
  - Requires explicit --yes flag for safety
  - Deactivates from config first
  - Moves workspace to trash (uses 'trash' CLI if available, else rm -rf)
  - Refuses to destroy 'main' agent
EOF
}

# Parse arguments
AGENT_ID=""
CONFIRMED=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)      CONFIRMED=true; shift ;;
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

# Require --yes
if ! $CONFIRMED && ! $DRY_RUN; then
  log_error "Destruction requires explicit --yes flag"
  echo ""
  echo "Usage: clawforge destroy $AGENT_ID --yes"
  exit 1
fi

# Refuse to destroy main
if [[ "$AGENT_ID" == "main" ]]; then
  log_error "Cannot destroy 'main' agent"
  exit 1
fi

# Validate agent exists
if ! _agent_exists_in_config "$AGENT_ID"; then
  log_error "Agent '$AGENT_ID' not found in config"
  exit 1
fi

# Get workspace path before deactivation
WORKSPACE=$(_get_workspace "$AGENT_ID")

if $DRY_RUN; then
  echo "[DRY-RUN] Would destroy agent '$AGENT_ID':"
  echo ""
  echo "  1. Deactivate from config"
  echo "  2. Move workspace to trash: $WORKSPACE"
  if command -v trash &>/dev/null; then
    echo "     (using 'trash' CLI)"
  else
    echo "     (using rm -rf with warning)"
  fi
  exit 0
fi

# Deactivate from config (reuse deactivate logic)
log_info "Deactivating agent from config..."
CONFIG=$(_read_openclaw_config) || exit 1

# Remove from agents.list
NEW_CONFIG=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '.agents.list = [.agents.list[] | select(.id != $id)]')

# Remove bindings
BINDING_COUNT=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '[.bindings[]? | select(.agentId == $id)] | length')
if [[ "$BINDING_COUNT" -gt 0 ]]; then
  log_info "Removing $BINDING_COUNT binding(s)..."
  NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg id "$AGENT_ID" \
    '.bindings = [.bindings[]? | select(.agentId != $id)]')
fi

# Remove from other agents' subagents.allowAgents
ALLOWAGENTS_COUNT=$(echo "$CONFIG" | jq --arg id "$AGENT_ID" \
  '[.agents.list[]? | select(.subagents.allowAgents[]? == $id)] | length')
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

_write_openclaw_config "$NEW_CONFIG"
log_info "✓ Removed from config"

# Delete workspace
if [[ -d "$WORKSPACE" ]]; then
  log_info "Removing workspace: $WORKSPACE"
  
  if command -v trash &>/dev/null; then
    trash "$WORKSPACE"
    log_info "✓ Moved to trash (recoverable)"
  else
    log_warn "'trash' CLI not found, using rm -rf (not recoverable)"
    rm -rf "$WORKSPACE"
    log_info "✓ Removed workspace"
  fi
else
  log_warn "Workspace directory not found: $WORKSPACE"
fi

log_info "✓ Destroyed agent '$AGENT_ID'"
