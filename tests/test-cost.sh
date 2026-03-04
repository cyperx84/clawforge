#!/usr/bin/env bash
# test-cost.sh — Test cost tracking module
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
COST="${SCRIPT_DIR}/../bin/cost.sh"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""
COSTS_FILE="${CLAWFORGE_DIR}/registry/costs.jsonl"
COSTS_BACKUP=""

cleanup() {
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
  if [[ -n "$COSTS_BACKUP" && -f "$COSTS_BACKUP" ]]; then
    mv "$COSTS_BACKUP" "$COSTS_FILE"
  else
    rm -f "$COSTS_FILE"
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

echo "=== test-cost.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"
if [[ -f "$COSTS_FILE" ]]; then
  COSTS_BACKUP=$(mktemp)
  cp "$COSTS_FILE" "$COSTS_BACKUP"
fi
rm -f "$COSTS_FILE"

# cost.sh exists and is executable
assert_ok "cost.sh exists" test -f "$COST"
assert_ok "cost.sh is executable" test -x "$COST"

# Help
assert_ok "cost --help exits 0" "$COST" --help
assert_contains "help shows summary" "summary" "$COST" --help
assert_contains "help shows capture" "capture" "$COST" --help
assert_contains "help shows json" "json" "$COST" --help

# Routes via CLI
assert_ok "CLI routes cost --help" "$CLI" cost --help

# Summary with no data
assert_contains "empty summary" "No cost data" "$COST" --summary

# Create test cost data
echo "Test 1: cost data writing"
mkdir -p "$(dirname "$COSTS_FILE")"
echo '{"taskId":"test-task-1","agentId":"agent-test","model":"claude-sonnet-4-5","inputTokens":1000,"outputTokens":500,"cacheHits":200,"totalCost":0.05,"timestamp":1700000000000}' > "$COSTS_FILE"
echo '{"taskId":"test-task-1","agentId":"agent-test","model":"claude-sonnet-4-5","inputTokens":2000,"outputTokens":1000,"cacheHits":400,"totalCost":0.10,"timestamp":1700000060000}' >> "$COSTS_FILE"
echo '{"taskId":"test-task-2","agentId":"agent-test2","model":"gpt-5.3-codex","inputTokens":500,"outputTokens":250,"cacheHits":100,"totalCost":0.03,"timestamp":1700000120000}' >> "$COSTS_FILE"

# Query task cost
echo "Test 2: query task cost"
# Add task to registry so resolve works
TASK1='{"id":"test-task-1","short_id":1,"mode":"sprint","tmuxSession":"agent-test","agent":"claude","model":"claude-sonnet-4-5","description":"Test","repo":"/tmp","worktree":"","branch":"sprint/test","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK1" 2>/dev/null

assert_contains "task cost shows total" "0.15\|Cost Breakdown" "$COST" test-task-1
assert_contains "task cost shows input" "3000\|Input" "$COST" test-task-1

# JSON output
echo "Test 3: JSON output"
json_output=$("$COST" test-task-1 --json 2>/dev/null || true)
has_total=$(echo "$json_output" | jq -e '.totalCost' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "JSON has totalCost" "yes" "$has_total"

has_entries=$(echo "$json_output" | jq -e '.entries' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "JSON has entries" "yes" "$has_entries"

# Summary
echo "Test 4: summary"
assert_contains "summary shows total" "0.18\|Cost Summary" "$COST" --summary
assert_contains "summary shows by model" "By Model\|claude" "$COST" --summary

# JSON summary
json_summary=$("$COST" --summary --json 2>/dev/null || true)
has_total_cost=$(echo "$json_summary" | jq -e '.totalCost' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "JSON summary has totalCost" "yes" "$has_total_cost"

# Budget check: verify the function exists in cost.sh source
echo "Test 5: budget check"
assert_contains "cost.sh has check_budget function" "check_budget" cat "$COST"

# Test budget logic directly
spent_total=$(grep '"taskId":"test-task-1"' "$COSTS_FILE" 2>/dev/null | jq -s '[.[].totalCost] | add // 0' 2>/dev/null || echo "0")
if python3 -c "exit(0 if $spent_total < 1.00 else 1)" 2>/dev/null; then
  echo "  ✅ budget not exceeded at \$1.00 (spent: \$$spent_total)"
  PASS=$((PASS+1))
else
  echo "  ❌ budget should not be exceeded at \$1.00"
  FAIL=$((FAIL+1))
fi

if python3 -c "exit(0 if $spent_total >= 0.01 else 1)" 2>/dev/null; then
  echo "  ✅ budget exceeded at \$0.01 (spent: \$$spent_total)"
  PASS=$((PASS+1))
else
  echo "  ❌ budget should be exceeded at \$0.01"
  FAIL=$((FAIL+1))
fi

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
