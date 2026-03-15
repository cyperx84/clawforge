#!/usr/bin/env bash
# test-fleet-status.sh — Tests for fleet-status command
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/test-helpers.sh"

BIN="${SCRIPT_DIR}/../bin/clawforge"

suite "fleet-status"

test_case "help flag works" && {
  out=$("$BIN" status --help 2>&1)
  assert_contains "$out" "Usage: clawforge status"
  assert_contains "$out" "--json"
  pass
}

test_case "runs without error against real fleet" && {
  out=$("$BIN" status 2>&1)
  assert_contains "$out" "ClawForge Fleet"
  pass
}

test_case "json output is valid JSON" && {
  out=$("$BIN" status --json 2>&1)
  echo "$out" | jq . > /dev/null 2>&1 || fail "Not valid JSON"
  pass
}

test_case "single agent lookup" && {
  # Get first agent id from fleet
  agent_id=$("$BIN" list --json 2>/dev/null | jq -r '.[0].id // empty' 2>/dev/null || echo "")
  if [[ -z "$agent_id" ]]; then
    skip "No agents in fleet"
  fi
  out=$("$BIN" status "$agent_id" 2>&1)
  assert_contains "$out" "$agent_id"
  pass
}

test_case "unknown agent exits non-zero" && {
  "$BIN" status "no-such-agent-xyz" 2>&1 && fail "Should have exited non-zero" || pass
}

summary
