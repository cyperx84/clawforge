#!/usr/bin/env bash
# fleet-upgrade-check.sh — Check what tools need updating
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"
source "${SCRIPT_DIR}/../lib/clwatch-bridge.sh"

usage() {
  cat <<EOF
Usage: clawforge upgrade-check [options]

Check for tool updates and map to affected agents.

Options:
  --json        Output as JSON
  --help        Show this help

Notes:
  - Uses clwatch to check for tool updates
  - Maps tool updates to affected agents
  - Shows which agents would benefit from upgrades
  - Graceful exit if clwatch not available
EOF
}

# Parse arguments
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     JSON_OUTPUT=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    -*)
      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      log_error "Unexpected argument: $1"; usage; exit 1
      shift ;;
  esac
done

# Check clwatch availability
if ! _has_clwatch; then
  echo "Install clwatch for upgrade checking"
  echo ""
  echo "clwatch tracks tool versions and provides update notifications."
  echo "Install with: brew install clwatch"
  exit 0
fi

# Get tool version info from clwatch
VERSIONS_JSON=$(_get_tool_versions)

# Check for updates
UPDATES=$(echo "$VERSIONS_JSON" | jq 'to_entries[] | select(.value.current != .value.latest) | {tool: .key, current: .value.current, latest: .value.latest}' 2>/dev/null || true)

if [[ -z "$UPDATES" ]]; then
  if $JSON_OUTPUT; then
    echo '{"updates": [], "message": "All tools current"}'
  else
    log_info "All tools are current"
  fi
  exit 0
fi

# Map tools to agents
# For now, we'll check which agents mention these tools in their config
# In practice, this would need a more sophisticated mapping

AGENTS_JSON=$(_list_agents)

# Build upgrade report
UPGRADE_REPORT=$(
  echo "$UPDATES" | jq -c '.' | while IFS= read -r update; do
    [[ -z "$update" ]] && continue
    
    TOOL=$(echo "$update" | jq -r '.tool')
    CURRENT=$(echo "$update" | jq -r '.current')
    LATEST=$(echo "$update" | jq -r '.latest')
    
    # Find agents that might be affected
    # This is a simple heuristic - in practice would need proper tool→agent mapping
    AFFECTED=$(
      echo "$AGENTS_JSON" | jq -r --arg tool "$TOOL" '
        [.[]? | select(
          .model | tostring | contains($tool) or
          .skills // [] | tostring | contains($tool)
        ) | .id] | join(", ")
      ' 2>/dev/null || echo ""
    )
    
    # Default affected if we can't determine
    if [[ -z "$AFFECTED" || "$AFFECTED" == "null" ]]; then
      case "$TOOL" in
        claude-code|codex-cli) AFFECTED="builder, main" ;;
        openclaw) AFFECTED="all agents" ;;
        *) AFFECTED="unknown" ;;
      esac
    fi
    
    # Output as JSON
    echo "$update" | jq --arg affected "$AFFECTED" '. + {affected_agents: $affected}'
  done | jq -s '.'
)

# Output
if $JSON_OUTPUT; then
  echo "{\"updates\": $(echo "$UPGRADE_REPORT" | jq '.'), \"message\": \"Updates available\"}"
else
  echo "Tool Upgrade Report"
  echo "────────────────────────────────────"
  echo ""
  
  # Show each update
  echo "$UPGRADE_REPORT" | jq -r '.[] |
    "⚠️  \(.tool) \(.current) → \(.latest) available\n   Affected: \(.affected_agents)\n   Run: brew upgrade \(.tool)"'
  
  echo ""
  
  UPDATE_COUNT=$(echo "$UPGRADE_REPORT" | jq 'length')
  log_warn "$UPDATE_COUNT tool(s) have updates available"
  echo ""
  echo "After upgrading, run 'clawforge apply' to restart agents with new versions."
fi
