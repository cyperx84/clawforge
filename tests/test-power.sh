#!/usr/bin/env bash
# test-power.sh — Test v1.2 power features
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
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

echo "=== test-power.sh ==="

# Test 1: config help
echo "Test 1: config command"
help=$("$BIN_DIR/config.sh" --help 2>&1)
assert_contains "config has usage" "Usage:" "$help"
assert_contains "config has show" "show" "$help"
assert_contains "config has set" "set" "$help"
assert_contains "config has init" "init" "$help"
assert_contains "config mentions review_models" "review_models" "$help"

# Test 2: config set/get
echo "Test 2: config set/get"
"$BIN_DIR/config.sh" set test_key test_value 2>/dev/null
val=$("$BIN_DIR/config.sh" get test_key 2>/dev/null)
assert_eq "config set/get works" "test_value" "$val"
"$BIN_DIR/config.sh" unset test_key 2>/dev/null

# Test 3: config show
echo "Test 3: config show"
show=$("$BIN_DIR/config.sh" show 2>&1)
assert_contains "config show has user" "User config" "$show"
assert_contains "config show has defaults" "Project defaults" "$show"

# Test 4: config path
echo "Test 4: config path"
path=$("$BIN_DIR/config.sh" path 2>&1)
assert_contains "config path correct" ".clawforge/config.json" "$path"

# Test 5: multi-review help
echo "Test 5: multi-review command"
help=$("$BIN_DIR/multi-review.sh" --help 2>&1)
assert_contains "multi-review has usage" "Usage:" "$help"
assert_contains "multi-review has --pr" "--pr" "$help"
assert_contains "multi-review has --models" "--models" "$help"
assert_contains "multi-review has --diff-only" "--diff-only" "$help"

# Test 6: multi-review missing --pr
echo "Test 6: multi-review missing args"
if ! "$BIN_DIR/multi-review.sh" 2>/dev/null; then
  echo "  ✅ multi-review no --pr fails"; PASS=$((PASS+1))
else
  echo "  ❌ should fail"; FAIL=$((FAIL+1))
fi

# Test 7: summary help
echo "Test 7: summary command"
help=$("$BIN_DIR/summary.sh" --help 2>&1)
assert_contains "summary has usage" "Usage:" "$help"
assert_contains "summary has --model" "--model" "$help"
assert_contains "summary has --format" "--format" "$help"
assert_contains "summary has --include-diff" "--include-diff" "$help"

# Test 8: summary missing args
echo "Test 8: summary missing args"
if ! "$BIN_DIR/summary.sh" 2>/dev/null; then
  echo "  ✅ summary no args fails"; PASS=$((PASS+1))
else
  echo "  ❌ should fail"; FAIL=$((FAIL+1))
fi

# Test 9: parse-cost help
echo "Test 9: parse-cost command"
help=$("$BIN_DIR/parse-cost.sh" --help 2>&1)
assert_contains "parse-cost has usage" "Usage:" "$help"
assert_contains "parse-cost has --update" "--update" "$help"
assert_contains "parse-cost has --lines" "--lines" "$help"

# Test 10: parse-cost missing args
echo "Test 10: parse-cost missing args"
if ! "$BIN_DIR/parse-cost.sh" 2>/dev/null; then
  echo "  ✅ parse-cost no args fails"; PASS=$((PASS+1))
else
  echo "  ❌ should fail"; FAIL=$((FAIL+1))
fi

# Test 11: common.sh has config_set
echo "Test 11: common.sh config functions"
common=$(cat "$SCRIPT_DIR/../lib/common.sh")
assert_contains "has config_set" "config_set" "$common"
assert_contains "has config_list" "config_list" "$common"
assert_contains "has USER_CONFIG_FILE" "USER_CONFIG_FILE" "$common"

# Test 12: CLI routing
echo "Test 12: CLI routing"
cli_help=$("$BIN_DIR/clawforge" help 2>&1)
assert_contains "help shows config" "config" "$cli_help"
assert_contains "help shows multi-review" "multi-review" "$cli_help"
assert_contains "help shows summary" "summary" "$cli_help"
assert_contains "help shows parse-cost" "parse-cost" "$cli_help"
assert_contains "help shows Power Features" "Power Features" "$cli_help"

# Test 13: version
echo "Test 13: version"
version=$(cat "${SCRIPT_DIR}/../VERSION")
assert_eq "version is 1.5.1" "1.5.1" "$version"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
