#!/usr/bin/env bash
# parse-cost.sh — Parse real cost/token data from agent output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge parse-cost <id> [options]

Parse token usage and cost from a running or completed agent's tmux output.
Supports Claude Code and Codex output formats.

Arguments:
  <id>                 Task ID or short ID (or "all" for all running tasks)

Options:
  --lines <N>          Lines to scan from tmux (default: 200)
  --update             Write parsed cost to registry costs.jsonl
  --json               Output as JSON
  --help               Show this help

Examples:
  clawforge parse-cost 1
  clawforge parse-cost all --update
  clawforge parse-cost 1 --json
EOF
}

TASK_REF="" LINES=200 UPDATE=false JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lines)   LINES="$2"; shift 2 ;;
    --update)  UPDATE=true; shift ;;
    --json)    JSON_OUTPUT=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --*)       log_error "Unknown option: $1"; usage; exit 1 ;;
    *)         TASK_REF="$1"; shift ;;
  esac
done

[[ -z "$TASK_REF" ]] && { log_error "Task ID required"; usage; exit 1; }

_ensure_registry
COSTS_FILE="${CLAWFORGE_DIR}/registry/costs.jsonl"

# Parse cost from captured output
parse_cost_from_output() {
  local output="$1"
  local task_id="$2"

  local total_cost=0
  local input_tokens=0
  local output_tokens=0
  local total_tokens=0
  local found=false

  # Claude Code patterns:
  # "Total cost: $1.23"
  # "Cost: $0.45"
  # "Input tokens: 12345"
  # "Output tokens: 6789"
  # "> Total cost: $X.XX"
  # "Total input tokens: X"
  local cost_match
  cost_match=$(echo "$output" | grep -ioE '(total )?cost:?\s*\$[0-9]+\.[0-9]+' | tail -1 || true)
  if [[ -n "$cost_match" ]]; then
    total_cost=$(echo "$cost_match" | grep -oE '[0-9]+\.[0-9]+' | tail -1)
    found=true
  fi

  local input_match
  input_match=$(echo "$output" | grep -ioE '(total )?input tokens?:?\s*[0-9,]+' | tail -1 || true)
  if [[ -n "$input_match" ]]; then
    input_tokens=$(echo "$input_match" | grep -oE '[0-9,]+' | tail -1 | tr -d ',')
    found=true
  fi

  local output_match
  output_match=$(echo "$output" | grep -ioE '(total )?output tokens?:?\s*[0-9,]+' | tail -1 || true)
  if [[ -n "$output_match" ]]; then
    output_tokens=$(echo "$output_match" | grep -oE '[0-9,]+' | tail -1 | tr -d ',')
    found=true
  fi

  # Codex patterns:
  # "Tokens used: 12345"
  # "API cost: $1.23"
  if ! $found; then
    local codex_cost
    codex_cost=$(echo "$output" | grep -ioE 'api cost:?\s*\$[0-9]+\.[0-9]+' | tail -1 || true)
    if [[ -n "$codex_cost" ]]; then
      total_cost=$(echo "$codex_cost" | grep -oE '[0-9]+\.[0-9]+' | tail -1)
      found=true
    fi

    local codex_tokens
    codex_tokens=$(echo "$output" | grep -ioE 'tokens? used:?\s*[0-9,]+' | tail -1 || true)
    if [[ -n "$codex_tokens" ]]; then
      total_tokens=$(echo "$codex_tokens" | grep -oE '[0-9,]+' | tail -1 | tr -d ',')
      found=true
    fi
  fi

  # Calculate total tokens
  if [[ "$total_tokens" -eq 0 ]]; then
    total_tokens=$((input_tokens + output_tokens))
  fi

  if $found; then
    jq -cn \
      --arg id "$task_id" \
      --argjson cost "$total_cost" \
      --argjson input "$input_tokens" \
      --argjson output "$output_tokens" \
      --argjson total "$total_tokens" \
      --argjson ts "$(epoch_ms)" \
      '{taskId:$id, totalCost:$cost, inputTokens:$input, outputTokens:$output, totalTokens:$total, timestamp:$ts, source:"parsed"}'
  else
    echo ""
  fi
}

# Process single task
process_task() {
  local task_ref="$1"
  local task_data=""

  if [[ "$task_ref" =~ ^[0-9]+$ ]]; then
    task_data=$(jq -r --argjson sid "$task_ref" '.tasks[] | select(.short_id == $sid)' "$REGISTRY_FILE" 2>/dev/null || true)
  fi
  if [[ -z "$task_data" ]]; then
    task_data=$(registry_get "$task_ref" 2>/dev/null || true)
  fi
  if [[ -z "$task_data" ]]; then
    log_warn "Task '$task_ref' not found"
    return 1
  fi

  local id=$(echo "$task_data" | jq -r '.id')
  local sid=$(echo "$task_data" | jq -r '.short_id // 0')
  local tmux_session=$(echo "$task_data" | jq -r '.tmuxSession // empty')
  [[ -z "$tmux_session" ]] && tmux_session="agent-${id}"

  # Capture tmux output
  local output=""
  if tmux has-session -t "$tmux_session" 2>/dev/null; then
    output=$(tmux capture-pane -t "$tmux_session" -p -S "-${LINES}" 2>/dev/null || true)
  fi

  if [[ -z "$output" ]]; then
    if $JSON_OUTPUT; then
      jq -cn --arg id "$id" --argjson sid "$sid" '{taskId:$id, shortId:$sid, status:"no_output"}'
    else
      echo "  #${sid} ($id): no output available"
    fi
    return 0
  fi

  # Parse
  local result
  result=$(parse_cost_from_output "$output" "$id")

  if [[ -z "$result" ]]; then
    if $JSON_OUTPUT; then
      jq -cn --arg id "$id" --argjson sid "$sid" '{taskId:$id, shortId:$sid, status:"no_cost_found"}'
    else
      echo "  #${sid} ($id): no cost data found in output"
    fi
    return 0
  fi

  # Update registry
  if $UPDATE; then
    echo "$result" >> "$COSTS_FILE"
    local cost=$(echo "$result" | jq -r '.totalCost')
    registry_update "$id" "cost" "\"$cost\"" 2>/dev/null || true
    log_info "Updated cost for #${sid}: \$${cost}"
  fi

  if $JSON_OUTPUT; then
    echo "$result"
  else
    local cost=$(echo "$result" | jq -r '.totalCost')
    local tokens=$(echo "$result" | jq -r '.totalTokens')
    echo "  #${sid} ($id): \$${cost} | ${tokens} tokens"
  fi
}

# Process all or single
if [[ "$TASK_REF" == "all" ]]; then
  echo "── Parsing costs for all running tasks ──"
  IDS=$(jq -r '.tasks[] | select(.status == "running" or .status == "spawned") | .id' "$REGISTRY_FILE" 2>/dev/null || true)
  if [[ -z "$IDS" ]]; then
    echo "No running tasks."
    exit 0
  fi
  while IFS= read -r id; do
    process_task "$id" || true
  done <<< "$IDS"
else
  process_task "$TASK_REF"
fi
