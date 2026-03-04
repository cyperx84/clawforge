#!/usr/bin/env bash
# run-all-tests.sh — Run all clawforge tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════╗"
echo "║       clawforge test suite            ║"
echo "╚══════════════════════════════════════╝"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
TESTS=(test-cli test-registry test-spawn test-watch test-review test-scope test-notify test-merge test-clean test-learn test-foundation test-modes test-management test-dashboard test-tui test-cost test-templates test-conflicts test-ci-loop test-openclaw test-multi-repo test-routing test-memory test-init test-history test-eval test-reliability test-observability test-practical test-power test-dx)

for test in "${TESTS[@]}"; do
  echo "────────────────────────────────────────"
  if "$SCRIPT_DIR/${test}.sh"; then
    echo "  → ${test}: PASS"
  else
    echo "  → ${test}: FAIL"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
  echo ""
done

echo "════════════════════════════════════════"
if [[ $TOTAL_FAIL -eq 0 ]]; then
  echo "All test suites passed ✅"
  exit 0
else
  echo "$TOTAL_FAIL test suite(s) failed ❌"
  exit 1
fi
