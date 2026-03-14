#!/usr/bin/env bash
# test-fleet-list.sh — Test fleet-list.sh output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
LIST="${SCRIPT_DIR}/../bin/fleet-list.sh"
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

assert_json_valid() {
  local desc="$1"; shift
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | jq empty 2>/dev/null; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (invalid JSON output)"
    ((FAIL++)) || true
  fi
}

echo "=== test-fleet-list: Fleet overview ==="

# ── Help ───────────────────────────────────────────────────────────────
echo ""
echo "── Help / usage ──"
assert_ok "list --help exits 0" "$CLI" list --help
assert_contains "help mentions status indicators" "●" "$CLI" list --help

# ── Normal output with live config ────────────────────────────────────
echo ""
echo "── Normal output (live config) ──"
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  assert_ok "list exits 0 with live config" "$LIST"
  assert_contains "output has fleet header" "Fleet" "$LIST"
  assert_contains "output has status legend" "●" "$LIST"
  assert_contains "output has column headers" "ID" "$LIST"
  assert_contains "output has name column" "Name" "$LIST"
  assert_contains "output has model column" "Model" "$LIST"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── JSON output ───────────────────────────────────────────────────────
echo ""
echo "── JSON output ──"
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  assert_json_valid "list --json produces valid JSON" "$LIST" --json
  output=$("$LIST" --json 2>/dev/null)
  if echo "$output" | jq -e '.agents | type == "array"' >/dev/null 2>&1; then
    echo "  ✅ JSON has agents array"
    ((PASS++)) || true
  else
    echo "  ❌ JSON missing agents array"
    ((FAIL++)) || true
  fi
  if echo "$output" | jq -e '.count | type == "number"' >/dev/null 2>&1; then
    echo "  ✅ JSON has count field"
    ((PASS++)) || true
  else
    echo "  ❌ JSON missing count field"
    ((FAIL++)) || true
  fi
  # Verify each agent has required fields
  if echo "$output" | jq -e '.agents[0] | has("id") and has("status") and has("model")' >/dev/null 2>&1; then
    echo "  ✅ JSON agents have required fields (id, status, model)"
    ((PASS++)) || true
  else
    echo "  ❌ JSON agents missing required fields"
    ((FAIL++)) || true
  fi
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── Verbose output ────────────────────────────────────────────────────
echo ""
echo "── Verbose output ──"
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  assert_ok "list --verbose exits 0" "$LIST" --verbose
  assert_contains "verbose shows heartbeat column" "Heartbeat" "$LIST" --verbose
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── Empty config ─────────────────────────────────────────────────────
echo ""
echo "── Empty config ──"
EMPTY_CONFIG=$(mktemp)
trap 'rm -f "$EMPTY_CONFIG"' EXIT
echo '{"agents": {"list": []}, "bindings": []}' > "$EMPTY_CONFIG"
output=$(OPENCLAW_CONFIG="$EMPTY_CONFIG" "$LIST" 2>&1 || true)
if echo "$output" | grep -qi "no agents\|create\|forge"; then
  echo "  ✅ empty config shows helpful message"
  ((PASS++)) || true
else
  echo "  ❌ empty config message unclear"
  ((FAIL++)) || true
fi

# ── CLI routing ───────────────────────────────────────────────────────
echo ""
echo "── CLI routing ──"
assert_ok "clawforge list routes correctly" "$CLI" list --help

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
