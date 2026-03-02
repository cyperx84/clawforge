#!/usr/bin/env bash
# test-modes.sh — Test v0.4 mode routing: sprint, review, swarm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""
TMPDIR=""

cleanup() {
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
  if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
    # Remove worktrees
    git -C "$TMPDIR/repo" worktree list --porcelain 2>/dev/null | grep "^worktree " | while read -r _ wt; do
      [[ "$wt" != "$TMPDIR/repo" ]] && git -C "$TMPDIR/repo" worktree remove "$wt" --force 2>/dev/null || true
    done
    rm -rf "$TMPDIR"
  fi
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

echo "=== test-modes.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# Setup: create temp git repo
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/repo"
git -C "$TMPDIR/repo" init -b main >/dev/null 2>&1
echo "test" > "$TMPDIR/repo/README.md"
git -C "$TMPDIR/repo" add -A
git -C "$TMPDIR/repo" -c commit.gpgsign=false commit -m "init" >/dev/null 2>&1

# ── CLI routing tests ─────────────────────────────────────────────
echo "Test 1: CLI routing"
assert_ok "sprint --help routes" "$CLI" sprint --help
assert_ok "review --help routes" "$CLI" review --help
assert_ok "swarm --help routes" "$CLI" swarm --help

# ── Help display tests ────────────────────────────────────────────
echo "Test 2: help displays"
assert_contains "help shows sprint" "sprint" "$CLI" help
assert_contains "help shows review" "review" "$CLI" help
assert_contains "help shows swarm" "swarm" "$CLI" help
assert_contains "help shows steer" "steer" "$CLI" help
assert_contains "help shows attach" "attach" "$CLI" help
assert_contains "help shows stop" "stop" "$CLI" help

# help --all shows module commands
assert_contains "help --all shows scope" "scope" "$CLI" help --all
assert_contains "help --all shows spawn" "spawn" "$CLI" help --all
assert_contains "help --all shows notify" "notify" "$CLI" help --all

# ── Sprint tests ──────────────────────────────────────────────────
echo "Test 3: sprint --help"
assert_contains "sprint help shows usage" "Usage:" "$BIN_DIR/sprint.sh" --help
assert_contains "sprint help shows --quick" "quick" "$BIN_DIR/sprint.sh" --help
assert_contains "sprint help shows --dry-run" "dry-run" "$BIN_DIR/sprint.sh" --help

echo "Test 4: sprint missing args"
assert_fail "sprint no args fails" "$BIN_DIR/sprint.sh"

echo "Test 5: sprint dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/sprint.sh" "$TMPDIR/repo" "Add JWT auth" --dry-run 2>&1 || true)
assert_contains "dry-run shows task" "Add JWT auth" echo "$output"
assert_contains "dry-run shows repo" "$TMPDIR/repo" echo "$output"
assert_contains "dry-run shows branch" "sprint/" echo "$output"

echo "Test 6: sprint --quick dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/sprint.sh" "$TMPDIR/repo" "Fix typo" --quick --dry-run 2>&1 || true)
assert_contains "quick dry-run shows mode" "quick" echo "$output"
assert_contains "quick dry-run shows auto-merge" "Auto-merge: true" echo "$output"

# ── Review mode tests ────────────────────────────────────────────
echo "Test 7: review-mode --help"
assert_contains "review help shows usage" "Usage:" "$BIN_DIR/review-mode.sh" --help
assert_contains "review help shows --pr" "pr" "$BIN_DIR/review-mode.sh" --help
assert_contains "review help shows --fix" "fix" "$BIN_DIR/review-mode.sh" --help

echo "Test 8: review missing --pr"
assert_fail "review no --pr fails" "$BIN_DIR/review-mode.sh" "$TMPDIR/repo"

# ── Swarm tests ───────────────────────────────────────────────────
echo "Test 9: swarm --help"
assert_contains "swarm help shows usage" "Usage:" "$BIN_DIR/swarm.sh" --help
assert_contains "swarm help shows --max-agents" "max-agents" "$BIN_DIR/swarm.sh" --help

echo "Test 10: swarm missing args"
assert_fail "swarm no args fails" "$BIN_DIR/swarm.sh"

echo "Test 11: swarm dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/swarm.sh" "$TMPDIR/repo" "Migrate tests" --dry-run 2>&1 || true)
assert_contains "swarm dry-run shows task" "Migrate tests" echo "$output"
assert_contains "swarm dry-run shows decomposition" "Decomposition" echo "$output"
assert_contains "swarm dry-run shows sub-tasks" "Sub-tasks:" echo "$output"

# Check registry has parent task
parent_mode=$(jq -r '.tasks[0].mode // empty' "$REGISTRY_FILE")
assert_eq "swarm parent registered" "swarm" "$parent_mode"
parent_sid=$(jq -r '.tasks[0].short_id // empty' "$REGISTRY_FILE")
assert_eq "swarm parent has short_id" "1" "$parent_sid"

# ── Status with modes ─────────────────────────────────────────────
echo "Test 12: status with modes"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
TASK1='{"id":"sprint-test","short_id":1,"mode":"sprint","tmuxSession":"","agent":"claude","model":"claude-sonnet-4-5","description":"Test sprint","repo":"/tmp","worktree":"","branch":"sprint/test","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK1" 2>/dev/null
output=$("$CLI" status 2>&1 || true)
assert_contains "status shows short ID" "#1" echo "$output"
assert_contains "status shows mode" "sprint" echo "$output"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
