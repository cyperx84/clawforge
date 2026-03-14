#!/usr/bin/env bash
# fleet-list.sh — Fleet overview table
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge list [options]

Show fleet overview with all configured agents.

Options:
  --verbose    Show fallbacks, heartbeat, subagent permissions
  --json       Machine-readable JSON output
  --help       Show this help

Status indicators:
  ● active       Config + workspace + binding
  ○ created      Workspace exists, not bound/activated
  ◌ config-only  In config but no workspace
EOF
}

VERBOSE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    --json)       JSON_OUTPUT=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)            log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

_require_jq

# ── Gather data ────────────────────────────────────────────────────────
agents=$(_list_agents 2>/dev/null) || agents="[]"
agent_count=$(echo "$agents" | jq 'length')

if [[ "$agent_count" -eq 0 ]]; then
  if $JSON_OUTPUT; then
    echo '{"agents": [], "count": 0}'
  else
    echo "No agents configured."
    echo "Run 'clawforge create <id>' to forge your first agent."
  fi
  exit 0
fi

# Build enriched agent list
config=$(_read_openclaw_config)
bindings=$(echo "$config" | jq '.bindings // []')

enriched="[]"
for i in $(seq 0 $((agent_count - 1))); do
  agent=$(echo "$agents" | jq ".[$i]")
  agent_id=$(echo "$agent" | jq -r '.id')
  agent_name=$(echo "$agent" | jq -r '.name // .id')
  model_primary=$(_get_model_primary "$agent")
  model_display=$(_resolve_model_display "$model_primary")

  # Get binding/channel info
  binding=$(echo "$bindings" | jq --arg id "$agent_id" '[.[] | select(.agentId == $id)] | first // empty')
  channel_display="—"
  if [[ -n "$binding" && "$binding" != "null" ]]; then
    channel_id=$(echo "$binding" | jq -r '.match.peer.id // empty')
    channel_kind=$(echo "$binding" | jq -r '.match.channel // empty')
    if [[ -n "$channel_id" ]]; then
      channel_display="#${channel_kind}:${channel_id: -4}"
    fi
  fi

  # Determine status
  status=$(_validate_agent "$agent_id")
  status_icon=$(_status_icon "$status")

  # Verbose fields
  fallbacks=$(_get_model_fallbacks "$agent")
  subagent_allow=$(echo "$agent" | jq -r '.subagents.allowAgents // [] | join(", ")')
  heartbeat_info=""
  workspace=$(_get_workspace "$agent_id")
  if [[ -f "${workspace}/HEARTBEAT.md" ]]; then
    hb_content=$(cat "${workspace}/HEARTBEAT.md" 2>/dev/null || true)
    if echo "$hb_content" | grep -q '^- '; then
      heartbeat_info="configured"
    else
      heartbeat_info="empty"
    fi
  else
    heartbeat_info="none"
  fi

  entry=$(jq -n \
    --arg id "$agent_id" \
    --arg name "$agent_name" \
    --arg model "$model_display" \
    --arg model_full "$model_primary" \
    --arg channel "$channel_display" \
    --arg status "$status" \
    --arg icon "$status_icon" \
    --argjson fallbacks "$fallbacks" \
    --arg subagents "$subagent_allow" \
    --arg heartbeat "$heartbeat_info" \
    '{id: $id, name: $name, model: $model, model_full: $model_full, channel: $channel, status: $status, icon: $icon, fallbacks: $fallbacks, subagents: $subagents, heartbeat: $heartbeat}')

  enriched=$(echo "$enriched" | jq --argjson e "$entry" '. + [$e]')
done

# ── Output ─────────────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  echo "$enriched" | jq '{agents: ., count: length}'
  exit 0
fi

echo ""
echo "🔨 ClawForge Fleet — ${agent_count} agents"
echo ""

# Table header
if $VERBOSE; then
  printf " %-12s %-12s %-22s %-16s %-12s %-10s\n" "ID" "Name" "Model" "Channel" "Status" "Heartbeat"
  printf " %s\n" "────────────────────────────────────────────────────────────────────────────────────────"
else
  printf " %-12s %-12s %-22s %-16s %s\n" "ID" "Name" "Model" "Channel" "Status"
  printf " %s\n" "────────────────────────────────────────────────────────────────────────"
fi

# Table rows
echo "$enriched" | jq -c '.[]' | while IFS= read -r row; do
  id=$(echo "$row" | jq -r '.id')
  name=$(echo "$row" | jq -r '.name')
  model=$(echo "$row" | jq -r '.model')
  channel=$(echo "$row" | jq -r '.channel')
  status=$(echo "$row" | jq -r '.status')
  icon=$(echo "$row" | jq -r '.icon')
  heartbeat=$(echo "$row" | jq -r '.heartbeat')

  if $VERBOSE; then
    printf " %-12s %-12s %-22s %-16s %s %-8s  %-10s\n" "$id" "$name" "$model" "$channel" "$icon" "$status" "$heartbeat"
    # Show fallbacks and subagents on next line
    fallbacks=$(echo "$row" | jq -r '.fallbacks | if length > 0 then "fallbacks: " + (map(split("/") | last) | join(", ")) else "" end')
    subagents=$(echo "$row" | jq -r '.subagents')
    extras=""
    [[ -n "$fallbacks" ]] && extras="${fallbacks}"
    [[ -n "$subagents" ]] && extras="${extras:+$extras | }spawns: ${subagents}"
    [[ -n "$extras" ]] && printf " %12s %s\n" "" "$extras"
  else
    printf " %-12s %-12s %-22s %-16s %s %s\n" "$id" "$name" "$model" "$channel" "$icon" "$status"
  fi
done

echo ""
echo " ● = active  ○ = created  ◌ = config-only"
