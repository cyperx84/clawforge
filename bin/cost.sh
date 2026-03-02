#!/usr/bin/env bash
# cost.sh — Cost tracking module: capture, store, and query token usage
# Usage: clawforge cost [task-id] [--summary] [--json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

COSTS_FILE="${CLAWFORGE_DIR}/registry/costs.jsonl"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge cost [task-id] [flags]

Cost tracking for ClawForge agent runs.

Commands:
  clawforge cost <task-id>        Show cost breakdown for a task
  clawforge cost --summary        All-time cost summary grouped by mode
  clawforge cost --capture <id>   Capture cost from running agent tmux pane

Flags:
  --summary          Show all-time cost summary
  --capture <id>     Capture cost from agent's tmux pane
  --json             Output as JSON
  --help             Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
TASK_ID="" SUMMARY=false CAPTURE="" JSON_OUTPUT=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)   SUMMARY=true; shift ;;
    --capture)   CAPTURE="$2"; shift 2 ;;
    --json)      JSON_OUTPUT=true; shift ;;
    --help|-h)   usage; exit 0 ;;
    --*)         log_error "Unknown option: $1"; usage; exit 1 ;;
    *)           POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  TASK_ID="${POSITIONAL[0]}"
fi

mkdir -p "$(dirname "$COSTS_FILE")"
touch "$COSTS_FILE"

# ── Capture cost from tmux pane ────────────────────────────────────────
_capture_cost() {
  local task_id="$1"
  local resolved_id
  resolved_id=$(resolve_task_id "$task_id")

  local task_data
  task_data=$(registry_get "$resolved_id")
  if [[ -z "$task_data" ]]; then
    log_error "Task '$task_id' not found"
    exit 1
  fi

  local tmux_session agent_type
  tmux_session=$(echo "$task_data" | jq -r '.tmuxSession // ""')
  agent_type=$(echo "$task_data" | jq -r '.agent // "claude"')
  local model
  model=$(echo "$task_data" | jq -r '.model // "unknown"')

  # Scrape tmux pane for cost info
  local pane_content=""
  if [[ -n "$tmux_session" ]] && tmux has-session -t "$tmux_session" 2>/dev/null; then
    pane_content=$(tmux capture-pane -t "$tmux_session" -p -S -100 2>/dev/null || true)
  fi

  # Parse cost data from pane output
  local input_tokens=0 output_tokens=0 cache_hits=0 total_cost="0.00"

  if [[ -n "$pane_content" ]]; then
    # Claude Code /cost output format: "Input tokens: X  Output tokens: Y  Total cost: $Z"
    input_tokens=$(echo "$pane_content" | grep -ioE 'input[_ ]tokens?:?\s*[0-9,]+' | tail -1 | grep -oE '[0-9,]+' | tr -d ',' || echo "0")
    output_tokens=$(echo "$pane_content" | grep -ioE 'output[_ ]tokens?:?\s*[0-9,]+' | tail -1 | grep -oE '[0-9,]+' | tr -d ',' || echo "0")
    cache_hits=$(echo "$pane_content" | grep -ioE 'cache[_ ]hits?:?\s*[0-9,]+' | tail -1 | grep -oE '[0-9,]+' | tr -d ',' || echo "0")
    total_cost=$(echo "$pane_content" | grep -ioE 'total[_ ]cost:?\s*\$?[0-9]+\.?[0-9]*' | tail -1 | grep -oE '[0-9]+\.?[0-9]*' || echo "0.00")
  fi

  [[ -z "$input_tokens" ]] && input_tokens=0
  [[ -z "$output_tokens" ]] && output_tokens=0
  [[ -z "$cache_hits" ]] && cache_hits=0
  [[ -z "$total_cost" ]] && total_cost="0.00"

  local now
  now=$(epoch_ms)

  local cost_entry
  cost_entry=$(jq -cn \
    --arg taskId "$resolved_id" \
    --arg agentId "${tmux_session}" \
    --arg model "$model" \
    --argjson inputTokens "${input_tokens:-0}" \
    --argjson outputTokens "${output_tokens:-0}" \
    --argjson cacheHits "${cache_hits:-0}" \
    --arg totalCost "$total_cost" \
    --argjson timestamp "$now" \
    '{
      taskId: $taskId,
      agentId: $agentId,
      model: $model,
      inputTokens: $inputTokens,
      outputTokens: $outputTokens,
      cacheHits: $cacheHits,
      totalCost: ($totalCost | tonumber),
      timestamp: $timestamp
    }')

  echo "$cost_entry" >> "$COSTS_FILE"
  log_info "Cost captured for $resolved_id: \$$total_cost"

  if $JSON_OUTPUT; then
    echo "$cost_entry"
  else
    echo "Cost captured for $resolved_id:"
    echo "  Input tokens:  $input_tokens"
    echo "  Output tokens: $output_tokens"
    echo "  Cache hits:    $cache_hits"
    echo "  Total cost:    \$$total_cost"
  fi
}

# ── Show cost for a task ───────────────────────────────────────────────
_show_task_cost() {
  local task_id="$1"
  local resolved_id
  resolved_id=$(resolve_task_id "$task_id")

  local entries
  entries=$(grep "\"taskId\":\"${resolved_id}\"" "$COSTS_FILE" 2>/dev/null || true)

  if [[ -z "$entries" ]]; then
    # Check if it's a swarm parent — sum sub-agent costs
    local sub_costs
    sub_costs=$(grep "\"taskId\":\"${resolved_id}" "$COSTS_FILE" 2>/dev/null || true)
    if [[ -z "$sub_costs" ]]; then
      if $JSON_OUTPUT; then
        echo '{"taskId":"'"$resolved_id"'","totalCost":0,"entries":[]}'
      else
        echo "No cost data for task: $resolved_id"
      fi
      return
    fi
    entries="$sub_costs"
  fi

  if $JSON_OUTPUT; then
    echo "$entries" | jq -s --arg tid "$resolved_id" '{
      taskId: $tid,
      entries: .,
      totalCost: ([.[].totalCost] | add // 0),
      totalInputTokens: ([.[].inputTokens] | add // 0),
      totalOutputTokens: ([.[].outputTokens] | add // 0)
    }'
  else
    local total_cost total_input total_output
    total_cost=$(echo "$entries" | jq -s '[.[].totalCost] | add // 0' 2>/dev/null || echo "0")
    total_input=$(echo "$entries" | jq -s '[.[].inputTokens] | add // 0' 2>/dev/null || echo "0")
    total_output=$(echo "$entries" | jq -s '[.[].outputTokens] | add // 0' 2>/dev/null || echo "0")

    echo "=== Cost Breakdown: $resolved_id ==="
    echo ""
    echo "  Total cost:    \$${total_cost}"
    echo "  Input tokens:  ${total_input}"
    echo "  Output tokens: ${total_output}"
    echo ""

    local entry_count
    entry_count=$(echo "$entries" | wc -l | tr -d ' ')
    echo "  Entries: ${entry_count}"

    echo ""
    echo "  History:"
    echo "$entries" | jq -r '"  [\(.timestamp | . / 1000 | strftime("%H:%M:%S"))] \(.model) — $\(.totalCost) (\(.inputTokens) in / \(.outputTokens) out)"' 2>/dev/null || true
  fi
}

# ── Summary ────────────────────────────────────────────────────────────
_show_summary() {
  if [[ ! -s "$COSTS_FILE" ]]; then
    if $JSON_OUTPUT; then
      echo '{"totalCost":0,"entries":0,"byMode":{}}'
    else
      echo "No cost data recorded yet."
    fi
    return
  fi

  local all_entries
  all_entries=$(cat "$COSTS_FILE" | jq -s '.' 2>/dev/null)

  if $JSON_OUTPUT; then
    echo "$all_entries" | jq '{
      totalCost: ([.[].totalCost] | add // 0),
      totalInputTokens: ([.[].inputTokens] | add // 0),
      totalOutputTokens: ([.[].outputTokens] | add // 0),
      entries: length,
      byModel: (group_by(.model) | map({key: .[0].model, value: {cost: ([.[].totalCost] | add // 0), entries: length}}) | from_entries)
    }'
    return
  fi

  local total_cost total_input total_output entry_count
  total_cost=$(echo "$all_entries" | jq '[.[].totalCost] | add // 0' 2>/dev/null || echo "0")
  total_input=$(echo "$all_entries" | jq '[.[].inputTokens] | add // 0' 2>/dev/null || echo "0")
  total_output=$(echo "$all_entries" | jq '[.[].outputTokens] | add // 0' 2>/dev/null || echo "0")
  entry_count=$(echo "$all_entries" | jq 'length' 2>/dev/null || echo "0")

  echo "=== Cost Summary ==="
  echo ""
  echo "  Total cost:    \$${total_cost}"
  echo "  Input tokens:  ${total_input}"
  echo "  Output tokens: ${total_output}"
  echo "  Entries:       ${entry_count}"
  echo ""

  # By model
  echo "  By Model:"
  echo "$all_entries" | jq -r 'group_by(.model) | .[] | "  \(.[0].model): $\([.[].totalCost] | add // 0) (\(length) runs)"' 2>/dev/null || true
  echo ""

  # By task (top 5 most expensive)
  echo "  Top 5 Most Expensive Tasks:"
  echo "$all_entries" | jq -r 'group_by(.taskId) | map({taskId: .[0].taskId, cost: ([.[].totalCost] | add // 0)}) | sort_by(-.cost) | .[0:5] | .[] | "  \(.taskId): $\(.cost)"' 2>/dev/null || true
}

# ── Budget check (called from sprint/swarm) ───────────────────────────
# Usage: source cost.sh && check_budget <task-id> <budget>
check_budget() {
  local task_id="$1" budget="$2"
  if [[ ! -f "$COSTS_FILE" ]]; then
    return 0  # No data, budget not exceeded
  fi

  local spent
  spent=$(grep "\"taskId\":\"${task_id}\"" "$COSTS_FILE" 2>/dev/null | jq -s '[.[].totalCost] | add // 0' 2>/dev/null || echo "0")

  local exceeded
  exceeded=$(python3 -c "print(1 if $spent >= $budget else 0)" 2>/dev/null || echo "0")
  if [[ "$exceeded" == "1" ]]; then
    return 1  # Budget exceeded
  fi

  # Warn at 80%
  local warning
  warning=$(python3 -c "print(1 if $spent >= $budget * 0.8 else 0)" 2>/dev/null || echo "0")
  if [[ "$warning" == "1" ]]; then
    log_warn "Budget warning: \$$spent / \$$budget (80% threshold)"
  fi

  return 0
}

# ── Route ──────────────────────────────────────────────────────────────
if [[ -n "$CAPTURE" ]]; then
  _capture_cost "$CAPTURE"
elif $SUMMARY; then
  _show_summary
elif [[ -n "$TASK_ID" ]]; then
  _show_task_cost "$TASK_ID"
else
  usage
  exit 0
fi
