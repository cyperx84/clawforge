#!/usr/bin/env bash
# test-management.sh — Test v0.4 management commands: steer, attach, stop, daemon
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""
TMUX_SESSION=""

cleanup() {
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
  [[ -n "$TMUX_SESSION" ]] && tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  rm -f "${CLAWFORGE_DIR}/watch.pid"
}
trap cleanup EXIT

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local desc="$1" expected="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    FAIL=$((FAIL+1))
  fi
}

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

echo "=== test-management.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# ── Help tests ────────────────────────────────────────────────────
echo "Test 1: --help flags"
assert_ok "steer --help" "$BIN_DIR/steer.sh" --help
assert_ok "attach --help" "$BIN_DIR/attach.sh" --help
assert_ok "stop --help" "$BIN_DIR/stop.sh" --help

assert_contains "steer help shows usage" "Usage:" "$BIN_DIR/steer.sh" --help
assert_contains "attach help shows usage" "Usage:" "$BIN_DIR/attach.sh" --help
assert_contains "stop help shows usage" "Usage:" "$BIN_DIR/stop.sh" --help

# ── CLI routing ───────────────────────────────────────────────────
echo "Test 2: CLI routing"
assert_ok "steer --help routes" "$CLI" steer --help
assert_ok "attach --help routes" "$CLI" attach --help
assert_ok "stop --help routes" "$CLI" stop --help

# ── Steer tests ───────────────────────────────────────────────────
echo "Test 3: steer missing args"
assert_fail "steer no args fails" "$BIN_DIR/steer.sh"
assert_fail "steer no message fails" "$BIN_DIR/steer.sh" 1

echo "Test 4: steer with done task"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
TASK_DONE='{"id":"done-task","short_id":1,"mode":"sprint","tmuxSession":"agent-done","agent":"claude","model":"m","description":"Done task","repo":"/tmp","worktree":"","branch":"b","startedAt":1000,"status":"done","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":2000,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK_DONE" 2>/dev/null
output=$("$BIN_DIR/steer.sh" 1 "test message" 2>&1 || true)
assert_contains "steer done task warns" "already done" echo "$output"

echo "Test 5: steer with running task (tmux live)"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
TMUX_SESSION="clawforge-test-steer-$$"
tmux new-session -d -s "$TMUX_SESSION" "sleep 60" 2>/dev/null || true
TASK_RUN='{"id":"steer-test","short_id":1,"mode":"sprint","tmuxSession":"'"$TMUX_SESSION"'","agent":"claude","model":"m","description":"Running task","repo":"/tmp","worktree":"","branch":"b","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK_RUN" 2>/dev/null
output=$("$BIN_DIR/steer.sh" 1 "Use bcrypt" 2>&1 || true)
assert_contains "steer sends to session" "Sent to:" echo "$output"

# Check steer_log was recorded
steer_log=$(registry_get "steer-test" | jq -r '.steer_log // "[]"' | jq 'length')
assert_eq "steer_log recorded" "1" "$steer_log"

# ── Stop tests ────────────────────────────────────────────────────
echo "Test 6: stop missing args"
assert_fail "stop no args fails" "$BIN_DIR/stop.sh"

echo "Test 7: stop with --yes"
# Task from steer test is still running
output=$("$BIN_DIR/stop.sh" 1 --yes 2>&1 || true)
assert_contains "stop confirms" "Stopped:" echo "$output"

# Check status in registry
stop_status=$(registry_get "steer-test" | jq -r '.status')
assert_eq "stopped status" "stopped" "$stop_status"
stop_completed=$(registry_get "steer-test" | jq -r '.completedAt')
if [[ "$stop_completed" != "null" && -n "$stop_completed" ]]; then
  assert_eq "completedAt set" "true" "true"
else
  assert_eq "completedAt set" "true" "false"
fi

# tmux session should be dead
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  assert_eq "tmux killed" "dead" "alive"
else
  assert_eq "tmux killed" "dead" "dead"
fi
TMUX_SESSION="" # Don't try cleanup since it's already dead

echo "Test 8: stop already stopped"
output=$("$BIN_DIR/stop.sh" 1 --yes 2>&1 || true)
assert_contains "already stopped msg" "already stopped" echo "$output"

# ── Attach tests ──────────────────────────────────────────────────
echo "Test 9: attach missing args"
assert_fail "attach no args fails" "$BIN_DIR/attach.sh"

echo "Test 10: attach no tmux session"
output=$("$BIN_DIR/attach.sh" 1 2>&1 || true)
assert_contains "attach dead session warns" "not found" echo "$output"

# ── Watch daemon tests ────────────────────────────────────────────
echo "Test 11: watch --help shows daemon"
assert_contains "watch help shows --daemon" "daemon" "$BIN_DIR/check-agents.sh" --help
assert_contains "watch help shows --stop" "stop" "$BIN_DIR/check-agents.sh" --help
assert_contains "watch help shows --interval" "interval" "$BIN_DIR/check-agents.sh" --help

echo "Test 12: watch --stop (no daemon)"
output=$("$BIN_DIR/check-agents.sh" --stop 2>&1 || true)
assert_contains "stop no daemon" "No daemon" echo "$output"

# ── Short ID resolution across management commands ────────────────
echo "Test 13: short ID resolution"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
TASK_A='{"id":"task-alpha","short_id":42,"mode":"sprint","tmuxSession":"","agent":"claude","model":"m","description":"Alpha task","repo":"/tmp","worktree":"","branch":"b","startedAt":1000,"status":"done","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":2000,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK_A" 2>/dev/null

# resolve_task_id should find it
resolved=$(resolve_task_id "42")
assert_eq "resolve #42 → task-alpha" "task-alpha" "$resolved"

resolved=$(resolve_task_id "#42")
assert_eq "resolve with hash #42" "task-alpha" "$resolved"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
