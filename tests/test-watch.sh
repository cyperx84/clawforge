#!/usr/bin/env bash
# test-watch.sh — Test module 4: check-agents
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""
TEST_TMUX="agent-test-watch-session"

cleanup() {
  tmux kill-session -t "$TEST_TMUX" 2>/dev/null || true
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
}
trap cleanup EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== test-watch.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')

# Test 1: Empty registry
echo "Test 1: empty registry"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/check-agents.sh" --json --dry-run 2>/dev/null)
if echo "$output" | jq -e '.tasks' >/dev/null 2>&1; then
  assert_eq "handles empty registry" "true" "true"
else
  assert_eq "handles empty registry" "true" "false"
fi

# Test 2: Detect running tmux session
echo "Test 2: detect running tmux session"
tmux new-session -d -s "$TEST_TMUX" "sleep 300" 2>/dev/null

TASK_RUNNING='{"id":"test-watch-running","tmuxSession":"'"$TEST_TMUX"'","agent":"claude","model":"claude-sonnet-4-5","description":"Watch test","repo":"/tmp","worktree":"/tmp","branch":"test-watch","startedAt":1000,"status":"spawned","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null}'
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$TASK_RUNNING" 2>/dev/null

output=$("$BIN_DIR/check-agents.sh" --json --dry-run 2>/dev/null)
detected_status=$(echo "$output" | jq -r '.tasks[0].currentStatus')
tmux_alive=$(echo "$output" | jq -r '.tasks[0].tmuxAlive')
assert_eq "detects running tmux" "true" "$tmux_alive"
assert_eq "status transitions to running" "running" "$detected_status"

# Test 3: Detect dead tmux session (failed)
echo "Test 3: detect dead session"
tmux kill-session -t "$TEST_TMUX" 2>/dev/null || true
TASK_DEAD='{"id":"test-watch-dead","tmuxSession":"agent-nonexistent-session-xyz","agent":"claude","model":"claude-sonnet-4-5","description":"Dead test","repo":"/tmp","worktree":"/tmp","branch":"test-dead","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null}'
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$TASK_DEAD" 2>/dev/null

output=$("$BIN_DIR/check-agents.sh" --json --dry-run 2>/dev/null)
detected_status=$(echo "$output" | jq -r '.tasks[0].currentStatus')
assert_eq "dead session detected as failed" "failed" "$detected_status"

# Test 4: --help flag
echo "Test 4: --help flag"
help_output=$("$BIN_DIR/check-agents.sh" --help 2>&1 || true)
if grep -q "Usage:" <<< "$help_output"; then
  assert_eq "help shows usage" "true" "true"
else
  assert_eq "help shows usage" "true" "false"
fi

# Test 5: JSON output format
echo "Test 5: JSON output structure"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$TASK_DEAD" 2>/dev/null
output=$("$BIN_DIR/check-agents.sh" --json --dry-run 2>/dev/null)
if echo "$output" | jq -e '.summary' >/dev/null 2>&1; then
  assert_eq "JSON has summary" "true" "true"
else
  assert_eq "JSON has summary" "true" "false"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
