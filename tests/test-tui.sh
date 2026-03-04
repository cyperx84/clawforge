#!/usr/bin/env bash
# test-tui.sh — Test the Go TUI dashboard binary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
TUI_DIR="${ROOT_DIR}/tui"
BINARY="${ROOT_DIR}/bin/clawforge-dashboard"
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

assert_source_contains() {
  local desc="$1" expected="$2"; shift 2
  if grep -rq "$expected" "$TUI_DIR"/*.go 2>/dev/null; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in source)"
    ((FAIL++)) || true
  fi
}

echo "=== test-tui.sh ==="

# Build test
echo "  Building Go TUI binary..."
if (cd "$TUI_DIR" && go build -o "$BINARY" . 2>&1); then
  echo "  ✅ binary builds"
  ((PASS++)) || true
else
  echo "  ❌ binary builds"
  ((FAIL++)) || true
  echo ""
  echo "  Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Binary exists and is executable
assert_ok "binary exists" test -f "$BINARY"
assert_ok "binary is executable" test -x "$BINARY"

# Help flag
assert_ok "help exits 0" "$BINARY" --help
assert_contains "help shows usage" "Usage:" "$BINARY" --help
assert_contains "help shows options" "Options:" "$BINARY" --help
assert_contains "help shows keybindings" "Keybindings:" "$BINARY" --help
assert_contains "help shows no-anim" "no-anim" "$BINARY" --help

# Keybinding strings in help
assert_contains "help shows j/k" "j/k" "$BINARY" --help
assert_contains "help shows Navigate" "Navigate" "$BINARY" --help
assert_contains "help shows Attach" "Attach" "$BINARY" --help
assert_contains "help shows Steer" "Steer" "$BINARY" --help
assert_contains "help shows Stop" "Stop" "$BINARY" --help
assert_contains "help shows Filter" "Filter" "$BINARY" --help
assert_contains "help shows help overlay" "help overlay" "$BINARY" --help
assert_contains "help shows Quit" "Quit" "$BINARY" --help

# Unknown flags fail
assert_fail "unknown flag fails" "$BINARY" --bogus

# Source code checks: keybindings present
assert_source_contains "source has j key handler" '"j"'
assert_source_contains "source has k key handler" '"k"'
assert_source_contains "source has q key handler" '"q"'
assert_source_contains "source has s key handler" '"s"'
assert_source_contains "source has x key handler" '"x"'
assert_source_contains "source has / key handler" '"/"'
assert_source_contains "source has Enter key handler" '"enter"'
assert_source_contains "source has r key handler" '"r"'
assert_source_contains "source has ? key handler" '"?"'
assert_source_contains "source has esc key handler" '"esc"'

# Source code checks: architecture
assert_source_contains "has alt screen" "AltScreen"
assert_source_contains "has refresh tick" "RefreshTickMsg"
assert_source_contains "has animation tick" "AnimationTickMsg"
assert_source_contains "has LoadAgents" "LoadAgents"
assert_source_contains "has tmux integration" "tmux"
assert_source_contains "has cost loading" "loadCosts"
assert_source_contains "has conflict loading" "loadConflictCounts"
assert_source_contains "has forge frames" "forgeFrames"

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
