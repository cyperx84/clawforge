#!/usr/bin/env bash
# export.sh — Export task history as markdown or JSON report
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge export [options]

Export full task history as a report.

Options:
  --format <fmt>       Output format: markdown, json (default: markdown)
  --status <status>    Filter by status (done, failed, running, all) (default: all)
  --since <date>       Filter tasks since date (YYYY-MM-DD)
  --save <path>        Save to file (default: stdout)
  --help               Show this help

Examples:
  clawforge export                                # Full markdown report
  clawforge export --format json                   # JSON dump
  clawforge export --status done --save report.md  # Only completed tasks
  clawforge export --since 2026-03-01             # Recent tasks only
EOF
}

FORMAT="markdown" STATUS_FILTER="all" SINCE="" SAVE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --status) STATUS_FILTER="$2"; shift 2 ;;
    --since)  SINCE="$2"; shift 2 ;;
    --save)   SAVE_PATH="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --*)      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)        shift ;;
  esac
done

_ensure_registry

# Gather all tasks (active + completed)
COMPLETED_FILE="${CLAWFORGE_DIR}/registry/completed-tasks.jsonl"
COSTS_FILE="${CLAWFORGE_DIR}/registry/costs.jsonl"

ALL_TASKS="[]"

# Active tasks
ACTIVE=$(jq '.tasks' "$REGISTRY_FILE" 2>/dev/null || echo '[]')
ALL_TASKS=$(echo "$ACTIVE" | jq '.')

# Completed tasks
if [[ -f "$COMPLETED_FILE" ]]; then
  COMPLETED=$(jq -s '.' "$COMPLETED_FILE" 2>/dev/null || echo '[]')
  ALL_TASKS=$(jq -s '.[0] + .[1] | unique_by(.id // .taskId)' <(echo "$ALL_TASKS") <(echo "$COMPLETED") 2>/dev/null || echo "$ALL_TASKS")
fi

# Apply filters
if [[ "$STATUS_FILTER" != "all" ]]; then
  ALL_TASKS=$(echo "$ALL_TASKS" | jq --arg s "$STATUS_FILTER" '[.[] | select(.status == $s)]')
fi

if [[ -n "$SINCE" ]]; then
  SINCE_TS=$(date -j -f "%Y-%m-%d" "$SINCE" "+%s" 2>/dev/null || date -d "$SINCE" "+%s" 2>/dev/null || echo "0")
  SINCE_MS=$((SINCE_TS * 1000))
  ALL_TASKS=$(echo "$ALL_TASKS" | jq --argjson s "$SINCE_MS" '[.[] | select((.startedAt // .timestamp // 0) >= $s)]')
fi

TASK_COUNT=$(echo "$ALL_TASKS" | jq 'length')

# Generate output
generate_markdown() {
  echo "# ClawForge Task Report"
  echo "Generated: $(date)"
  echo "Tasks: $TASK_COUNT"
  [[ "$STATUS_FILTER" != "all" ]] && echo "Filter: status=$STATUS_FILTER"
  [[ -n "$SINCE" ]] && echo "Since: $SINCE"
  echo ""

  # Summary stats
  DONE_COUNT=$(echo "$ALL_TASKS" | jq '[.[] | select(.status == "done")] | length')
  FAIL_COUNT=$(echo "$ALL_TASKS" | jq '[.[] | select(.status == "failed")] | length')
  RUN_COUNT=$(echo "$ALL_TASKS" | jq '[.[] | select(.status == "running")] | length')

  echo "## Summary"
  echo "| Status | Count |"
  echo "|--------|-------|"
  echo "| ✅ Done | $DONE_COUNT |"
  echo "| ❌ Failed | $FAIL_COUNT |"
  echo "| 🔄 Running | $RUN_COUNT |"
  echo "| Total | $TASK_COUNT |"
  echo ""

  # Costs
  if [[ -f "$COSTS_FILE" ]] && [[ -s "$COSTS_FILE" ]]; then
    TOTAL_COST=$(jq -s '[.[].totalCost // 0] | add' "$COSTS_FILE" 2>/dev/null || echo "0")
    TOTAL_TOKENS=$(jq -s '[.[].totalTokens // 0] | add' "$COSTS_FILE" 2>/dev/null || echo "0")
    echo "## Costs"
    echo "- Total cost: \$${TOTAL_COST}"
    echo "- Total tokens: ${TOTAL_TOKENS}"
    echo ""
  fi

  # Task details
  echo "## Tasks"
  echo ""

  echo "$ALL_TASKS" | jq -r '.[] | "### #\(.short_id // "—") — \(.description // .desc // "—")\n- **Status:** \(.status // "—")\n- **Mode:** \(.mode // "—")\n- **Agent:** \(.agent // "—")\n- **Branch:** \(.branch // "—")\n"' 2>/dev/null || true
}

if [[ "$FORMAT" == "json" ]]; then
  OUTPUT=$(echo "$ALL_TASKS" | jq '.')
else
  OUTPUT=$(generate_markdown)
fi

if [[ -n "$SAVE_PATH" ]]; then
  echo "$OUTPUT" > "$SAVE_PATH"
  echo "Report saved to $SAVE_PATH ($TASK_COUNT tasks)"
else
  echo "$OUTPUT"
fi
