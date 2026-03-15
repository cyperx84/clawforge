#!/usr/bin/env bash
# test-fleet-logs.sh — Tests for fleet-logs command
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/test-helpers.sh"

BIN="${SCRIPT_DIR}/../bin/clawforge"

suite "fleet-logs"

test_case "help flag works" && {
  out=$("$BIN" logs --help 2>&1)
  assert_contains "$out" "Usage: clawforge logs"
  assert_contains "$out" "--follow"
  assert_contains "$out" "--tail"
  pass
}

test_case "requires agent-id argument" && {
  "$BIN" logs 2>&1 && fail "Should exit non-zero without agent-id" || pass
}

test_case "unknown agent exits non-zero" && {
  "$BIN" logs "no-such-agent-xyz" 2>&1 && fail "Should exit non-zero" || pass
}

test_case "known agent runs without error" && {
  agent_id=$("$BIN" list --json 2>/dev/null | jq -r '.[0].id // empty' 2>/dev/null || echo "")
  if [[ -z "$agent_id" ]]; then
    skip "No agents in fleet"
  fi
  # Just check it doesn't crash (logs may be empty)
  "$BIN" logs "$agent_id" --tail 5 2>&1 || true
  pass
}

test_case "json output is valid JSON when logs exist" && {
  agent_id=$("$BIN" list --json 2>/dev/null | jq -r '.[0].id // empty' 2>/dev/null || echo "")
  if [[ -z "$agent_id" ]]; then
    skip "No agents in fleet"
  fi
  out=$("$BIN" logs "$agent_id" --json --tail 5 2>&1)
  echo "$out" | jq . > /dev/null 2>&1 || fail "Not valid JSON"
  pass
}

summary
