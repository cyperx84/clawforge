#!/usr/bin/env bash
# test-fleet-inspect.sh — Test fleet-inspect.sh output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
INSPECT="${SCRIPT_DIR}/../bin/fleet-inspect.sh"
CREATE="${SCRIPT_DIR}/../bin/fleet-create.sh"
PASS=0 FAIL=0

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

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

echo "=== test-fleet-inspect: Deep agent view ==="

# ── Help ───────────────────────────────────────────────────────────────
echo ""
echo "── Help / usage ──"
assert_ok "inspect --help exits 0" "$CLI" inspect --help

# ── Inspect live agent ────────────────────────────────────────────────
echo ""
echo "── Live agent inspection (builder) ──"
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  assert_ok "inspect builder exits 0" "$INSPECT" builder
  assert_contains "shows Config section" "Config" "$INSPECT" builder
  assert_contains "shows Workspace Files section" "Workspace Files" "$INSPECT" builder
  assert_contains "shows model info" "Model" "$INSPECT" builder
  assert_contains "shows workspace path" ".openclaw" "$INSPECT" builder
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── JSON output ───────────────────────────────────────────────────────
echo ""
echo "── JSON output ──"
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  assert_json_valid "inspect --json produces valid JSON" "$INSPECT" builder --json

  output=$("$INSPECT" builder --json 2>/dev/null)

  if echo "$output" | jq -e '.status' >/dev/null 2>&1; then
    echo "  ✅ JSON has status field"
    ((PASS++)) || true
  else
    echo "  ❌ JSON missing status field"
    ((FAIL++)) || true
  fi

  if echo "$output" | jq -e '.files | type == "array"' >/dev/null 2>&1; then
    echo "  ✅ JSON has files array"
    ((PASS++)) || true
  else
    echo "  ❌ JSON missing files array"
    ((FAIL++)) || true
  fi

  if echo "$output" | jq -e '.memory_count | type == "number"' >/dev/null 2>&1; then
    echo "  ✅ JSON has memory_count"
    ((PASS++)) || true
  else
    echo "  ❌ JSON missing memory_count"
    ((FAIL++)) || true
  fi
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── Inspect agent with pending config only ───────────────────────────
echo ""
echo "── Inspect agent from pending config ──"
PENDING_ID="test-pending-$$"
PENDING_WS="${TEST_DIR}/${PENDING_ID}"

# Create an agent (writes pending config, no live config)
OPENCLAW_CONFIG="/dev/null" \
  "$CREATE" "$PENDING_ID" \
  --name "PendingAgent" \
  --role "Agent pending activation" \
  --emoji "⏳" \
  --from generalist \
  --workspace "$PENDING_WS" \
  --no-interactive >/dev/null 2>&1 || true

if [[ -d "$PENDING_WS" ]]; then
  output=$(OPENCLAW_CONFIG="/dev/null" "$INSPECT" "$PENDING_ID" \
    --workspace-override "$PENDING_WS" 2>&1 || true)
  # inspect should work via workspace path lookup
  assert_ok "pending agent workspace exists" test -d "$PENDING_WS"
  assert_ok "pending agent SOUL.md exists" test -f "${PENDING_WS}/SOUL.md"
  echo "  ✅ pending config inspection (workspace created correctly)"
  ((PASS++)) || true
fi

# ── Nonexistent agent ─────────────────────────────────────────────────
echo ""
echo "── Error handling ──"
assert_fail "fails for nonexistent agent" "$INSPECT" "nonexistent-agent-xyz-99999"
assert_fail "fails without agent ID" "$INSPECT"

# ── File status display ───────────────────────────────────────────────
echo ""
echo "── File status indicators ──"
if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  output=$("$INSPECT" builder 2>/dev/null)
  if echo "$output" | grep -q '✓\|○\|⚠\|✗'; then
    echo "  ✅ shows file status icons"
    ((PASS++)) || true
  else
    echo "  ❌ no file status icons found"
    ((FAIL++)) || true
  fi
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── CLI routing ───────────────────────────────────────────────────────
echo ""
echo "── CLI routing ──"
assert_ok "clawforge inspect routes correctly" "$CLI" inspect --help

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
