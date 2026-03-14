#!/usr/bin/env bash
# test-fleet-phase2.sh — Tests for Phase 2 management commands
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAWFORGE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
TESTS_RUN=0

# Test utilities
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAILED=$((FAILED + 1))
}

run_test() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  echo ""
  echo "── Test: $test_name ────────────────────────"
}

cleanup_test_artifacts() {
  # Clean up any test agents created
  if _agent_exists_in_config "test-agent-1" 2>/dev/null; then
    "${CLAWFORGE_ROOT}/bin/fleet-destroy.sh" test-agent-1 --yes 2>/dev/null || true
  fi
  if _agent_exists_in_config "test-agent-2" 2>/dev/null; then
    "${CLAWFORGE_ROOT}/bin/fleet-destroy.sh" test-agent-2 --yes 2>/dev/null || true
  fi
  if _agent_exists_in_config "test-cloned" 2>/dev/null; then
    "${CLAWFORGE_ROOT}/bin/fleet-destroy.sh" test-cloned --yes 2>/dev/null || true
  fi
}

# Source libraries
source "${CLAWFORGE_ROOT}/lib/common.sh"
source "${CLAWFORGE_ROOT}/lib/fleet-common.sh"

echo "ClawForge Phase 2 Tests"
echo "════════════════════════════════════════════"

# Ensure cleanup on exit
trap cleanup_test_artifacts EXIT

# ─────────────────────────────────────────────────────────────────────
# Test 1: fleet-edit routes to correct file
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-edit routes to correct file"

# Create a test agent first (if it doesn't exist)
if ! _agent_exists_in_config "builder" 2>/dev/null; then
  fail "Builder agent not found - cannot test edit"
else
  # Test that --soul flag would open SOUL.md (we can't actually test opening editor)
  if "${CLAWFORGE_ROOT}/bin/fleet-edit.sh" builder --help 2>/dev/null | grep -q "SOUL.md"; then
    pass "fleet-edit --soul mentions SOUL.md in help"
  else
    fail "fleet-edit --soul should mention SOUL.md"
  fi
  
  # Test that --all flag exists
  if "${CLAWFORGE_ROOT}/bin/fleet-edit.sh" builder --help 2>/dev/null | grep -q "\-\-all"; then
    pass "fleet-edit --all flag exists"
  else
    fail "fleet-edit should have --all flag"
  fi
fi

# ─────────────────────────────────────────────────────────────────────
# Test 2: fleet-bind dry-run
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-bind dry-run shows plan"

if _agent_exists_in_config "builder" 2>/dev/null; then
  OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-bind.sh" bind builder 123456789 --dry-run 2>&1 || true)
  
  if echo "$OUTPUT" | grep -q "DRY-RUN"; then
    pass "fleet-bind shows dry-run output"
  else
    fail "fleet-bind --dry-run should show DRY-RUN prefix"
  fi
  
  if echo "$OUTPUT" | grep -q "builder"; then
    pass "fleet-bind dry-run mentions agent ID"
  else
    fail "fleet-bind dry-run should mention agent ID"
  fi
else
  fail "Builder agent not found - cannot test bind"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 3: fleet-clone creates workspace + config (dry-run)
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-clone dry-run shows plan"

if _agent_exists_in_config "builder" 2>/dev/null; then
  OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-clone.sh" builder test-cloned --dry-run 2>&1 || true)
  
  if echo "$OUTPUT" | grep -q "DRY-RUN"; then
    pass "fleet-clone shows dry-run output"
  else
    fail "fleet-clone --dry-run should show DRY-RUN prefix"
  fi
  
  if echo "$OUTPUT" | grep -q "test-cloned"; then
    pass "fleet-clone dry-run mentions new agent ID"
  else
    fail "fleet-clone dry-run should mention new agent ID"
  fi
else
  fail "Builder agent not found - cannot test clone"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 4: fleet-deactivate removes from config (dry-run)
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-deactivate dry-run shows plan"

if _agent_exists_in_config "builder" 2>/dev/null; then
  OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-deactivate.sh" builder --dry-run 2>&1 || true)
  
  if echo "$OUTPUT" | grep -q "DRY-RUN"; then
    pass "fleet-deactivate shows dry-run output"
  else
    fail "fleet-deactivate --dry-run should show DRY-RUN prefix"
  fi
  
  # Should refuse to deactivate main
  OUTPUT_MAIN=$("${CLAWFORGE_ROOT}/bin/fleet-deactivate.sh" main --dry-run 2>&1 || true)
  if echo "$OUTPUT_MAIN" | grep -qi "cannot deactivate"; then
    pass "fleet-deactivate refuses to deactivate main agent"
  else
    fail "fleet-deactivate should refuse to deactivate main"
  fi
else
  fail "Builder agent not found - cannot test deactivate"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 5: fleet-destroy requires --yes
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-destroy requires explicit confirmation"

if _agent_exists_in_config "builder" 2>/dev/null; then
  # Should fail without --yes
  OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-destroy.sh" builder 2>&1 || true)
  
  if echo "$OUTPUT" | grep -qi "\-\-yes"; then
    pass "fleet-destroy requires --yes flag"
  else
    fail "fleet-destroy should require --yes flag"
  fi
  
  # Should refuse to destroy main even with --yes
  OUTPUT_MAIN=$("${CLAWFORGE_ROOT}/bin/fleet-destroy.sh" main --yes 2>&1 || true)
  if echo "$OUTPUT_MAIN" | grep -qi "cannot destroy"; then
    pass "fleet-destroy refuses to destroy main agent"
  else
    fail "fleet-destroy should refuse to destroy main"
  fi
else
  fail "Builder agent not found - cannot test destroy"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 6: fleet-migrate dry-run shows plan
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-migrate dry-run shows plan"

OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-migrate.sh" --dry-run 2>&1 || true)

if echo "$OUTPUT" | grep -q "DRY-RUN"; then
  pass "fleet-migrate shows dry-run output"
else
  fail "fleet-migrate --dry-run should show DRY-RUN prefix"
fi

if echo "$OUTPUT" | grep -qi "migrate\|migration"; then
  pass "fleet-migrate mentions migration"
else
  fail "fleet-migrate should mention migration"
fi

# ─────────────────────────────────────────────────────────────────────
# Test 7: fleet-compat exits gracefully without clwatch
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-compat graceful exit without clwatch"

OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-compat.sh" 2>&1 || true)

if echo "$OUTPUT" | grep -qi "install clwatch"; then
  pass "fleet-compat gracefully suggests installing clwatch"
else
  # If clwatch is installed, check for table output
  if echo "$OUTPUT" | grep -q "Agent\|Model\|Compat"; then
    pass "fleet-compat shows compatibility table (clwatch installed)"
  else
    fail "fleet-compat should suggest installing clwatch or show table"
  fi
fi

# ─────────────────────────────────────────────────────────────────────
# Test 8: fleet-upgrade-check graceful exit without clwatch
# ─────────────────────────────────────────────────────────────────────

run_test "fleet-upgrade-check graceful exit without clwatch"

OUTPUT=$("${CLAWFORGE_ROOT}/bin/fleet-upgrade-check.sh" 2>&1 || true)

if echo "$OUTPUT" | grep -qi "install clwatch"; then
  pass "fleet-upgrade-check gracefully suggests installing clwatch"
else
  # If clwatch is installed, check for version output
  if echo "$OUTPUT" | grep -qi "current\|upgrade\|update"; then
    pass "fleet-upgrade-check shows version info (clwatch installed)"
  else
    fail "fleet-upgrade-check should suggest installing clwatch or show versions"
  fi
fi

# ─────────────────────────────────────────────────────────────────────
# Test 9: doctor includes fleet health section
# ─────────────────────────────────────────────────────────────────────

run_test "doctor includes fleet health section"

OUTPUT=$("${CLAWFORGE_ROOT}/bin/doctor.sh" 2>&1 || true)

if echo "$OUTPUT" | grep -q "Fleet Health"; then
  pass "doctor shows Fleet Health section"
else
  fail "doctor should show Fleet Health section"
fi

if echo "$OUTPUT" | grep -q "Tool Versions"; then
  pass "doctor shows Tool Versions section"
else
  fail "doctor should show Tool Versions section"
fi

# Existing doctor checks should still be there
if echo "$OUTPUT" | grep -q "Registry"; then
  pass "doctor still shows Registry section"
else
  fail "doctor should still show Registry section"
fi

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════"
echo "Test Results"
echo "════════════════════════════════════════════"
echo "Tests run:  $TESTS_RUN"
echo -e "Passed:     ${GREEN}$PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
  echo -e "Failed:     ${RED}$FAILED${NC}"
  exit 1
else
  echo "Failed:     0"
  echo ""
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
