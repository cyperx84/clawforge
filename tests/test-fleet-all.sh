#!/usr/bin/env bash
# test-fleet-all.sh — Run all fleet management tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0 FAIL=0 SKIP=0

run_suite() {
  local name="$1" file="$2"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Suite: $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ ! -f "$file" ]]; then
    echo "  ⚠️  Skipped (file not found: $file)"
    ((SKIP++)) || true
    return
  fi

  if bash "$file"; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
  fi
}

echo "🔨 ClawForge Fleet Test Suite"
echo "=============================="

run_suite "fleet-common"  "${SCRIPT_DIR}/test-fleet-common.sh"
run_suite "fleet-create"  "${SCRIPT_DIR}/test-fleet-create.sh"
run_suite "fleet-list"    "${SCRIPT_DIR}/test-fleet-list.sh"
run_suite "fleet-inspect" "${SCRIPT_DIR}/test-fleet-inspect.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "  ✅ All suites passed ($PASS passed${SKIP:+, $SKIP skipped})"
  exit 0
else
  echo "  ❌ $FAIL suite(s) failed, $PASS passed${SKIP:+, $SKIP skipped}"
  exit 1
fi
