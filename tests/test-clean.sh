#!/usr/bin/env bash
# test-clean.sh — Test module 8: clean
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
TMPDIR=""
CLEANUP_LOG="${CLAWFORGE_DIR}/registry/cleanup-log.jsonl"

cleanup() {
  [[ -n "$TMPDIR" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
  echo '{"tasks":[]}' > "$REGISTRY_FILE"
  rm -f "$CLEANUP_LOG"
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

echo "=== test-clean.sh ==="

TMPDIR=$(mktemp -d)

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/clean.sh" --help 2>&1 || true)
if grep -q "Usage:" <<< "$help_output"; then
  assert_eq "help shows usage" "true" "true"
else
  assert_eq "help shows usage" "true" "false"
fi

# Test 2: missing args
echo "Test 2: missing args"
if "$BIN_DIR/clean.sh" 2>/dev/null; then
  assert_eq "exits with error" "false" "true"
else
  assert_eq "exits with error" "1" "1"
fi

# Test 3: clean a specific done task with dry-run
echo "Test 3: dry-run clean specific task"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
mkdir -p "$TMPDIR/worktree-done"
registry_add "$(jq -n --arg wt "$TMPDIR/worktree-done" '{id:"done-task",description:"Done",status:"done",worktree:$wt,tmuxSession:"agent-done-task",repo:"/tmp"}')"
dry_clean=$("$BIN_DIR/clean.sh" --task-id "done-task" --dry-run 2>/dev/null)
assert_eq "dry-run doesn't remove worktree" "true" "$([ -d "$TMPDIR/worktree-done" ] && echo true || echo false)"

# Test 4: actually clean a done task
echo "Test 4: clean done task"
"$BIN_DIR/clean.sh" --task-id "done-task" 2>/dev/null || true
status=$(jq -r '.tasks[] | select(.id == "done-task") | .status' "$REGISTRY_FILE")
assert_eq "task archived" "archived" "$status"

# Test 5: cleanup log written
echo "Test 5: cleanup log"
if [[ -f "$CLEANUP_LOG" ]]; then
  log_task=$(tail -1 "$CLEANUP_LOG" | jq -r '.taskId' 2>/dev/null || echo "")
  assert_eq "cleanup log has entry" "done-task" "$log_task"
else
  assert_eq "cleanup log exists" "true" "false"
fi

# Test 6: won't clean running tasks without --force
echo "Test 6: safety - won't clean running"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$(jq -n '{id:"running-task",description:"Running",status:"running",tmuxSession:"agent-running"}')"
"$BIN_DIR/clean.sh" --task-id "running-task" 2>/dev/null || true
running_status=$(jq -r '.tasks[] | select(.id == "running-task") | .status' "$REGISTRY_FILE")
assert_eq "running task not cleaned" "running" "$running_status"

# Test 7: --all-done cleans multiple
echo "Test 7: --all-done"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$(jq -n '{id:"done-1",description:"D1",status:"done"}')"
registry_add "$(jq -n '{id:"done-2",description:"D2",status:"done"}')"
registry_add "$(jq -n '{id:"running-1",description:"R1",status:"running"}')"
"$BIN_DIR/clean.sh" --all-done 2>/dev/null || true
done1_status=$(jq -r '.tasks[] | select(.id == "done-1") | .status' "$REGISTRY_FILE")
done2_status=$(jq -r '.tasks[] | select(.id == "done-2") | .status' "$REGISTRY_FILE")
running1_status=$(jq -r '.tasks[] | select(.id == "running-1") | .status' "$REGISTRY_FILE")
assert_eq "done-1 archived" "archived" "$done1_status"
assert_eq "done-2 archived" "archived" "$done2_status"
assert_eq "running-1 untouched" "running" "$running1_status"

# Test 8: --stale-days
echo "Test 8: --stale-days"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
OLD_MS=$(($(epoch_ms | tr -d '[:space:]') - 864000000))  # 10 days ago
registry_add "$(jq -n --argjson ts "$OLD_MS" '{id:"old-task",description:"Old",status:"done",startedAt:$ts}')"
registry_add "$(jq -n --argjson ts "$(epoch_ms)" '{id:"new-task",description:"New",status:"done",startedAt:$ts}')"
"$BIN_DIR/clean.sh" --stale-days 5 2>/dev/null || true
old_status=$(jq -r '.tasks[] | select(.id == "old-task") | .status' "$REGISTRY_FILE")
new_status=$(jq -r '.tasks[] | select(.id == "new-task") | .status' "$REGISTRY_FILE")
assert_eq "old task archived" "archived" "$old_status"
assert_eq "new task untouched" "done" "$new_status"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
