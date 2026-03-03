#!/usr/bin/env bash
# test-history.sh — Test history command (Feature 5)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
HISTORY_FILE="${CLAWFORGE_DIR}/registry/completed-tasks.jsonl"
HISTORY_BAK=""

cleanup() {
  rm -f "$HISTORY_FILE"
  [[ -n "$HISTORY_BAK" && -f "$HISTORY_BAK" ]] && mv "$HISTORY_BAK" "$HISTORY_FILE" 2>/dev/null || true
}
trap cleanup EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"; FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-history.sh ==="

# Backup existing file
if [[ -f "$HISTORY_FILE" ]]; then
  HISTORY_BAK=$(mktemp)
  cp "$HISTORY_FILE" "$HISTORY_BAK"
fi

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/history.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: empty history
echo "Test 2: empty history"
rm -f "$HISTORY_FILE"
empty_output=$("$BIN_DIR/history.sh" 2>/dev/null)
assert_contains "shows no tasks message" "No completed tasks" "$empty_output"

# Test 3: with entries
echo "Test 3: show entries"
NOW=$(epoch_ms)
STARTED=$((NOW - 1800000))  # 30 min ago

cat > "$HISTORY_FILE" <<EOF
{"id":"sprint-auth","description":"Add auth middleware","mode":"sprint","status":"done","repo":"/home/user/api","duration_minutes":30,"cost":"0.45","pr":"#42","completedAt":$NOW,"timestamp":$NOW}
{"id":"swarm-i18n","description":"Add i18n support","mode":"swarm","status":"done","repo":"/home/user/web","duration_minutes":60,"cost":"1.20","pr":"#55","completedAt":$NOW,"timestamp":$NOW}
{"id":"sprint-fix","description":"Fix null pointer bug","mode":"sprint","status":"failed","repo":"/home/user/api","duration_minutes":10,"cost":"0.10","pr":null,"completedAt":$NOW,"timestamp":$NOW}
EOF

output=$("$BIN_DIR/history.sh" 2>/dev/null)
assert_contains "shows date column" "Date" "$output"
assert_contains "shows mode column" "Mode" "$output"
assert_contains "shows auth task" "auth" "$output"
assert_contains "shows i18n task" "i18n" "$output"

# Test 4: --repo filter
echo "Test 4: --repo filter"
repo_output=$("$BIN_DIR/history.sh" --repo "api" 2>/dev/null)
assert_contains "filters to api repo" "auth" "$repo_output"
assert_contains "includes fix task" "null pointer" "$repo_output"

# Test 5: --mode filter
echo "Test 5: --mode filter"
mode_output=$("$BIN_DIR/history.sh" --mode "swarm" 2>/dev/null)
assert_contains "filters to swarm mode" "i18n" "$mode_output"

# Test 6: --limit
echo "Test 6: --limit"
limit_output=$("$BIN_DIR/history.sh" --limit 1 2>/dev/null)
# Should only show last 1 entry
line_count=$(echo "$limit_output" | grep -c "sprint\|swarm" || true)
assert_eq "limit 1 shows 1 entry" "1" "$line_count"

# Test 7: --all flag
echo "Test 7: --all"
all_output=$("$BIN_DIR/history.sh" --all 2>/dev/null)
all_count=$(echo "$all_output" | grep -c "sprint\|swarm" || true)
assert_eq "all shows 3 entries" "3" "$all_count"

# Test 8: clean.sh writes to completed-tasks.jsonl
echo "Test 8: clean appends to history"
rm -f "$HISTORY_FILE"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$(jq -n --argjson started "$STARTED" --argjson completed "$NOW" \
  '{id:"hist-test",description:"History test task",status:"done",mode:"sprint",agent:"claude",model:"claude-sonnet-4-5",repo:"/tmp/test",startedAt:$started,completedAt:$completed}')"
"$BIN_DIR/clean.sh" --task-id "hist-test" 2>/dev/null || true

if [[ -f "$HISTORY_FILE" ]]; then
  hist_entry=$(cat "$HISTORY_FILE" | jq -r '.id' | head -1)
  assert_eq "clean wrote to history" "hist-test" "$hist_entry"
  hist_desc=$(cat "$HISTORY_FILE" | jq -r '.description' | head -1)
  assert_eq "description preserved" "History test task" "$hist_desc"
else
  assert_eq "history file created by clean" "true" "false"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
