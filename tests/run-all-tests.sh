#!/usr/bin/env bash
# run-all-tests.sh — Run all clawforge tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════╗"
echo "║       ClawForge Test Suite           ║"
echo "╚══════════════════════════════════════╝"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0

TESTS=(
  test-foundation
  test-cli
  test-fleet-common
  test-fleet-create
  test-fleet-list
  test-fleet-inspect
  test-fleet-status
  test-fleet-cost
  test-fleet-logs
  test-fleet-config-safety
  test-fleet-e2e
  test-fleet-all
  test-fleet-phase2
  test-fleet-phase3
)

for test in "${TESTS[@]}"; do
  echo "────────────────────────────────────────"
  if [[ -f "$SCRIPT_DIR/${test}.sh" ]]; then
    if "$SCRIPT_DIR/${test}.sh"; then
      echo "  → ${test}: PASS"
      TOTAL_PASS=$((TOTAL_PASS + 1))
    else
      echo "  → ${test}: FAIL"
      TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
  else
    echo "  → ${test}: SKIP (not found)"
  fi
  echo ""
done

echo "════════════════════════════════════════"
echo "Passed: $TOTAL_PASS  Failed: $TOTAL_FAIL"
if [[ $TOTAL_FAIL -eq 0 ]]; then
  echo "All test suites passed ✅"
  exit 0
else
  echo "$TOTAL_FAIL test suite(s) failed ❌"
  exit 1
fi
