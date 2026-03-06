#!/usr/bin/env bash
# test-review.sh — Test module 5: review-pr
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0

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

echo "=== test-review.sh ==="

# Test 1: --help flag
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/review-pr.sh" --help 2>&1 || true)
if grep -q "Usage:" <<< "$help_output"; then
  assert_eq "help shows usage" "true" "true"
else
  assert_eq "help shows usage" "true" "false"
fi

# Test 2: missing required args
echo "Test 2: missing required args"
if "$BIN_DIR/review-pr.sh" 2>/dev/null; then
  assert_eq "exits with error on missing args" "false" "true"
else
  assert_eq "exits with error on missing args" "1" "1"
fi

# Test 3: dry-run with fake repo
echo "Test 3: dry-run mode"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/repo"
git -C "$TMPDIR/repo" init -b main >/dev/null 2>&1
echo "test" > "$TMPDIR/repo/README.md"
git -C "$TMPDIR/repo" add -A
git -C "$TMPDIR/repo" -c commit.gpgsign=false commit -m "init" >/dev/null 2>&1

output=$("$BIN_DIR/review-pr.sh" --repo "$TMPDIR/repo" --pr 1 --dry-run 2>/dev/null || true)
if echo "$output" | jq -e '.[0].reviewer' >/dev/null 2>&1; then
  assert_eq "dry-run produces review structure" "true" "true"
else
  assert_eq "dry-run produces review structure" "true" "false"
fi

# Test 4: custom reviewers
echo "Test 4: custom reviewers"
output=$("$BIN_DIR/review-pr.sh" --repo "$TMPDIR/repo" --pr 1 --reviewers "claude,gemini" --dry-run 2>/dev/null || true)
reviewer_count=$(echo "$output" | jq 'length' 2>/dev/null || echo 0)
assert_eq "two reviewers" "2" "$reviewer_count"

first_reviewer=$(echo "$output" | jq -r '.[0].reviewer' 2>/dev/null || echo "")
assert_eq "first reviewer is claude" "claude" "$first_reviewer"

second_reviewer=$(echo "$output" | jq -r '.[1].reviewer' 2>/dev/null || echo "")
assert_eq "second reviewer is gemini" "gemini" "$second_reviewer"

rm -rf "$TMPDIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
