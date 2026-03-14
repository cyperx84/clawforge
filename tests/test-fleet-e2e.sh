#!/usr/bin/env bash
# test-fleet-e2e.sh — End-to-end happy path tests using temp harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/fleet-test-harness.sh"

PASS=0 FAIL=0

# Import assertion helpers from harness
source "${SCRIPT_DIR}/lib/fleet-test-harness.sh"

# Initialize harness
fleet_harness_init
fleet_harness_auto_cleanup

CLI=$(clawforge_cli)
CREATE=$(fleet_script fleet-create.sh)
ACTIVATE=$(fleet_script fleet-activate.sh)
BIND=$(fleet_script fleet-bind.sh)
LIST=$(fleet_script fleet-list.sh)
EXPORT=$(fleet_script fleet-export.sh)
IMPORT=$(fleet_script fleet-import.sh)
DEACTIVATE=$(fleet_script fleet-deactivate.sh)
DESTROY=$(fleet_script fleet-destroy.sh)
INSPECT=$(fleet_script fleet-inspect.sh)

TEST_AGENT="cf-test-scout"
TEST_CHANNEL="123456789012345678"

echo "=== test-fleet-e2e: End-to-end happy path ==="

# ── 1. Create Agent ───────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Create Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

output=$("$CREATE" "$TEST_AGENT" \
  --name "Scout" \
  --role "Monitoring" \
  --emoji "🔭" \
  --from monitor \
  --model openai-codex/gpt-5.4 \
  --spawnable-by main \
  --workspace "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}" \
  --no-interactive 2>&1 || true)

assert_dir_exists "workspace created" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}"
assert_dir_exists "memory directory created" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/memory"
assert_dir_exists "references directory created" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/references"

for f in SOUL.md AGENTS.md TOOLS.md HEARTBEAT.md IDENTITY.md MEMORY.md USER.md; do
  assert_file_exists "created $f" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/${f}"
done

# Check placeholder substitution
assert_file_contains "SOUL.md has agent name" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/SOUL.md" "Scout"
assert_file_contains "SOUL.md has role" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/SOUL.md" "Monitoring"
assert_file_contains "SOUL.md has emoji" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/SOUL.md" "🔭"
assert_file_not_contains "SOUL.md has no NAME placeholder" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/SOUL.md" "{{NAME}}"
assert_file_not_contains "SOUL.md has no ROLE placeholder" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/SOUL.md" "{{ROLE}}"

# Check pending config
assert_file_exists "pending config created" "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/.clawforge/pending-config.json"

# ── 2. Inspect Agent ─────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  2. Inspect Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

output=$("$INSPECT" "$TEST_AGENT" 2>&1 || true)

if echo "$output" | grep -q "○ created\|created"; then
  echo "  ✅ inspect shows 'created' status"
  ((PASS++)) || true
else
  echo "  ❌ inspect should show 'created' status"
  echo "$output"
  ((FAIL++)) || true
fi

# ── 3. Activate Agent ────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  3. Activate Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

output=$("$ACTIVATE" "$TEST_AGENT" --add-to main 2>&1 || true)

# Verify agent added to config
if fleet_harness_agent_in_config "$TEST_AGENT"; then
  echo "  ✅ agent added to agents.list"
  ((PASS++)) || true
else
  echo "  ❌ agent not in agents.list"
  ((FAIL++)) || true
fi

# Verify added to main's allowAgents
if fleet_harness_agent_in_allowagents "$TEST_AGENT" "main"; then
  echo "  ✅ added to main's allowAgents"
  ((PASS++)) || true
else
  echo "  ❌ not in main's allowAgents"
  ((FAIL++)) || true
fi

# Verify pending config removed
if [[ ! -f "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}/.clawforge/pending-config.json" ]]; then
  echo "  ✅ pending config removed"
  ((PASS++)) || true
else
  echo "  ❌ pending config still exists"
  ((FAIL++)) || true
fi

# ── 4. Bind Agent ────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  4. Bind Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

output=$("$BIND" bind "$TEST_AGENT" "$TEST_CHANNEL" 2>&1 || true)

# Verify binding exists
if fleet_harness_binding_exists "$TEST_AGENT" "$TEST_CHANNEL"; then
  echo "  ✅ binding created in config"
  ((PASS++)) || true
else
  echo "  ❌ binding not found in config"
  ((FAIL++)) || true
fi

# ── 5. List Agents ───────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  5. List Agents"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

output=$("$LIST" 2>&1 || true)

if echo "$output" | grep -q "$TEST_AGENT"; then
  echo "  ✅ agent appears in list"
  ((PASS++)) || true
else
  echo "  ❌ agent not in list output"
  echo "$output"
  ((FAIL++)) || true
fi

# Check for active indicator
if echo "$output" | grep -q "●\|active"; then
  echo "  ✅ shows as active"
  ((PASS++)) || true
else
  echo "  ❌ not shown as active"
  ((FAIL++)) || true
fi

# ── 6. Export Agent ──────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  6. Export Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXPORT_DIR=$(mktemp -d)
trap 'rm -rf "$EXPORT_DIR"' EXIT

EXPORT_FILE="${EXPORT_DIR}/${TEST_AGENT}.clawforge"

output=$("$EXPORT" "$TEST_AGENT" --output "$EXPORT_FILE" 2>&1 || true)

if [[ -f "$EXPORT_FILE" ]]; then
  echo "  ✅ export archive created"
  ((PASS++)) || true
else
  echo "  ❌ export archive not created"
  ((FAIL++)) || true
  exit 1
fi

# Verify archive contains manifest.json
temp_extract=$(mktemp -d)
if tar -xzf "$EXPORT_FILE" -C "$temp_extract" 2>/dev/null; then
  if [[ -f "${temp_extract}/${TEST_AGENT}/manifest.json" ]]; then
    echo "  ✅ archive contains manifest.json"
    ((PASS++)) || true
  else
    echo "  ❌ manifest.json not in archive"
    ((FAIL++)) || true
  fi
  rm -rf "$temp_extract"
else
  echo "  ❌ failed to extract archive"
  ((FAIL++)) || true
fi

# ── 7. Import Agent ──────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  7. Import Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

IMPORT_ID="${TEST_AGENT}-copy"

# Import with explicit --id and --model to avoid interactive prompts
output=$("$IMPORT" "$EXPORT_FILE" --id "$IMPORT_ID" --model "openai-codex/gpt-5.4" 2>&1) && rc=0 || rc=$?

if [[ $rc -eq 0 ]]; then
  echo "  ✅ import command succeeded"
  ((PASS++)) || true
else
  echo "  ❌ import command failed (exit code: $rc)"
  echo "$output"
  ((FAIL++)) || true
fi

# Check workspace created
if [[ -d "${OPENCLAW_AGENTS_DIR}/${IMPORT_ID}" ]]; then
  echo "  ✅ imported workspace created"
  ((PASS++)) || true
else
  echo "  ❌ imported workspace not created (expected: ${OPENCLAW_AGENTS_DIR}/${IMPORT_ID})"
  ls -la "${OPENCLAW_AGENTS_DIR}/" 2>&1 | head -10
  ((FAIL++)) || true
fi

# Check workspace has files
if [[ -f "${OPENCLAW_AGENTS_DIR}/${IMPORT_ID}/SOUL.md" ]]; then
  echo "  ✅ imported workspace has SOUL.md"
  ((PASS++)) || true
else
  echo "  ❌ imported workspace missing SOUL.md"
  ((FAIL++)) || true
fi

# ── 8. Deactivate Imported Agent ────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  8. Deactivate Imported Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# First activate the imported agent
output=$("$ACTIVATE" "$IMPORT_ID" 2>&1 || true)

# Now deactivate
output=$("$DEACTIVATE" "$IMPORT_ID" 2>&1 || true)

# Verify removed from config
if ! fleet_harness_agent_in_config "$IMPORT_ID"; then
  echo "  ✅ agent removed from config"
  ((PASS++)) || true
else
  echo "  ❌ agent still in config"
  ((FAIL++)) || true
fi

# Verify workspace still exists
if [[ -d "${OPENCLAW_AGENTS_DIR}/${IMPORT_ID}" ]]; then
  echo "  ✅ workspace preserved"
  ((PASS++)) || true
else
  echo "  ❌ workspace was deleted"
  ((FAIL++)) || true
fi

# ── 9. Destroy Imported Agent ────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  9. Destroy Imported Agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Need to reactivate first (destroy expects agent in config)
output=$("$ACTIVATE" "$IMPORT_ID" 2>&1 || true)

# Now destroy with --yes
output=$("$DESTROY" "$IMPORT_ID" --yes 2>&1 || true)

# Verify removed from config
if ! fleet_harness_agent_in_config "$IMPORT_ID"; then
  echo "  ✅ agent removed from config"
  ((PASS++)) || true
else
  echo "  ❌ agent still in config"
  ((FAIL++)) || true
fi

# Verify workspace removed
if [[ ! -d "${OPENCLAW_AGENTS_DIR}/${IMPORT_ID}" ]]; then
  echo "  ✅ workspace removed"
  ((PASS++)) || true
else
  echo "  ❌ workspace still exists"
  ((FAIL++)) || true
fi

# ── Cleanup Test Agent ───────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Deactivate and destroy test agent
"$DEACTIVATE" "$TEST_AGENT" >/dev/null 2>&1 || true
"$DESTROY" "$TEST_AGENT" --yes >/dev/null 2>&1 || true

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "  ✅ All E2E tests passed ($PASS passed)"
  exit 0
else
  echo "  ❌ $FAIL test(s) failed, $PASS passed"
  exit 1
fi
