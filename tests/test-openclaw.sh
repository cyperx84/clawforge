#!/usr/bin/env bash
# test-openclaw.sh — Test OpenClaw integration: --json, --notify, --webhook flags
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
SPRINT="${SCRIPT_DIR}/../bin/sprint.sh"
SWARM="${SCRIPT_DIR}/../bin/swarm.sh"
COST="${SCRIPT_DIR}/../bin/cost.sh"
CONFLICTS="${SCRIPT_DIR}/../bin/conflicts.sh"
TEMPLATES="${SCRIPT_DIR}/../bin/templates.sh"
PASS=0 FAIL=0

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

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== test-openclaw.sh ==="

# ── --json flag on all commands ───────────────────────────────────────
echo "Test 1: --json flag availability"
assert_contains "sprint has --json" "json" "$SPRINT" --help
assert_contains "swarm has --json" "json" "$SWARM" --help
assert_contains "cost has --json" "json" "$COST" --help
assert_contains "conflicts has --json" "json" "$CONFLICTS" --help
assert_contains "templates has --json" "json" "$TEMPLATES" --help
assert_contains "watch has --json" "json" "$CLI" watch --help

# ── --notify flag ─────────────────────────────────────────────────────
echo "Test 2: --notify flag availability"
assert_contains "sprint has --notify" "notify" "$SPRINT" --help
assert_contains "swarm has --notify" "notify" "$SWARM" --help

# ── --webhook flag ────────────────────────────────────────────────────
echo "Test 3: --webhook flag availability"
assert_contains "sprint has --webhook" "webhook" "$SPRINT" --help
assert_contains "swarm has --webhook" "webhook" "$SWARM" --help

# ── JSON output format for cost ───────────────────────────────────────
echo "Test 4: JSON output format"
# cost --summary --json with no data
json_out=$("$COST" --summary --json 2>/dev/null || true)
valid_json=$(echo "$json_out" | jq -e '.' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "cost summary JSON is valid" "yes" "$valid_json"

# conflicts --json with no data
json_out=$("$CONFLICTS" --json 2>/dev/null || true)
valid_json=$(echo "$json_out" | jq -e '.' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "conflicts JSON is valid" "yes" "$valid_json"

# templates --json
json_out=$("$TEMPLATES" --json 2>/dev/null || true)
valid_json=$(echo "$json_out" | jq -e '.' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "templates JSON is valid" "yes" "$valid_json"

# ── Source code checks ────────────────────────────────────────────────
echo "Test 5: OpenClaw integration in source"
assert_contains "sprint source has openclaw" "openclaw" cat "$SPRINT"
assert_contains "swarm source has openclaw" "openclaw" cat "$SWARM"
assert_contains "sprint source has webhook" "webhook\|WEBHOOK" cat "$SPRINT"
assert_contains "swarm source has webhook" "webhook\|WEBHOOK" cat "$SWARM"
assert_contains "sprint source has curl" "curl" cat "$SPRINT"
assert_contains "swarm source has curl" "curl" cat "$SWARM"

# ── v0.5 commands in help ────────────────────────────────────────────
echo "Test 6: v0.5 commands in CLI help"
assert_contains "help shows cost" "cost" "$CLI" help
assert_contains "help shows conflicts" "conflicts" "$CLI" help
assert_contains "help shows templates" "templates" "$CLI" help
assert_contains "help shows Observability" "Observability" "$CLI" help

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
