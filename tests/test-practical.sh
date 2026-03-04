#!/usr/bin/env bash
# test-practical.sh — Test v1.1 practical features
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-practical.sh ==="

# Test 1: resume help
echo "Test 1: resume command"
help=$("$BIN_DIR/resume.sh" --help 2>&1)
assert_contains "resume has usage" "Usage:" "$help"
assert_contains "resume has --context-lines" "--context-lines" "$help"
assert_contains "resume has --message" "--message" "$help"
assert_contains "resume has --dry-run" "--dry-run" "$help"

# Test 2: resume no args
echo "Test 2: resume missing args"
if ! "$BIN_DIR/resume.sh" 2>/dev/null; then
  echo "  ✅ resume no args fails"; PASS=$((PASS+1))
else
  echo "  ❌ resume no args should fail"; FAIL=$((FAIL+1))
fi

# Test 3: diff help
echo "Test 3: diff command"
help=$("$BIN_DIR/diff.sh" --help 2>&1)
assert_contains "diff has usage" "Usage:" "$help"
assert_contains "diff has --stat" "--stat" "$help"
assert_contains "diff has --staged" "--staged" "$help"
assert_contains "diff has --save" "--save" "$help"
assert_contains "diff has --name-only" "--name-only" "$help"

# Test 4: diff no args
echo "Test 4: diff missing args"
if ! "$BIN_DIR/diff.sh" 2>/dev/null; then
  echo "  ✅ diff no args fails"; PASS=$((PASS+1))
else
  echo "  ❌ diff no args should fail"; FAIL=$((FAIL+1))
fi

# Test 5: pr help
echo "Test 5: pr command"
help=$("$BIN_DIR/pr.sh" --help 2>&1)
assert_contains "pr has usage" "Usage:" "$help"
assert_contains "pr has --title" "--title" "$help"
assert_contains "pr has --draft" "--draft" "$help"
assert_contains "pr has --base" "--base" "$help"
assert_contains "pr has --reviewers" "--reviewers" "$help"
assert_contains "pr has --labels" "--labels" "$help"
assert_contains "pr has --dry-run" "--dry-run" "$help"

# Test 6: pr no args
echo "Test 6: pr missing args"
if ! "$BIN_DIR/pr.sh" 2>/dev/null; then
  echo "  ✅ pr no args fails"; PASS=$((PASS+1))
else
  echo "  ❌ pr no args should fail"; FAIL=$((FAIL+1))
fi

# Test 7: CLI routing
echo "Test 7: CLI routing"
cli_help=$("$BIN_DIR/clawforge" help 2>&1)
assert_contains "help shows resume" "resume" "$cli_help"
assert_contains "help shows diff" "diff" "$cli_help"
assert_contains "help shows pr" "pr" "$cli_help"

# Test 8: watch daemon has on-complete wiring
echo "Test 8: watch daemon on-complete"
watch_src=$(cat "$BIN_DIR/check-agents.sh")
assert_contains "watch fires on-complete" "on-complete.sh" "$watch_src"
assert_contains "watch checks terminal states" "done|failed|timeout|cancelled" "$watch_src"

# Test 9: version
echo "Test 9: version"
version=$(cat "${SCRIPT_DIR}/../VERSION")
assert_eq "version is 1.5.2" "1.5.2" "$version"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
