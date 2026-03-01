#!/usr/bin/env bash
# test-spawn.sh — Test module 2: spawn-agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
TMPDIR=""

cleanup() {
  if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
    # Remove worktree first
    git -C "$TMPDIR/repo" worktree remove "$TMPDIR/worktrees/test-feature" --force 2>/dev/null || true
    rm -rf "$TMPDIR"
  fi
  # Reset registry
  echo '{"tasks":[]}' > "$REGISTRY_FILE"
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

assert_not_empty() {
  local desc="$1" val="$2"
  if [[ -n "$val" ]]; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (empty)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== test-spawn.sh ==="

# Setup: create temp git repo
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/repo"
git -C "$TMPDIR/repo" init -b main >/dev/null 2>&1
echo "test" > "$TMPDIR/repo/README.md"
git -C "$TMPDIR/repo" add -A
git -C "$TMPDIR/repo" -c commit.gpgsign=false commit -m "init" >/dev/null 2>&1

# Reset registry
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# Test 1: --help flag
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/spawn-agent.sh" --help 2>&1 || true)
if echo "$help_output" | grep -q "Usage:"; then
  assert_eq "help shows usage" "true" "true"
else
  assert_eq "help shows usage" "true" "false"
fi

# Test 2: missing required args
echo "Test 2: missing required args"
if "$BIN_DIR/spawn-agent.sh" 2>/dev/null; then
  assert_eq "exits with error on missing args" "false" "true"
else
  assert_eq "exits with error on missing args" "1" "1"
fi

# Test 3: dry-run creates worktree and registry entry
echo "Test 3: dry-run spawn"
"$BIN_DIR/spawn-agent.sh" \
  --repo "$TMPDIR/repo" \
  --branch "test-feature" \
  --task "Test task description" \
  --dry-run >/dev/null 2>&1

# Check worktree exists
if [[ -d "$TMPDIR/worktrees/test-feature" ]]; then
  assert_eq "worktree created" "true" "true"
else
  assert_eq "worktree created" "true" "false"
fi

# Check registry entry
task_id=$(jq -r '.tasks[0].id // empty' "$REGISTRY_FILE")
assert_not_empty "registry entry created" "$task_id"

task_status=$(jq -r '.tasks[0].status' "$REGISTRY_FILE")
assert_eq "task status is running" "running" "$task_status"

task_agent=$(jq -r '.tasks[0].agent' "$REGISTRY_FILE")
assert_not_empty "agent set" "$task_agent"

task_desc=$(jq -r '.tasks[0].description' "$REGISTRY_FILE")
assert_eq "description preserved" "Test task description" "$task_desc"

# Test 4: idempotent (second run with same branch)
echo "Test 4: idempotent re-run"
# Reset registry first
echo '{"tasks":[]}' > "$REGISTRY_FILE"
"$BIN_DIR/spawn-agent.sh" \
  --repo "$TMPDIR/repo" \
  --branch "test-feature" \
  --task "Second run" \
  --dry-run >/dev/null 2>&1
task_count=$(jq '.tasks | length' "$REGISTRY_FILE")
assert_eq "registry has entry after re-run" "1" "$task_count"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
