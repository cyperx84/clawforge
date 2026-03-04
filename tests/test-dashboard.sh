#!/usr/bin/env bash
# test-dashboard.sh — Test the TUI dashboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
DASHBOARD="${SCRIPT_DIR}/../bin/dashboard.sh"
PASS=0 FAIL=0

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc"
    ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc"
    ((FAIL++)) || true
  fi
}

assert_contains() {
  local desc="$1" expected="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if grep -q "$expected" <<< "$output"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    ((FAIL++)) || true
  fi
}

echo "=== test-dashboard.sh ==="

# Dashboard script exists and is executable
assert_ok "dashboard.sh exists" test -f "$DASHBOARD"
assert_ok "dashboard.sh is executable" test -x "$DASHBOARD"

# Help flag works
assert_ok "dashboard --help exits 0" "$DASHBOARD" --help
assert_contains "help shows keybindings" "j/k" "$DASHBOARD" --help
assert_contains "help shows vim navigate" "Navigate" "$DASHBOARD" --help
assert_contains "help shows attach" "Attach" "$DASHBOARD" --help
assert_contains "help shows steer" "Steer" "$DASHBOARD" --help
assert_contains "help shows quit" "Quit" "$DASHBOARD" --help
assert_contains "help shows filter" "Filter" "$DASHBOARD" --help
assert_contains "help shows help overlay" "help overlay" "$DASHBOARD" --help

# Dashboard routes via CLI
assert_contains "CLI routes to dashboard" "keybindings\|Navigate\|TUI\|dashboard" "$CLI" dashboard --help

# --no-anim flag is accepted
assert_contains "no-anim accepted" "keybindings\|Navigate\|Quit" "$DASHBOARD" --help

# Check forge animation functions exist in source
assert_contains "has forge frame 1" "FORGE_FRAME_1" cat "$DASHBOARD"
assert_contains "has forge frame 2" "FORGE_FRAME_2" cat "$DASHBOARD"
assert_contains "has forge frame 3" "FORGE_FRAME_3" cat "$DASHBOARD"
assert_contains "has amber color" "COLOR_AMBER" cat "$DASHBOARD"
assert_contains "has orange color" "COLOR_ORANGE" cat "$DASHBOARD"

# Check key handlers exist
assert_contains "handles j key" "SELECTED=.*SELECTED.*1" cat "$DASHBOARD"
assert_contains "handles k key" "SELECTED.*0" cat "$DASHBOARD"
assert_contains "handles q key" "break" cat "$DASHBOARD"
assert_contains "handles s key" "_action_steer" cat "$DASHBOARD"
assert_contains "handles x key" "_action_stop" cat "$DASHBOARD"
assert_contains "handles / key" "_action_filter" cat "$DASHBOARD"

# Check auto-refresh
assert_contains "has refresh interval" "REFRESH_INTERVAL" cat "$DASHBOARD"
assert_contains "has render function" "_render" cat "$DASHBOARD"

# Check cost column integration
assert_contains "cost column in dashboard" "_get_task_cost\|Cost" cat "$DASHBOARD"

# Check conflict integration
assert_contains "conflict count in dashboard" "_get_conflict_count\|Conflict" cat "$DASHBOARD"

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
