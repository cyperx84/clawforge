#!/usr/bin/env bash
# test-cli.sh — Test the clawforge CLI wrapper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
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
  if echo "$output" | grep -q "$expected"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    ((FAIL++)) || true
  fi
}

echo "=== test-cli: CLI wrapper ==="

# Basic meta commands
assert_ok "help exits 0" "$CLI" help
assert_ok "--help exits 0" "$CLI" --help
assert_ok "version exits 0" "$CLI" version
assert_ok "--version exits 0" "$CLI" --version

# Output content checks
assert_contains "help shows commands" "Commands:" "$CLI" help
assert_contains "help shows scope" "scope" "$CLI" help
assert_contains "help shows spawn" "spawn" "$CLI" help
assert_contains "help shows run" "run" "$CLI" help
assert_contains "help shows dashboard" "dashboard" "$CLI" help
assert_contains "version shows v" "clawforge v" "$CLI" version

# Unknown command fails
assert_fail "unknown command fails" "$CLI" nonexistent_command

# Subcommand routing — verify they reach the right script (use --help)
assert_ok "scope --help routes" "$CLI" scope --help
assert_ok "spawn --help routes" "$CLI" spawn --help
assert_ok "watch --help routes" "$CLI" watch --help
assert_ok "review --help routes" "$CLI" review --help
assert_ok "notify --help routes" "$CLI" notify --help
assert_ok "merge --help routes" "$CLI" merge --help
assert_ok "clean --help routes" "$CLI" clean --help
assert_ok "learn --help routes" "$CLI" learn --help

# Status works (empty registry is fine)
assert_ok "status works" "$CLI" status

# Dashboard works
assert_ok "dashboard works" "$CLI" dashboard

# Run without args fails gracefully
assert_fail "run without args fails" "$CLI" run

# Verbose flag doesn't break things
assert_ok "verbose + help works" "$CLI" --verbose help
assert_ok "verbose + version works" "$CLI" --verbose version

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
