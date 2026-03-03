#!/usr/bin/env bash
# history.sh — Show completed task history
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

HISTORY_FILE="${CLAWFORGE_DIR}/registry/completed-tasks.jsonl"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: history.sh [options]

Show completed task history.

Options:
  --repo <name>     Filter by repo name
  --mode <mode>     Filter by mode (sprint, swarm, review)
  --limit <n>       Number of entries to show (default: 10)
  --all             Show all entries (no limit)
  --help            Show this help
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
REPO_FILTER="" MODE_FILTER="" LIMIT=10 SHOW_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO_FILTER="$2"; shift 2 ;;
    --mode)    MODE_FILTER="$2"; shift 2 ;;
    --limit)   LIMIT="$2"; shift 2 ;;
    --all)     SHOW_ALL=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)         log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Check file ────────────────────────────────────────────────────────
if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
  echo "No completed tasks yet."
  echo "Tasks are recorded when cleaned via 'clawforge clean'."
  exit 0
fi

# ── Build jq filter ──────────────────────────────────────────────────
JQ_FILTER="."
if [[ -n "$REPO_FILTER" ]]; then
  JQ_FILTER="$JQ_FILTER | select(.repo | test(\"$REPO_FILTER\"; \"i\"))"
fi
if [[ -n "$MODE_FILTER" ]]; then
  JQ_FILTER="$JQ_FILTER | select(.mode == \"$MODE_FILTER\")"
fi

# ── Collect and limit ────────────────────────────────────────────────
ENTRIES=$(jq -c "$JQ_FILTER" "$HISTORY_FILE" 2>/dev/null || true)

if [[ -z "$ENTRIES" ]]; then
  echo "No matching tasks found."
  exit 0
fi

if ! $SHOW_ALL; then
  ENTRIES=$(echo "$ENTRIES" | tail -"$LIMIT")
fi

TOTAL=$(echo "$ENTRIES" | wc -l | tr -d ' ')

# ── Print table ──────────────────────────────────────────────────────
printf "%-12s %-8s %-40s %-8s %-8s %-8s %s\n" "Date" "Mode" "Task" "Status" "Dur" "Cost" "PR"
printf "%-12s %-8s %-40s %-8s %-8s %-8s %s\n" "────────────" "────────" "────────────────────────────────────────" "────────" "────────" "────────" "──────"

echo "$ENTRIES" | while IFS= read -r line; do
  date=$(echo "$line" | jq -r '.completedAt // .cleanedAt // .timestamp // 0' | \
    python3 -c "import sys,datetime; t=int(sys.stdin.read().strip()); print(datetime.datetime.fromtimestamp(t/1000).strftime('%Y-%m-%d') if t > 0 else '—')" 2>/dev/null || echo "—")
  mode=$(echo "$line" | jq -r '.mode // "—"')
  task=$(echo "$line" | jq -r '.description // "—"' | cut -c1-40)
  status=$(echo "$line" | jq -r '.status // "—"')
  dur_min=$(echo "$line" | jq -r '.duration_minutes // "—"')
  [[ "$dur_min" != "—" && "$dur_min" != "0" && "$dur_min" != "null" ]] && dur="${dur_min}m" || dur="—"
  cost=$(echo "$line" | jq -r '.cost // "—"')
  [[ "$cost" == "null" ]] && cost="—"
  pr=$(echo "$line" | jq -r '.pr // "—"')
  [[ "$pr" == "null" ]] && pr="—"

  printf "%-12s %-8s %-40s %-8s %-8s %-8s %s\n" "$date" "$mode" "$task" "$status" "$dur" "$cost" "$pr"
done

echo ""
echo "Showing $TOTAL entries."
