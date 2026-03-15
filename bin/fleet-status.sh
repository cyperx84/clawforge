#!/usr/bin/env bash
# fleet-status.sh — Fleet-aware status dashboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge status [agent-id] [options]

Show fleet status with agent details.

Arguments:
  agent-id     Show status for a single agent (optional)

Options:
  --json       Machine-readable JSON output
  --help       Show this help

Status indicators:
  ● active       Agent bound and active
  ○ created      Agent workspace exists
  ◌ config-only  Agent in config only
EOF
}

JSON_OUTPUT=false
TARGET_AGENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       JSON_OUTPUT=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    -*)           log_error "Unknown option: $1"; usage; exit 1 ;;
    *)            TARGET_AGENT="$1"; shift ;;
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
  fi
  exit 0
fi

# Build status list
config=$(_read_openclaw_config)
bindings=$(echo "$config" | jq '.bindings // []')

status_list="[]"
for i in $(seq 0 $((agent_count - 1))); do
  agent=$(echo "$agents" | jq ".[$i]")
  agent_id=$(echo "$agent" | jq -r '.id')

  # Skip if filtering by TARGET_AGENT
  if [[ -n "$TARGET_AGENT" && "$agent_id" != "$TARGET_AGENT" ]]; then
    continue
  fi

  agent_name=$(echo "$agent" | jq -r '.name // .id')
  model_primary=$(_get_model_primary "$agent")
  model_display=$(_resolve_model_display "$model_primary")

  # Get binding/channel info
  binding=$(echo "$bindings" | jq --arg id "$agent_id" '[.[] | select(.agentId == $id)] | first // empty')
  channel_display="—"
  if [[ -n "$binding" && "$binding" != "null" ]]; then
    channel_id=$(echo "$binding" | jq -r '.match.peer.id // empty')
    channel_kind=$(echo "$binding" | jq -r '.match.channel // empty')
    if [[ -n "$channel_id" && -n "$channel_kind" ]]; then
      channel_display="${channel_kind}/#${agent_id}"
    fi
  fi

  # Determine status
  status=$(_validate_agent "$agent_id")
  status_icon=$(_status_icon "$status")

  # Get workspace and memory info
  workspace=$(_get_workspace "$agent_id")
  memory_lines=0
  if [[ -d "${workspace}/memory" ]]; then
    memory_lines=$(find "${workspace}/memory" -type f | wc -l)
  fi

  # Get last activity (check agent logs if available)
  last_activity="—"
  if [[ -d "${workspace}" ]]; then
    # Look for most recent file modification
    if last_file=$(find "${workspace}" -type f -newermt "1 day ago" -ls 2>/dev/null | tail -1); then
      last_activity="active"
    fi
  fi

  entry=$(jq -n \
    --arg id "$agent_id" \
    --arg name "$agent_name" \
    --arg model "$model_display" \
    --arg channel "$channel_display" \
    --arg status "$status" \
    --arg icon "$status_icon" \
    --argjson memory "$memory_lines" \
    --arg activity "$last_activity" \
    '{id: $id, name: $name, model: $model, channel: $channel, status: $status, icon: $icon, memory: $memory, activity: $activity}')

  status_list=$(echo "$status_list" | jq --argjson e "$entry" '. + [$e]')
done

# ── Output ─────────────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  echo "$status_list" | jq '{agents: ., count: length}'
  exit 0
fi

result_count=$(echo "$status_list" | jq 'length')

if [[ "$result_count" -eq 0 ]]; then
  echo "No agents found."
  exit 0
fi

echo ""
if [[ -n "$TARGET_AGENT" ]]; then
  echo "Agent Status"
  printf " %-12s %-12s %-22s %-16s %-10s %-8s %-10s\n" "ID" "Name" "Model" "Channel" "Status" "Memory" "Activity"
else
  echo "🔨 ClawForge Fleet — $result_count agents"
  printf " %-12s %-12s %-22s %-16s %-10s %-8s %-10s\n" "ID" "Name" "Model" "Channel" "Status" "Memory" "Activity"
fi

printf " %s\n" "────────────────────────────────────────────────────────────────────────────────────────"

echo "$status_list" | jq -c '.[]' | while IFS= read -r row; do
  id=$(echo "$row" | jq -r '.id')
  name=$(echo "$row" | jq -r '.name')
  model=$(echo "$row" | jq -r '.model')
  channel=$(echo "$row" | jq -r '.channel')
  status=$(echo "$row" | jq -r '.status')
  icon=$(echo "$row" | jq -r '.icon')
  memory=$(echo "$row" | jq -r '.memory')
  activity=$(echo "$row" | jq -r '.activity')

  printf " %-12s %-12s %-22s %-16s %s %-8s %-10s\n" "$id" "$name" "$model" "$channel" "$icon $status" "$memory" "$activity"
done

echo ""
echo " ● = active  ○ = created  ◌ = config-only"
echo ""
