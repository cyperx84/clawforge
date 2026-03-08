#!/usr/bin/env bash
# test-quick-run.sh — Tests for clawforge quick-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
QR="${SCRIPT_DIR}/../bin/quick-run.sh"

PASS=0 FAIL=0

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"; ((PASS++)) || true
  else
    echo "  ❌ $desc"; ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"; ((PASS++)) || true
  else
    echo "  ❌ $desc"; ((FAIL++)) || true
  fi
}

assert_contains() {
  local desc="$1" needle="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if grep -q "$needle" <<< "$output"; then
    echo "  ✅ $desc"; ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$needle' in output)"; ((FAIL++)) || true
  fi
}

echo "=== test-quick-run.sh ==="

# Test 1: script exists and is executable
echo "Test 1: script exists"
assert_ok "quick-run.sh exists" test -f "$QR"
assert_ok "quick-run.sh is executable" test -x "$QR"

# Test 2: --help
echo "Test 2: --help"
assert_ok "help exits 0" "$QR" --help
assert_contains "help shows usage"    "Usage:"           "$QR" --help
assert_contains "help shows --dir"    "\-\-dir"          "$QR" --help
assert_contains "help shows --agent"  "\-\-agent"        "$QR" --help
assert_contains "help shows --model"  "\-\-model"        "$QR" --help
assert_contains "help shows --save"   "\-\-save"         "$QR" --help
assert_contains "help shows --budget" "\-\-budget"       "$QR" --help
assert_contains "help shows --no-track" "\-\-no-track"   "$QR" --help
assert_contains "help shows --dry-run" "\-\-dry-run"     "$QR" --help

# Test 3: missing task fails
echo "Test 3: missing task"
assert_fail "no task fails" "$QR"

# Test 4: bad dir fails
echo "Test 4: bad dir"
assert_fail "nonexistent dir fails" "$QR" "task" --dir /nonexistent/path

# Test 5: dry-run
echo "Test 5: dry-run"
TMPDIR_TEST=$(mktemp -d)
assert_contains "dry-run shows task"      "task"        "$QR" "Explain the code" --dir "$TMPDIR_TEST" --dry-run
assert_contains "dry-run shows agent"     "agent\|claude\|codex" "$QR" "Explain the code" --dir "$TMPDIR_TEST" --dry-run
assert_contains "dry-run shows dir"       "$TMPDIR_TEST" "$QR" "Explain the code" --dir "$TMPDIR_TEST" --dry-run
assert_contains "dry-run shows model"     "model"       "$QR" "Explain the code" --dir "$TMPDIR_TEST" --dry-run
assert_contains "dry-run no-track shows no" "no"        "$QR" "Explain the code" --dir "$TMPDIR_TEST" --dry-run --no-track
rm -rf "$TMPDIR_TEST"

# Test 6: CLI routes quick-run
echo "Test 6: CLI routing"
assert_contains "CLI help shows quick-run" "quick-run"  "$CLI" help
assert_contains "CLI routes to script"    "Usage:"      "$CLI" quick-run --help

# Test 7: dry-run with options
echo "Test 7: dry-run with budget + save"
TMPDIR_TEST=$(mktemp -d)
assert_contains "dry-run shows budget" "Budget" \
  "$QR" "Fix the bug" --dir "$TMPDIR_TEST" --dry-run --budget 1.50
assert_contains "dry-run shows save path" "/tmp" \
  "$QR" "Fix the bug" --dir "$TMPDIR_TEST" --dry-run --save /tmp/out.log
rm -rf "$TMPDIR_TEST"

# Test 8: registry + log setup (with --no-track, no agent needed)
echo "Test 8: source inspection"
assert_contains "has epoch_ms"          "epoch_ms"     cat "$QR"
assert_contains "has registry_add"      "registry_add" cat "$QR"
assert_contains "has log_path"          "log_path"     cat "$QR"
assert_contains "has tee"               "tee"          cat "$QR"
assert_contains "has quick-run mode"    "quick-run"    cat "$QR"
assert_contains "has detect_agent"      "detect_agent" cat "$QR"
assert_contains "has no-track flag"     "NO_TRACK"     cat "$QR"
assert_contains "has budget flag"       "BUDGET"       cat "$QR"
assert_contains "has save flag"         "SAVE_PATH"    cat "$QR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
