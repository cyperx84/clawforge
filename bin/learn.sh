#!/usr/bin/env bash
# learn.sh — Module 9: Capture learnings from completed tasks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

LEARNINGS_FILE="${CLAWFORGE_DIR}/registry/learnings.jsonl"
MEMORY_DIR="$HOME/.openclaw/agents/builder/memory"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: learn.sh [options]

Options:
  --task-id <id>     Task ID to learn from (required unless --summary)
  --auto             Auto-generate notes from task data
  --notes <text>     Manual notes to attach
  --tags <t1,t2>     Comma-separated pattern tags
  --summary          Output summary of all learnings
  --memory           Also append to Builder's daily memory
  --help             Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
TASK_ID="" AUTO=false NOTES="" TAGS="" SUMMARY=false MEMORY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id)  TASK_ID="$2"; shift 2 ;;
    --auto)     AUTO=true; shift ;;
    --notes)    NOTES="$2"; shift 2 ;;
    --tags)     TAGS="$2"; shift 2 ;;
    --summary)  SUMMARY=true; shift ;;
    --memory)   MEMORY=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    *)          log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

mkdir -p "$(dirname "$LEARNINGS_FILE")"

# ── Summary mode ─────────────────────────────────────────────────────
if $SUMMARY; then
  if [[ ! -f "$LEARNINGS_FILE" ]]; then
    echo "No learnings recorded yet."
    exit 0
  fi

  TOTAL=$(wc -l < "$LEARNINGS_FILE" | tr -d ' ')
  SUCCESSES=$(grep -c '"success":true' "$LEARNINGS_FILE" 2>/dev/null || echo 0)
  FAILURES=$(grep -c '"success":false' "$LEARNINGS_FILE" 2>/dev/null || echo 0)

  echo "=== Learning Summary ==="
  echo "Total entries: $TOTAL"
  echo "Successes: $SUCCESSES"
  echo "Failures: $FAILURES"
  if [[ "$TOTAL" -gt 0 ]]; then
    RATE=$(python3 -c "print(f'{($SUCCESSES/$TOTAL)*100:.0f}%')" 2>/dev/null || echo "N/A")
    echo "Success rate: $RATE"
  fi
  echo ""

  # Average duration
  AVG_DURATION=$(cat "$LEARNINGS_FILE" | jq -s '[.[].duration_minutes | select(. != null and . > 0)] | if length > 0 then (add / length | floor) else 0 end' 2>/dev/null || echo 0)
  echo "Avg duration: ${AVG_DURATION} min"

  # Agent breakdown
  echo ""
  echo "By agent:"
  cat "$LEARNINGS_FILE" | jq -r '.agent' | sort | uniq -c | sort -rn | while read count agent; do
    echo "  $agent: $count"
  done

  # Model breakdown
  echo ""
  echo "By model:"
  cat "$LEARNINGS_FILE" | jq -r '.model' | sort | uniq -c | sort -rn | while read count model; do
    echo "  $model: $count"
  done

  # Recent entries
  echo ""
  echo "Recent (last 5):"
  tail -5 "$LEARNINGS_FILE" | jq -r '"  [\(.taskId)] \(.agent)/\(.model) — \(.success | if . then "✅" else "❌" end) \(.duration_minutes // "?")min — \(.notes // "no notes")"' 2>/dev/null || true

  exit 0
fi

# ── Learn from task ──────────────────────────────────────────────────
[[ -z "$TASK_ID" ]] && { log_error "--task-id is required (or use --summary)"; usage; exit 1; }

TASK_DATA=$(registry_get "$TASK_ID")
if [[ -z "$TASK_DATA" ]]; then
  log_error "Task '$TASK_ID' not found in registry"
  exit 1
fi

AGENT=$(echo "$TASK_DATA" | jq -r '.agent // "unknown"')
MODEL=$(echo "$TASK_DATA" | jq -r '.model // "unknown"')
RETRIES=$(echo "$TASK_DATA" | jq -r '.retries // 0')
STATUS=$(echo "$TASK_DATA" | jq -r '.status // "unknown"')
STARTED=$(echo "$TASK_DATA" | jq -r '.startedAt // 0')
COMPLETED=$(echo "$TASK_DATA" | jq -r '.completedAt // 0')
BRANCH=$(echo "$TASK_DATA" | jq -r '.branch // ""')
CHECKS=$(echo "$TASK_DATA" | jq '.checks // {}')
DESC=$(echo "$TASK_DATA" | jq -r '.description // ""')

# Calculate duration
DURATION_MIN=0
if [[ "$STARTED" -gt 0 && "$COMPLETED" -gt 0 ]]; then
  DURATION_MS=$((COMPLETED - STARTED))
  DURATION_MIN=$((DURATION_MS / 60000))
fi

# Determine success
SUCCESS=false
if [[ "$STATUS" == "done" || "$STATUS" == "archived" ]]; then
  SUCCESS=true
fi

# Reviews passed
REVIEWS_PASSED=$(echo "$CHECKS" | jq '[to_entries[] | select(.value | test("APPROVE"; "i")) | .key]' 2>/dev/null || echo '[]')

# Auto-generate notes
if $AUTO && [[ -z "$NOTES" ]]; then
  if [[ "$RETRIES" -eq 0 ]] && $SUCCESS; then
    NOTES="One-shot success."
  elif [[ "$RETRIES" -gt 0 ]] && $SUCCESS; then
    NOTES="Succeeded after $RETRIES retries."
  elif ! $SUCCESS; then
    NOTES="Failed. Status: $STATUS."
  fi

  if [[ "$DURATION_MIN" -gt 60 ]]; then
    NOTES+=" Long-running task (${DURATION_MIN}min)."
  elif [[ "$DURATION_MIN" -gt 0 && "$DURATION_MIN" -le 10 ]]; then
    NOTES+=" Quick task (${DURATION_MIN}min)."
  fi
fi

# Parse tags
TAGS_JSON="[]"
if [[ -n "$TAGS" ]]; then
  TAGS_JSON=$(echo "$TAGS" | tr ',' '\n' | jq -R . | jq -s .)
else
  # Auto-tag from branch name
  TAGS_JSON="[]"
  if [[ "$BRANCH" == feat/* || "$BRANCH" == feature/* ]]; then
    TAGS_JSON='["feature"]'
  elif [[ "$BRANCH" == fix/* || "$BRANCH" == bugfix/* ]]; then
    TAGS_JSON='["bugfix"]'
  elif [[ "$BRANCH" == refactor/* ]]; then
    TAGS_JSON='["refactor"]'
  fi
fi

# Build learning entry
NOW=$(epoch_ms)
LEARNING=$(jq -cn \
  --argjson timestamp "$NOW" \
  --arg taskId "$TASK_ID" \
  --arg agent "$AGENT" \
  --arg model "$MODEL" \
  --argjson duration_minutes "$DURATION_MIN" \
  --argjson retries "$RETRIES" \
  --argjson success "$SUCCESS" \
  --argjson reviews_passed "$REVIEWS_PASSED" \
  --arg branch "$BRANCH" \
  --argjson pattern_tags "$TAGS_JSON" \
  --arg notes "${NOTES:-}" \
  '{
    timestamp: $timestamp,
    taskId: $taskId,
    agent: $agent,
    model: $model,
    duration_minutes: $duration_minutes,
    retries: $retries,
    success: $success,
    reviews_passed: $reviews_passed,
    branch: $branch,
    pattern_tags: $pattern_tags,
    notes: $notes
  }')

# Write learning
echo "$LEARNING" >> "$LEARNINGS_FILE"
log_info "Learning recorded for task: $TASK_ID"

# Output
echo "$LEARNING" | jq .

# Append to clawforge memory with source=learn
CLAWFORGE_MEMORY_BASE="$HOME/.clawforge/memory"
LEARN_REPO=$(echo "$TASK_DATA" | jq -r '.repo // empty')
if [[ -n "$LEARN_REPO" ]]; then
  LEARN_REPO_NAME=$(basename "$LEARN_REPO")
  LEARN_REMOTE=$(git -C "$LEARN_REPO" config --get remote.origin.url 2>/dev/null || true)
  [[ -n "$LEARN_REMOTE" ]] && LEARN_REPO_NAME=$(basename "$LEARN_REMOTE" .git)
  LEARN_MEMORY_FILE="${CLAWFORGE_MEMORY_BASE}/${LEARN_REPO_NAME}.jsonl"
  mkdir -p "$CLAWFORGE_MEMORY_BASE"
  MEMORY_TEXT="[learn] ${DESC}: ${NOTES:-$AGENT/$MODEL, ${DURATION_MIN}min, retries=$RETRIES}"
  LEARN_MEM_ENTRY=$(jq -cn \
    --arg id "learn-$(date +%s)" \
    --arg text "$MEMORY_TEXT" \
    --argjson tags "$TAGS_JSON" \
    --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "learn" \
    '{id:$id, text:$text, tags:$tags, created:$created, source:$source}')
  echo "$LEARN_MEM_ENTRY" >> "$LEARN_MEMORY_FILE"
  log_info "Appended to clawforge memory: $LEARN_MEMORY_FILE"
fi

# Append to Builder's daily memory
if $MEMORY; then
  mkdir -p "$MEMORY_DIR"
  TODAY=$(date +%Y-%m-%d)
  MEMORY_FILE="${MEMORY_DIR}/${TODAY}.md"

  {
    echo ""
    echo "## Learning: $TASK_ID"
    echo "- Agent: $AGENT / $MODEL"
    echo "- Duration: ${DURATION_MIN}min | Retries: $RETRIES | Success: $SUCCESS"
    [[ -n "$NOTES" ]] && echo "- Notes: $NOTES"
  } >> "$MEMORY_FILE"
  log_info "Appended to memory: $MEMORY_FILE"
fi
