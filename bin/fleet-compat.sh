#!/usr/bin/env bash
# fleet-compat.sh — Fleet-wide compatibility check (clwatch-powered)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"
source "${SCRIPT_DIR}/../lib/clwatch-bridge.sh"

usage() {
  cat <<EOF
Usage: clawforge compat [id] [options]

Check fleet-wide model/tool compatibility via clwatch.

Arguments:
  <id>          Agent ID (optional, checks all agents if not specified)

Options:
  --json        Output as JSON
  --help        Show this help

Notes:
  - Requires clwatch to be installed
  - Shows compatibility with coding harnesses (claude-code, codex, etc.)
  - Reports deprecations affecting agent models
  - Graceful exit if clwatch not available
EOF
}

# Parse arguments
AGENT_ID=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     JSON_OUTPUT=true; shift ;;
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

# Check clwatch availability
if ! _has_clwatch; then
  echo "Install clwatch for compatibility checking"
  echo ""
  echo "clwatch provides model/tool compatibility data and deprecation warnings."
  echo "Install with: brew install clwatch"
  exit 0
fi

# Get agents to check
if [[ -n "$AGENT_ID" ]]; then
  # Single agent
  if ! _agent_exists_in_config "$AGENT_ID"; then
    log_error "Agent '$AGENT_ID' not found in config"
    exit 1
  fi
  AGENTS_JSON=$(_get_agent "$AGENT_ID")
else
  # All agents
  AGENTS_JSON=$(_list_agents)
fi

# Build compatibility report
COMPAT_REPORT=$(
  echo "$AGENTS_JSON" | jq -c '.[]?' 2>/dev/null | while IFS= read -r agent; do
    [[ -z "$agent" ]] && continue
    
    AGENT_ID=$(echo "$agent" | jq -r '.id')
    MODEL=$(_get_model_primary "$agent")
    MODEL_DISPLAY=$(_resolve_model_display "$MODEL")
    
    # Get compatibility info
    COMPAT=$(_get_model_compat_display "$MODEL")
    DEPRECATIONS=$(_get_deprecation_display "$MODEL")
    
    # Output as JSON line
    jq -n \
      --arg id "$AGENT_ID" \
      --arg model "$MODEL_DISPLAY" \
      --arg compat "$COMPAT" \
      --arg deps "$DEPRECATIONS" \
      '{agent: $id, model: $model, compat: $compat, deprecations: $deps}'
  done | jq -s '.'
)

# Output
if $JSON_OUTPUT; then
  echo "$COMPAT_REPORT" | jq '.'
else
  echo "Fleet Compatibility Report"
  echo "────────────────────────────────────"
  echo ""
  
  # Table header
  printf "%-12s %-20s %-30s %s\n" "Agent" "Model" "Harness Compat" "Deprecations"
  echo "───────────────────────────────────────────────────────────────────────"
  
  # Table rows
  echo "$COMPAT_REPORT" | jq -r '.[] | 
    def pad(len): . + (" " * (len - (. | length)));
    "\(.agent | pad(12)) \(.model | pad(20)) \(.compat | pad(30)) \(.deprecations)"'
  
  echo ""
  
  # Check for any deprecations
  DEP_COUNT=$(echo "$COMPAT_REPORT" | jq '[.[] | select(.deprecations != "none")] | length')
  if [[ "$DEP_COUNT" -gt 0 ]]; then
    log_warn "$DEP_COUNT agent(s) have deprecation warnings"
    echo "Run 'clawforge upgrade-check' for details"
  else
    log_info "All agents compatible. No deprecations found."
  fi
fi
