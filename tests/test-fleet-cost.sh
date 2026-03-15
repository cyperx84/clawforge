#!/usr/bin/env bash
# test-fleet-cost.sh — Tests for fleet-cost command
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/test-helpers.sh"

BIN="${SCRIPT_DIR}/../bin/clawforge"

suite "fleet-cost"

test_case "help flag works" && {
  out=$("$BIN" cost --help 2>&1)
  assert_contains "$out" "Usage: clawforge cost"
  assert_contains "$out" "--today"
  assert_contains "$out" "--week"
  pass
}

test_case "runs without error" && {
  out=$("$BIN" cost 2>&1)
  assert_contains "$out" "Fleet Costs"
  assert_contains "$out" "TOTAL"
  pass
}

test_case "json output is valid JSON" && {
  out=$("$BIN" cost --json 2>&1)
  echo "$out" | jq . > /dev/null 2>&1 || fail "Not valid JSON"
  pass
}

test_case "--today filter runs" && {
  out=$("$BIN" cost --today 2>&1)
  assert_contains "$out" "Fleet Costs"
  pass
}

test_case "--week filter runs" && {
  out=$("$BIN" cost --week 2>&1)
  assert_contains "$out" "Fleet Costs"
  pass
}

test_case "single agent cost lookup" && {
  agent_id=$("$BIN" list --json 2>/dev/null | jq -r '.[0].id // empty' 2>/dev/null || echo "")
  if [[ -z "$agent_id" ]]; then
    skip "No agents in fleet"
  fi
  out=$("$BIN" cost "$agent_id" 2>&1)
  assert_contains "$out" "$agent_id"
  pass
}

summary
