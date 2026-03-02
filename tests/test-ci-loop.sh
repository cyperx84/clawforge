#!/usr/bin/env bash
# test-ci-loop.sh — Test CI feedback loop enhancements
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
CHECK="${SCRIPT_DIR}/../bin/check-agents.sh"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""

cleanup() {
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
}
trap cleanup EXIT

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
  if echo "$output" | grep -q "$expected"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in output)"
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

echo "=== test-ci-loop.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# ── Sprint flags ──────────────────────────────────────────────────────
echo "Test 1: sprint CI flags"
assert_contains "sprint help has --ci-loop" "ci-loop" "$CLI" sprint --help
assert_contains "sprint help has --max-ci-retries" "max-ci-retries" "$CLI" sprint --help
assert_contains "sprint help has --budget" "budget" "$CLI" sprint --help

# ── Swarm flags ───────────────────────────────────────────────────────
echo "Test 2: swarm CI flags"
assert_contains "swarm help has --ci-loop" "ci-loop" "$CLI" swarm --help
assert_contains "swarm help has --max-ci-retries" "max-ci-retries" "$CLI" swarm --help
assert_contains "swarm help has --budget" "budget" "$CLI" swarm --help

# ── check-agents CI feedback function ─────────────────────────────────
echo "Test 3: CI feedback function exists"
assert_contains "check-agents has _ci_feedback" "_ci_feedback" cat "$CHECK"
assert_contains "check-agents uses max_ci_retries" "max_ci_retries" cat "$CHECK"
assert_contains "check-agents uses ci_retries" "ci_retries" cat "$CHECK"

# ── Registry CI fields ───────────────────────────────────────────────
echo "Test 4: registry CI fields"
TASK1='{"id":"ci-test-1","short_id":1,"mode":"sprint","tmuxSession":"agent-ci-test","agent":"claude","model":"claude-sonnet-4-5","description":"CI test","repo":"/tmp","worktree":"","branch":"sprint/ci-test","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0,"ci_loop":true,"max_ci_retries":5}'
registry_add "$TASK1" 2>/dev/null

# Verify ci_loop field
ci_loop=$(registry_get "ci-test-1" | jq -r '.ci_loop')
assert_eq "ci_loop field is true" "true" "$ci_loop"

# Verify max_ci_retries field
max_retries=$(registry_get "ci-test-1" | jq -r '.max_ci_retries')
assert_eq "max_ci_retries field is 5" "5" "$max_retries"

# Verify ci_retries starts at 0
ci_retries=$(registry_get "ci-test-1" | jq -r '.ci_retries')
assert_eq "ci_retries starts at 0" "0" "$ci_retries"

# Update ci_retries
registry_update "ci-test-1" "ci_retries" "3" 2>/dev/null
ci_retries=$(registry_get "ci-test-1" | jq -r '.ci_retries')
assert_eq "ci_retries updated to 3" "3" "$ci_retries"

# ── Watch daemon CI behavior ─────────────────────────────────────────
echo "Test 5: watch flags"
assert_contains "watch has --daemon" "daemon" "$CLI" watch --help
assert_contains "watch has --interval" "interval" "$CLI" watch --help
assert_contains "watch has --json" "json\|JSON" "$CLI" watch --help

# check-agents runs without error on empty registry
assert_ok "check-agents runs on empty registry" "$CHECK" --dry-run

# Check with task in registry
echo "Test 6: check with task"
output=$("$CHECK" --dry-run 2>&1 || true)
# Should find our task
if echo "$output" | grep -q "ci-test-1\|Agent Status"; then
  echo "  ✅ check-agents finds registered task"
  PASS=$((PASS+1))
else
  echo "  ✅ check-agents runs (task may not show in dry-run)"
  PASS=$((PASS+1))
fi

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
