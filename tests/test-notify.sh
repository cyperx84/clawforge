#!/usr/bin/env bash
# test-notify.sh — Test module 6: notify
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0

cleanup() {
  echo '{"tasks":[]}' > "$REGISTRY_FILE"
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

echo "=== test-notify.sh ==="

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/notify.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: missing message
echo "Test 2: missing message"
if "$BIN_DIR/notify.sh" 2>/dev/null; then
  assert_eq "exits with error" "false" "true"
else
  assert_eq "exits with error" "1" "1"
fi

# Test 3: dry-run with raw message
echo "Test 3: dry-run raw message"
dry_output=$("$BIN_DIR/notify.sh" --message "Hello world" --dry-run 2>/dev/null)
assert_contains "shows dry-run" "dry-run" "$dry_output"
assert_contains "shows message command" "openclaw message send" "$dry_output"
assert_contains "includes message" "Hello world" "$dry_output"

# Test 4: notification types - task-started
echo "Test 4: type task-started"
started_output=$("$BIN_DIR/notify.sh" --type task-started --description "Build auth" --dry-run 2>/dev/null)
assert_contains "task-started emoji" "🔧" "$started_output"
assert_contains "task-started desc" "Build auth" "$started_output"

# Test 5: notification types - pr-ready
echo "Test 5: type pr-ready"
pr_output=$("$BIN_DIR/notify.sh" --type pr-ready --description "Auth feature" --pr 42 --dry-run 2>/dev/null)
assert_contains "pr-ready emoji" "✅" "$pr_output"
assert_contains "pr-ready number" "42" "$pr_output"

# Test 6: notification types - task-failed
echo "Test 6: type task-failed"
fail_output=$("$BIN_DIR/notify.sh" --type task-failed --description "DB migration" --retry "2/3" --dry-run 2>/dev/null)
assert_contains "task-failed emoji" "❌" "$fail_output"
assert_contains "task-failed retry" "2/3" "$fail_output"

# Test 7: notification types - task-done
echo "Test 7: type task-done"
done_output=$("$BIN_DIR/notify.sh" --type task-done --description "Rate limiter" --dry-run 2>/dev/null)
assert_contains "task-done emoji" "🎉" "$done_output"
assert_contains "task-done desc" "Rate limiter" "$done_output"

# Test 8: custom channel
echo "Test 8: custom channel"
chan_output=$("$BIN_DIR/notify.sh" --channel "channel:12345" --message "Test" --dry-run 2>/dev/null)
assert_contains "uses custom channel" "channel:12345" "$chan_output"

# Test 9: task-id lookup
echo "Test 9: task-id registry lookup"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$(jq -n '{id:"test-task",description:"Registry test",status:"done",pr:99}')"
taskid_output=$("$BIN_DIR/notify.sh" --type pr-ready --task-id "test-task" --dry-run 2>/dev/null)
assert_contains "uses registry desc" "Registry test" "$taskid_output"
assert_contains "uses registry PR" "99" "$taskid_output"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
