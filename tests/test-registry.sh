#!/usr/bin/env bash
# test-registry.sh — Test module 3: registry CRUD
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""

cleanup() {
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

echo "=== test-registry.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# Test 1: Add
echo "Test 1: registry_add"
TASK1='{"id":"test-1","tmuxSession":"agent-test-1","agent":"claude","model":"claude-sonnet-4-5","description":"Test task 1","repo":"/tmp","worktree":"/tmp/wt","branch":"test-1","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null}'
registry_add "$TASK1" 2>/dev/null
count=$(jq '.tasks | length' "$REGISTRY_FILE")
assert_eq "add task" "1" "$count"

# Test 2: Add second task
echo "Test 2: add second task"
TASK2='{"id":"test-2","tmuxSession":"agent-test-2","agent":"codex","model":"gpt-5.3","description":"Test task 2","repo":"/tmp","worktree":"/tmp/wt2","branch":"test-2","startedAt":2000,"status":"failed","retries":1,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null}'
registry_add "$TASK2" 2>/dev/null
count=$(jq '.tasks | length' "$REGISTRY_FILE")
assert_eq "two tasks" "2" "$count"

# Test 3: Get by ID
echo "Test 3: registry_get"
got_id=$(registry_get "test-1" | jq -r '.id')
assert_eq "get by id" "test-1" "$got_id"

got_agent=$(registry_get "test-1" | jq -r '.agent')
assert_eq "get agent field" "claude" "$got_agent"

# Test 4: Update
echo "Test 4: registry_update"
registry_update "test-1" "status" '"done"' 2>/dev/null
new_status=$(registry_get "test-1" | jq -r '.status')
assert_eq "update status" "done" "$new_status"

registry_update "test-1" "pr" '42' 2>/dev/null
new_pr=$(registry_get "test-1" | jq -r '.pr')
assert_eq "update pr number" "42" "$new_pr"

# Test 5: List with filter
echo "Test 5: registry_list with filter"
running=$(registry_list --status running | jq 'length')
assert_eq "no running tasks" "0" "$running"

failed=$(registry_list --status failed | jq 'length')
assert_eq "one failed task" "1" "$failed"

all=$(registry_list | jq 'length')
assert_eq "two total tasks" "2" "$all"

# Test 6: Remove
echo "Test 6: registry_remove"
registry_remove "test-1" 2>/dev/null
count=$(jq '.tasks | length' "$REGISTRY_FILE")
assert_eq "one task after remove" "1" "$count"

remaining_id=$(jq -r '.tasks[0].id' "$REGISTRY_FILE")
assert_eq "correct task remains" "test-2" "$remaining_id"

# Test 7: Remove last task
echo "Test 7: remove last task"
registry_remove "test-2" 2>/dev/null
count=$(jq '.tasks | length' "$REGISTRY_FILE")
assert_eq "zero tasks" "0" "$count"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
