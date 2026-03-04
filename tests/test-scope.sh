#!/usr/bin/env bash
# test-scope.sh — Test module 1: scope-task
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
TMPDIR=""

cleanup() {
  [[ -n "$TMPDIR" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
}
trap cleanup EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"; FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -qF "$needle" <<< "$haystack"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-scope.sh ==="

# Setup: temp vault and files
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/vault" "$TMPDIR/context"
echo "# Auth System\nUse JWT tokens for authentication." > "$TMPDIR/vault/auth-notes.md"
echo "# Database\nPostgres with connection pooling." > "$TMPDIR/vault/db-notes.md"
echo "# PRD: Rate Limiter\nImplement token bucket algorithm." > "$TMPDIR/prd.md"
echo "Additional context about the API." > "$TMPDIR/context/api-notes.md"

# Override vault path for testing
export CLAWFORGE_VAULT_PATH="$TMPDIR/vault"

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/scope-task.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: missing --task
echo "Test 2: missing --task"
if "$BIN_DIR/scope-task.sh" 2>/dev/null; then
  assert_eq "exits with error" "false" "true"
else
  assert_eq "exits with error" "1" "1"
fi

# Test 3: basic prompt output
echo "Test 3: basic prompt output"
output=$("$BIN_DIR/scope-task.sh" --task "Build a rate limiter" 2>/dev/null)
assert_contains "includes task" "Build a rate limiter" "$output"
assert_contains "includes instructions" "Instructions" "$output"

# Test 4: dry-run mode
echo "Test 4: dry-run mode"
dry_output=$("$BIN_DIR/scope-task.sh" --task "Test task" --dry-run 2>/dev/null)
assert_contains "dry-run header" "Scope Dry Run" "$dry_output"
assert_contains "shows task" "Test task" "$dry_output"

# Test 5: JSON output
echo "Test 5: JSON output"
json_output=$("$BIN_DIR/scope-task.sh" --task "JSON test task" --output json 2>/dev/null)
task_val=$(echo "$json_output" | jq -r '.task' 2>/dev/null || echo "")
assert_eq "JSON has task field" "JSON test task" "$task_val"
prompt_val=$(echo "$json_output" | jq -r '.prompt' 2>/dev/null || echo "")
assert_contains "JSON has prompt" "JSON test task" "$prompt_val"

# Test 6: PRD inclusion
echo "Test 6: PRD inclusion"
prd_output=$("$BIN_DIR/scope-task.sh" --task "With PRD" --prd "$TMPDIR/prd.md" 2>/dev/null)
assert_contains "includes PRD content" "token bucket" "$prd_output"

# Test 7: context file inclusion
echo "Test 7: context file inclusion"
ctx_output=$("$BIN_DIR/scope-task.sh" --task "With context" --context "$TMPDIR/context/api-notes.md" 2>/dev/null)
assert_contains "includes context" "Additional context" "$ctx_output"

# Test 8: vault search (with temp vault)
echo "Test 8: vault search"
# Temporarily override config vault path — use the script with explicit vault override
# We test by checking that the vault-query flag parses correctly in dry-run
vault_dry=$("$BIN_DIR/scope-task.sh" --task "Auth task" --vault-query "JWT" --dry-run 2>/dev/null || true)
assert_contains "dry-run shows vault query" "JWT" "$vault_dry"

# Test 9: template rendering
echo "Test 9: template rendering"
template_output=$("$BIN_DIR/scope-task.sh" --task "Template test" 2>/dev/null)
assert_contains "template renders task" "Template test" "$template_output"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
