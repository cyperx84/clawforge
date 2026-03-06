#!/usr/bin/env bash
# test-memory.sh — Test agent memory (Feature 3)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
TEST_REPO_NAME="test-memory-repo-$$"
MEMORY_BASE="$HOME/.clawforge/memory"
MEMORY_FILE="${MEMORY_BASE}/${TEST_REPO_NAME}.jsonl"

cleanup() {
  rm -f "$MEMORY_FILE"
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
  if grep -qF "$needle" <<< "$haystack"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-memory.sh ==="

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/memory.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: add a memory
echo "Test 2: add memory"
output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" add "Always run tests before merging" 2>/dev/null)
added_text=$(echo "$output" | jq -r '.text')
assert_eq "text matches" "Always run tests before merging" "$added_text"
added_source=$(echo "$output" | jq -r '.source')
assert_eq "source is manual" "manual" "$added_source"

# Test 3: add with tags
echo "Test 3: add with tags"
output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" --tags "ci,testing" add "CI uses vitest" 2>/dev/null)
tags=$(echo "$output" | jq -r '.tags | join(",")')
assert_eq "tags set" "ci,testing" "$tags"

# Test 4: add with custom source
echo "Test 4: add with custom source"
output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" --source "ci-fail" add "Flaky test in auth.spec" 2>/dev/null)
src=$(echo "$output" | jq -r '.source')
assert_eq "source is ci-fail" "ci-fail" "$src"

# Test 5: show all memories
echo "Test 5: show"
show_output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" show 2>/dev/null)
assert_contains "shows first memory" "Always run tests" "$show_output"
assert_contains "shows second memory" "CI uses vitest" "$show_output"
assert_contains "shows third memory" "Flaky test" "$show_output"

# Test 6: search
echo "Test 6: search"
search_output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" search "vitest" 2>/dev/null)
assert_contains "finds vitest memory" "vitest" "$search_output"

# Test 7: stats (default subcommand)
echo "Test 7: stats"
stats_output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" 2>/dev/null)
assert_contains "shows entry count" "3 entries" "$stats_output"
assert_contains "shows repo name" "$TEST_REPO_NAME" "$stats_output"

# Test 8: forget
echo "Test 8: forget"
id_to_forget=$(head -1 "$MEMORY_FILE" | jq -r '.id')
forget_output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" forget --id "$id_to_forget" 2>/dev/null)
assert_contains "confirms removal" "Removed" "$forget_output"
remaining=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
assert_eq "2 entries remain" "2" "$remaining"

# Test 9: clear
echo "Test 9: clear"
clear_output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" clear 2>/dev/null)
assert_contains "confirms clear" "Cleared" "$clear_output"
assert_eq "file removed" "false" "$([ -f "$MEMORY_FILE" ] && echo true || echo false)"

# Test 10: show on empty repo
echo "Test 10: show empty"
empty_output=$("$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" show 2>/dev/null)
assert_contains "says no memories" "No memories" "$empty_output"

# Test 11: JSONL format validity
echo "Test 11: JSONL format"
"$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" add "Entry one" 2>/dev/null >/dev/null
"$BIN_DIR/memory.sh" --repo-name "$TEST_REPO_NAME" add "Entry two" 2>/dev/null >/dev/null
valid=true
while IFS= read -r line; do
  if ! echo "$line" | jq . >/dev/null 2>&1; then
    valid=false
    break
  fi
done < "$MEMORY_FILE"
assert_eq "all lines valid JSON" "true" "$valid"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
