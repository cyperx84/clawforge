#!/usr/bin/env bash
# test-fleet-config-safety.sh — Config mutation safety tests
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
DEACTIVATE=$(fleet_script fleet-deactivate.sh)
DESTROY=$(fleet_script fleet-destroy.sh)
MIGRATE=$(fleet_script fleet-migrate.sh)

TEST_AGENT="cf-safety-test"

echo "=== test-fleet-config-safety: Config mutation safety ==="

# ── Setup: Create and activate a test agent ──────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup: Creating test agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

"$CREATE" "$TEST_AGENT" \
  --name "SafetyTest" \
  --role "Testing" \
  --emoji "🧪" \
  --workspace "${OPENCLAW_AGENTS_DIR}/${TEST_AGENT}" \
  --no-interactive >/dev/null 2>&1 || true

"$ACTIVATE" "$TEST_AGENT" >/dev/null 2>&1 || true

# ── Test: activate --dry-run ────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  activate --dry-run does not modify config"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create another agent to test with
DRY_TEST="cf-dry-test"
"$CREATE" "$DRY_TEST" \
  --name "DryRun" \
  --role "Testing" \
  --emoji "🔬" \
  --workspace "${OPENCLAW_AGENTS_DIR}/${DRY_TEST}" \
  --no-interactive >/dev/null 2>&1 || true

# Backup config
backup_config

# Run activate --dry-run
output=$("$ACTIVATE" "$DRY_TEST" --dry-run 2>&1 || true)

# Verify config unchanged
assert_config_unchanged "activate --dry-run does not modify config"

# Verify agent not actually added
if ! fleet_harness_agent_in_config "$DRY_TEST"; then
  echo "  ✅ agent not added to config"
  ((PASS++)) || true
else
  echo "  ❌ agent was added to config"
  ((FAIL++)) || true
fi

# ── Test: bind --dry-run ────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  bind --dry-run does not modify config"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Run bind --dry-run
output=$("$BIND" bind "$TEST_AGENT" "999999999999999999" --dry-run 2>&1 || true)

# Verify config unchanged
assert_config_unchanged "bind --dry-run does not modify config"

# Verify binding not added
binding_count=$(fleet_harness_binding_count "$TEST_AGENT")
if [[ "$binding_count" -eq 0 ]]; then
  echo "  ✅ binding not added"
  ((PASS++)) || true
else
  echo "  ❌ binding was added"
  ((FAIL++)) || true
fi

# ── Test: deactivate --dry-run ──────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  deactivate --dry-run does not modify config"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# First activate dry test agent
"$ACTIVATE" "$DRY_TEST" >/dev/null 2>&1 || true

# Backup config
backup_config

# Run deactivate --dry-run
output=$("$DEACTIVATE" "$DRY_TEST" --dry-run 2>&1 || true)

# Verify config unchanged
assert_config_unchanged "deactivate --dry-run does not modify config"

# Verify agent still in config
if fleet_harness_agent_in_config "$DRY_TEST"; then
  echo "  ✅ agent still in config"
  ((PASS++)) || true
else
  echo "  ❌ agent was removed from config"
  ((FAIL++)) || true
fi

# ── Test: destroy --dry-run ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  destroy --dry-run does not remove files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Run destroy --dry-run
output=$("$DESTROY" "$DRY_TEST" --dry-run 2>&1 || true)

# Verify config unchanged
assert_config_unchanged "destroy --dry-run does not modify config"

# Verify agent still in config
if fleet_harness_agent_in_config "$DRY_TEST"; then
  echo "  ✅ agent still in config"
  ((PASS++)) || true
else
  echo "  ❌ agent was removed from config"
  ((FAIL++)) || true
fi

# Verify workspace still exists
if [[ -d "${OPENCLAW_AGENTS_DIR}/${DRY_TEST}" ]]; then
  echo "  ✅ workspace not removed"
  ((PASS++)) || true
else
  echo "  ❌ workspace was removed"
  ((FAIL++)) || true
fi

# ── Test: migrate --dry-run ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  migrate --dry-run does not copy or rewrite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Run migrate --dry-run
output=$("$MIGRATE" --dry-run 2>&1 || true)

# Verify config unchanged
assert_config_unchanged "migrate --dry-run does not modify config"

# Verify no new directories created
if [[ ! -d "${OPENCLAW_AGENTS_DIR}/migrated-test" ]]; then
  echo "  ✅ no spurious directories created"
  ((PASS++)) || true
else
  echo "  ❌ unexpected directory created"
  ((FAIL++)) || true
fi

# ── Test: destroy main --yes is refused ────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  destroy main --yes is refused"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Attempt to destroy main
output=$("$DESTROY" main --yes 2>&1) && rc=0 || rc=$?

if [[ $rc -ne 0 ]]; then
  echo "  ✅ destroy main exits with error"
  ((PASS++)) || true
else
  echo "  ❌ destroy main should fail"
  ((FAIL++)) || true
fi

# Verify config unchanged
assert_config_unchanged "destroy main does not modify config"

# Verify main still in config
if fleet_harness_agent_in_config "main"; then
  echo "  ✅ main still in config"
  ((PASS++)) || true
else
  echo "  ❌ main was removed from config"
  ((FAIL++)) || true
fi

# ── Test: deactivate main is refused ───────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  deactivate main is refused"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Attempt to deactivate main
output=$("$DEACTIVATE" main 2>&1) && rc=0 || rc=$?

if [[ $rc -ne 0 ]]; then
  echo "  ✅ deactivate main exits with error"
  ((PASS++)) || true
else
  echo "  ❌ deactivate main should fail"
  ((FAIL++)) || true
fi

# Verify config unchanged
assert_config_unchanged "deactivate main does not modify config"

# Verify main still in config
if fleet_harness_agent_in_config "main"; then
  echo "  ✅ main still in config"
  ((PASS++)) || true
else
  echo "  ❌ main was removed from config"
  ((FAIL++)) || true
fi

# ── Test: invalid agent operations fail cleanly ────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Invalid/nonexistent agent operations fail cleanly"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Try to activate nonexistent agent
output=$("$ACTIVATE" "nonexistent-agent-xyz" 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "  ✅ activate nonexistent agent fails"
  ((PASS++)) || true
else
  echo "  ❌ activate nonexistent should fail"
  ((FAIL++)) || true
fi

# Try to bind nonexistent agent
output=$("$BIND" bind "nonexistent-agent-xyz" "123456789" 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "  ✅ bind nonexistent agent fails"
  ((PASS++)) || true
else
  echo "  ❌ bind nonexistent should fail"
  ((FAIL++)) || true
fi

# Try to deactivate nonexistent agent
output=$("$DEACTIVATE" "nonexistent-agent-xyz" 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "  ✅ deactivate nonexistent agent fails"
  ((PASS++)) || true
else
  echo "  ❌ deactivate nonexistent should fail"
  ((FAIL++)) || true
fi

# Try to destroy nonexistent agent
output=$("$DESTROY" "nonexistent-agent-xyz" --yes 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "  ✅ destroy nonexistent agent fails"
  ((PASS++)) || true
else
  echo "  ❌ destroy nonexistent should fail"
  ((FAIL++)) || true
fi

# Verify config unchanged after all failed operations
assert_config_unchanged "config unchanged after invalid operations"

# ── Test: destroy without --yes is refused ─────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  destroy without --yes is refused"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup config
backup_config

# Attempt to destroy without --yes
output=$("$DESTROY" "$TEST_AGENT" 2>&1) && rc=0 || rc=$?

if [[ $rc -ne 0 ]]; then
  echo "  ✅ destroy without --yes exits with error"
  ((PASS++)) || true
else
  echo "  ❌ destroy should require --yes"
  ((FAIL++)) || true
fi

# Verify config unchanged
assert_config_unchanged "destroy without --yes does not modify config"

# Verify agent still exists
if fleet_harness_agent_in_config "$TEST_AGENT"; then
  echo "  ✅ agent still in config"
  ((PASS++)) || true
else
  echo "  ❌ agent was removed from config"
  ((FAIL++)) || true
fi

# ── Cleanup ─────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean up test agents
"$DEACTIVATE" "$TEST_AGENT" >/dev/null 2>&1 || true
"$DESTROY" "$TEST_AGENT" --yes >/dev/null 2>&1 || true
"$DEACTIVATE" "$DRY_TEST" >/dev/null 2>&1 || true
"$DESTROY" "$DRY_TEST" --yes >/dev/null 2>&1 || true

# ── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "  ✅ All config safety tests passed ($PASS passed)"
  exit 0
else
  echo "  ❌ $FAIL test(s) failed, $PASS passed"
  exit 1
fi
