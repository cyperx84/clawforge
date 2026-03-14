#!/usr/bin/env bash
# test-fleet-create.sh — Test fleet-create.sh (non-interactive mode)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
CREATE="${SCRIPT_DIR}/../bin/fleet-create.sh"
PASS=0 FAIL=0

# Temp workspace for testing
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

assert_file_exists() {
  local desc="$1" filepath="$2"
  if [[ -f "$filepath" ]]; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (missing: $filepath)"
    ((FAIL++)) || true
  fi
}

assert_dir_exists() {
  local desc="$1" dirpath="$2"
  if [[ -d "$dirpath" ]]; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (missing: $dirpath)"
    ((FAIL++)) || true
  fi
}

assert_file_contains() {
  local desc="$1" filepath="$2" expected="$3"
  if [[ -f "$filepath" ]] && grep -q "$expected" "$filepath"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in $filepath)"
    ((FAIL++)) || true
  fi
}

assert_file_not_contains() {
  local desc="$1" filepath="$2" unexpected="$3"
  if [[ -f "$filepath" ]] && ! grep -q "$unexpected" "$filepath"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (unexpected '$unexpected' in $filepath)"
    ((FAIL++)) || true
  fi
}

echo "=== test-fleet-create: Agent creation ==="

# ── Help ───────────────────────────────────────────────────────────────
echo ""
echo "── Help / usage ──"
assert_ok "create --help exits 0" "$CLI" create --help

# ── Non-interactive creation (generalist archetype) ───────────────────
echo ""
echo "── Non-interactive creation (generalist) ──"
TEST_AGENT_ID="test-agent-$$"
TEST_WS="${TEST_DIR}/${TEST_AGENT_ID}"

output=$(OPENCLAW_CONFIG="/dev/null" \
  "$CREATE" "$TEST_AGENT_ID" \
  --name "TestAgent" \
  --role "Test agent for unit tests" \
  --emoji "🧪" \
  --from generalist \
  --model "openai-codex/gpt-5.4" \
  --spawnable-by "main" \
  --workspace "$TEST_WS" \
  --no-interactive 2>&1 || true)

assert_dir_exists "workspace directory created" "$TEST_WS"
assert_dir_exists "memory directory created" "${TEST_WS}/memory"
assert_dir_exists "references directory created" "${TEST_WS}/references"

for f in SOUL.md AGENTS.md TOOLS.md HEARTBEAT.md IDENTITY.md MEMORY.md USER.md; do
  assert_file_exists "created $f" "${TEST_WS}/${f}"
done

assert_file_contains "SOUL.md has agent name" "${TEST_WS}/SOUL.md" "TestAgent"
assert_file_contains "SOUL.md has role" "${TEST_WS}/SOUL.md" "Test agent for unit tests"
assert_file_contains "SOUL.md has emoji" "${TEST_WS}/SOUL.md" "🧪"
assert_file_not_contains "SOUL.md has no unresolved NAME placeholder" "${TEST_WS}/SOUL.md" "{{NAME}}"
assert_file_not_contains "SOUL.md has no unresolved ROLE placeholder" "${TEST_WS}/SOUL.md" "{{ROLE}}"

assert_dir_exists "pending config dir created" "${TEST_WS}/.clawforge"
assert_file_exists "pending config file created" "${TEST_WS}/.clawforge/pending-config.json"

pending=$(cat "${TEST_WS}/.clawforge/pending-config.json" 2>/dev/null)
if echo "$pending" | jq -e '.id == "'"$TEST_AGENT_ID"'"' >/dev/null 2>&1; then
  echo "  ✅ pending config has correct agent ID"
  ((PASS++)) || true
else
  echo "  ❌ pending config has wrong agent ID"
  ((FAIL++)) || true
fi

if echo "$pending" | jq -e '.workspace' >/dev/null 2>&1; then
  echo "  ✅ pending config has workspace"
  ((PASS++)) || true
else
  echo "  ❌ pending config missing workspace"
  ((FAIL++)) || true
fi

# ── Coder archetype ───────────────────────────────────────────────────
echo ""
echo "── Coder archetype ──"
CODER_ID="test-coder-$$"
CODER_WS="${TEST_DIR}/${CODER_ID}"

OPENCLAW_CONFIG="/dev/null" \
  "$CREATE" "$CODER_ID" \
  --name "TestCoder" \
  --role "Coding specialist" \
  --emoji "💻" \
  --from coder \
  --workspace "$CODER_WS" \
  --no-interactive >/dev/null 2>&1 || true

assert_dir_exists "coder workspace created" "$CODER_WS"
assert_file_contains "coder SOUL.md has coding content" "${CODER_WS}/SOUL.md" "code"

# ── Monitor archetype ─────────────────────────────────────────────────
echo ""
echo "── Monitor archetype ──"
MONITOR_ID="test-monitor-$$"
MONITOR_WS="${TEST_DIR}/${MONITOR_ID}"

OPENCLAW_CONFIG="/dev/null" \
  "$CREATE" "$MONITOR_ID" \
  --name "TestMonitor" \
  --role "System monitoring" \
  --emoji "👁" \
  --from monitor \
  --workspace "$MONITOR_WS" \
  --no-interactive >/dev/null 2>&1 || true

assert_dir_exists "monitor workspace created" "$MONITOR_WS"
assert_file_contains "monitor HEARTBEAT.md has tasks" "${MONITOR_WS}/HEARTBEAT.md" "Health\|health\|check\|disk"

# ── Blank archetype ───────────────────────────────────────────────────
echo ""
echo "── Blank archetype ──"
BLANK_ID="test-blank-$$"
BLANK_WS="${TEST_DIR}/${BLANK_ID}"

OPENCLAW_CONFIG="/dev/null" \
  "$CREATE" "$BLANK_ID" \
  --name "TestBlank" \
  --role "Blank agent" \
  --emoji "⬜" \
  --workspace "$BLANK_WS" \
  --no-interactive >/dev/null 2>&1 || true

assert_dir_exists "blank workspace created" "$BLANK_WS"
assert_file_exists "blank SOUL.md created" "${BLANK_WS}/SOUL.md"

# ── Validation ────────────────────────────────────────────────────────
echo ""
echo "── Input validation ──"

# Missing ID
assert_fail "fails without agent ID" "$CREATE" --no-interactive

# Invalid ID format
assert_fail "fails with uppercase ID" "$CREATE" "TestAgent" --no-interactive

# Missing role in non-interactive
assert_fail "fails without role in non-interactive" "$CREATE" "no-role-test" \
  --workspace "${TEST_DIR}/no-role" --no-interactive

# ── CLI routing ───────────────────────────────────────────────────────
echo ""
echo "── CLI routing ──"
output=$("$CLI" create --help 2>&1 || true)
if echo "$output" | grep -qi "create\|forge\|agent"; then
  echo "  ✅ clawforge create routes correctly"
  ((PASS++)) || true
else
  echo "  ❌ clawforge create routing failed"
  ((FAIL++)) || true
fi

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
