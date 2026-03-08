#!/usr/bin/env bash
# test-observability.sh — Test v0.9 observability features
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"
TUI_DIR="${SCRIPT_DIR}/../tui"

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

echo "=== test-observability.sh ==="

# Test 1: logs help
echo "Test 1: logs command"
logs_help=$("$BIN_DIR/logs.sh" --help 2>&1)
assert_contains "logs has usage" "Usage:" "$logs_help"
assert_contains "logs has --lines" "--lines" "$logs_help"
assert_contains "logs has --follow" "--follow" "$logs_help"
assert_contains "logs has --save" "--save" "$logs_help"
assert_contains "logs has --raw" "--raw" "$logs_help"

# Test 2: logs no args fails
echo "Test 2: logs missing args"
if ! "$BIN_DIR/logs.sh" 2>/dev/null; then
  echo "  ✅ logs no args fails"; PASS=$((PASS+1))
else
  echo "  ❌ logs no args should fail"; FAIL=$((FAIL+1))
fi

# Test 3: on-complete help
echo "Test 3: on-complete command"
oc_help=$("$BIN_DIR/on-complete.sh" --help 2>&1)
assert_contains "on-complete has usage" "Usage:" "$oc_help"
assert_contains "on-complete has --dry-run" "--dry-run" "$oc_help"
assert_contains "on-complete mentions webhook" "Webhook" "$oc_help"
assert_contains "on-complete mentions auto-clean" "auto-clean" "$oc_help"

# Test 4: CLI routes
echo "Test 4: CLI routing"
cli_help=$("$BIN_DIR/clawforge" help 2>&1)
assert_contains "help shows logs" "logs" "$cli_help"
assert_contains "help shows on-complete" "on-complete" "$cli_help"
assert_contains "help shows Observability" "Observability" "$cli_help"

# Test 5: TUI source has preview
echo "Test 5: TUI preview pane"
tui_src=$(cat "$TUI_DIR"/*.go)
assert_contains "TUI has showPreview" "showPreview" "$tui_src"
assert_contains "TUI has Preview field" "Preview" "$tui_src"
assert_contains "TUI has captureTmuxPreview" "captureTmuxPreview" "$tui_src"
assert_contains "TUI has p key handler" '"p"' "$tui_src"

# Test 6: TUI help has preview key
echo "Test 6: TUI help text"
tui_help=$("$BIN_DIR/clawforge-dashboard" --help 2>&1)
assert_contains "dashboard help shows p key" "preview" "$tui_help"

# Test 7: version
echo "Test 7: version"
version=$(cat "${SCRIPT_DIR}/../VERSION")
assert_eq "version is 1.6.2" "1.6.2" "$version"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
