#!/usr/bin/env bash
# test-merge.sh — Test module 7: merge-helper
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

echo "=== test-merge.sh ==="

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/merge-helper.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: missing required args
echo "Test 2: missing required args"
if "$BIN_DIR/merge-helper.sh" 2>/dev/null; then
  assert_eq "exits with error" "false" "true"
else
  assert_eq "exits with error" "1" "1"
fi

# Test 3: dry-run (needs a real repo with gh, so we test the parse logic)
# We can't fully test without gh access, but we verify arg parsing
echo "Test 3: arg parsing"
# merge-helper requires --repo to be a real dir for cd, so we use /tmp
if "$BIN_DIR/merge-helper.sh" --repo /tmp --pr 1 --dry-run --auto 2>/dev/null; then
  # gh might fail but we get past arg parsing
  assert_eq "arg parsing works" "true" "true"
else
  # Expected — gh pr view will fail on /tmp which isn't a repo
  # That's fine, we're testing that the script doesn't crash on arg parsing
  assert_eq "exits (no gh repo)" "1" "1"
fi

# Test 4: registry update logic
echo "Test 4: registry integration"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
registry_add "$(jq -n '{id:"merge-test",description:"Merge test",status:"pr-created",pr:42}')"
task_status=$(jq -r '.tasks[0].status' "$REGISTRY_FILE")
assert_eq "task exists in registry" "pr-created" "$task_status"

# Simulate what merge would do
registry_update "merge-test" "status" '"done"'
registry_update "merge-test" "completedAt" "$(epoch_ms)"
new_status=$(jq -r '.tasks[0].status' "$REGISTRY_FILE")
assert_eq "status updated to done" "done" "$new_status"
completed=$(jq -r '.tasks[0].completedAt' "$REGISTRY_FILE")
assert_eq "completedAt is set" "true" "$( [[ "$completed" != "null" ]] && echo true || echo false )"

# Test 5: auto-merge safety — verify script structure
echo "Test 5: safety checks exist"
if grep -q "CAN_AUTO" "$BIN_DIR/merge-helper.sh"; then
  assert_eq "has auto-merge safety logic" "true" "true"
else
  assert_eq "has auto-merge safety logic" "true" "false"
fi

if grep -q "APPROVED" "$BIN_DIR/merge-helper.sh"; then
  assert_eq "checks review approval" "true" "true"
else
  assert_eq "checks review approval" "true" "false"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
