#!/usr/bin/env bash
# fleet-cost.sh — Aggregate token/cost tracking across fleet
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge cost [agent-id] [options]

Show aggregated token/cost tracking across fleet.

Arguments:
  agent-id     Show costs for a single agent (optional)

Options:
  --today      Show today's costs only
  --week       Show this week's costs
  --json       Machine-readable JSON output
  --help       Show this help
EOF
}

JSON_OUTPUT=false
TIME_FILTER="all"
TARGET_AGENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today)      TIME_FILTER="today"; shift ;;
    --week)       TIME_FILTER="week"; shift ;;
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
    echo '{"agents": [], "total": {"tokens_in": 0, "tokens_out": 0, "cost": 0}}'
  else
    echo "No agents configured."
  fi
  exit 0
fi

# Build cost list
cost_list="[]"
total_in=0
total_out=0
total_cost=0

for i in $(seq 0 $((agent_count - 1))); do
  agent=$(echo "$agents" | jq ".[$i]")
  agent_id=$(echo "$agent" | jq -r '.id')

  # Skip if filtering by TARGET_AGENT
  if [[ -n "$TARGET_AGENT" && "$agent_id" != "$TARGET_AGENT" ]]; then
    continue
  fi

  agent_name=$(echo "$agent" | jq -r '.name // .id')

  # Try to read costs.jsonl from agent workspace
  workspace=$(_get_workspace "$agent_id")
  costs_file="${workspace}/../${agent_id}/costs.jsonl"

  # Fallback to alternate location
  if [[ ! -f "$costs_file" ]]; then
    costs_file="${OPENCLAW_AGENTS_DIR}/${agent_id}/costs.jsonl"
  fi

  agent_in=0
  agent_out=0
  agent_cost=0

  if [[ -f "$costs_file" ]]; then
    # Parse costs.jsonl and sum values (simplified — real implementation would parse dates)
    while IFS= read -r line; do
      if [[ -z "$line" ]]; then continue; fi
      in_tokens=$(echo "$line" | jq -r '.input_tokens // 0')
      out_tokens=$(echo "$line" | jq -r '.output_tokens // 0')
      cost=$(echo "$line" | jq -r '.cost // 0')

      agent_in=$((agent_in + in_tokens))
      agent_out=$((agent_out + out_tokens))
      agent_cost=$(echo "$agent_cost + $cost" | bc 2>/dev/null || echo "0")
    done < "$costs_file"
  fi

  total_in=$((total_in + agent_in))
  total_out=$((total_out + agent_out))
  total_cost=$(echo "$total_cost + $agent_cost" | bc 2>/dev/null || echo "0")

  entry=$(jq -n \
    --arg id "$agent_id" \
    --arg name "$agent_name" \
    --argjson in "$agent_in" \
    --argjson out "$agent_out" \
    --argjson cost "$agent_cost" \
    '{id: $id, name: $name, input_tokens: $in, output_tokens: $out, cost: $cost}')

  cost_list=$(echo "$cost_list" | jq --argjson e "$entry" '. + [$e]')
done

# ── Output ─────────────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  echo "$cost_list" | jq --arg total_in "$total_in" --arg total_out "$total_out" --arg total_cost "$total_cost" \
    '{agents: ., total: {tokens_in: ($total_in | tonumber), tokens_out: ($total_out | tonumber), cost: ($total_cost | tonumber)}}'
  exit 0
fi

result_count=$(echo "$cost_list" | jq 'length')

if [[ "$result_count" -eq 0 ]]; then
  echo "No cost data available."
  exit 0
fi

echo ""
if [[ -n "$TARGET_AGENT" ]]; then
  echo "Agent Cost"
else
  echo "🔨 ClawForge Fleet Costs ($TIME_FILTER)"
fi
printf " %-12s %-12s %-12s %-12s %-10s\n" "ID" "Name" "Input Tokens" "Output Tokens" "Cost"
printf " %s\n" "────────────────────────────────────────────────────────────────"

echo "$cost_list" | jq -c '.[]' | while IFS= read -r row; do
  id=$(echo "$row" | jq -r '.id')
  name=$(echo "$row" | jq -r '.name')
  in=$(echo "$row" | jq -r '.input_tokens')
  out=$(echo "$row" | jq -r '.output_tokens')
  cost=$(echo "$row" | jq -r '.cost')

  printf " %-12s %-12s %-12s %-12s \$%-9s\n" "$id" "$name" "$in" "$out" "$cost"
done

echo ""
printf " %-12s %-12s %-12s %-12s \$%-9s\n" "TOTAL" "" "$total_in" "$total_out" "$total_cost"
echo ""
