#!/usr/bin/env bash
# test-foundation.sh — Test v0.4 foundation: short IDs, auto-repo, auto-branch, registry schema
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""
TMPDIR=""

cleanup() {
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
  if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

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

assert_not_empty() {
  local desc="$1" val="$2"
  if [[ -n "$val" ]]; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (empty)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== test-foundation.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# ── slugify_task tests ─────────────────────────────────────────────
echo "Test 1: slugify_task"
slug=$(slugify_task "Add JWT authentication middleware")
assert_eq "basic slugify" "add-jwt-authentication-middleware" "$slug"

slug=$(slugify_task "Fix null pointer in UserService")
assert_eq "slugify with capitals" "fix-null-pointer-in-userservice" "$slug"

slug=$(slugify_task "Add (rate) limiter!!!")
assert_eq "slugify strips special chars" "add-rate-limiter" "$slug"

slug=$(slugify_task "This is a very long task description that should be truncated at forty characters maximum" 40)
assert_eq "slugify truncates to max length" "this-is-a-very-long-task-description-tha" "$slug"

slug=$(slugify_task "  Multiple   spaces   here  ")
assert_eq "slugify collapses spaces" "multiple-spaces-here" "$slug"

# ── auto_branch_name tests ────────────────────────────────────────
echo "Test 2: auto_branch_name"
branch=$(auto_branch_name "sprint" "Add JWT auth")
assert_eq "sprint prefix" "sprint/add-jwt-auth" "$branch"

branch=$(auto_branch_name "quick" "Fix null pointer")
assert_eq "quick prefix" "quick/fix-null-pointer" "$branch"

branch=$(auto_branch_name "swarm" "Migrate tests")
assert_eq "swarm prefix" "swarm/migrate-tests" "$branch"

# Collision detection
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/repo"
git -C "$TMPDIR/repo" init -b main >/dev/null 2>&1
echo "test" > "$TMPDIR/repo/README.md"
git -C "$TMPDIR/repo" add -A
git -C "$TMPDIR/repo" -c commit.gpgsign=false commit -m "init" >/dev/null 2>&1
# Create a branch to collide with
git -C "$TMPDIR/repo" branch "sprint/add-jwt-auth" 2>/dev/null
branch=$(auto_branch_name "sprint" "Add JWT auth" "$TMPDIR/repo")
assert_eq "collision appends -2" "sprint/add-jwt-auth-2" "$branch"

# ── detect_repo tests ─────────────────────────────────────────────
echo "Test 3: detect_repo"
detected=$(detect_repo "$TMPDIR/repo" 2>/dev/null)
assert_eq "detects repo from root" "$TMPDIR/repo" "$detected"

mkdir -p "$TMPDIR/repo/src/deep/nested"
detected=$(detect_repo "$TMPDIR/repo/src/deep/nested" 2>/dev/null)
assert_eq "detects repo from nested dir" "$TMPDIR/repo" "$detected"

if detect_repo "/tmp" 2>/dev/null; then
  assert_eq "fails for non-repo" "false" "true"
else
  assert_eq "fails for non-repo" "true" "true"
fi

# ── Short ID tests ────────────────────────────────────────────────
echo "Test 4: short IDs"

# _next_short_id starts at 1
next=$(_next_short_id)
assert_eq "first short ID is 1" "1" "$next"

# Add a task with short_id
TASK1='{"id":"test-sprint-1","short_id":1,"mode":"sprint","tmuxSession":"agent-test-sprint-1","agent":"claude","model":"claude-sonnet-4-5","description":"Test task","repo":"/tmp","worktree":"/tmp/wt","branch":"sprint/test","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK1" 2>/dev/null

next=$(_next_short_id)
assert_eq "second short ID is 2" "2" "$next"

# resolve_task_id with short ID
resolved=$(resolve_task_id "1")
assert_eq "resolve short ID 1" "test-sprint-1" "$resolved"

resolved=$(resolve_task_id "#1")
assert_eq "resolve #1 with hash" "test-sprint-1" "$resolved"

# resolve_task_id with full ID
resolved=$(resolve_task_id "test-sprint-1")
assert_eq "resolve full ID passthrough" "test-sprint-1" "$resolved"

# Add sub-agent task
TASK2='{"id":"test-swarm-1-sub1","short_id":2,"parent_id":"test-sprint-1","sub_index":1,"mode":"swarm","tmuxSession":"agent-test-sub1","agent":"claude","model":"claude-sonnet-4-5","description":"Sub task","repo":"/tmp","worktree":"/tmp/wt2","branch":"swarm/sub1","startedAt":2000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0}'
registry_add "$TASK2" 2>/dev/null

# resolve sub-agent ID (1.1 = sub-agent 1 of task #1)
resolved=$(resolve_task_id "1.1")
assert_eq "resolve sub-agent 1.1" "test-swarm-1-sub1" "$resolved"

# ── Registry schema enhancements ──────────────────────────────────
echo "Test 5: registry schema — new fields"

# Verify mode field
mode=$(registry_get "test-sprint-1" | jq -r '.mode')
assert_eq "mode field exists" "sprint" "$mode"

# Verify short_id field
sid=$(registry_get "test-sprint-1" | jq -r '.short_id')
assert_eq "short_id field exists" "1" "$sid"

# Verify files_touched field
ft=$(registry_get "test-sprint-1" | jq -r '.files_touched | length')
assert_eq "files_touched is empty array" "0" "$ft"

# Verify ci_retries field
cr=$(registry_get "test-sprint-1" | jq -r '.ci_retries')
assert_eq "ci_retries starts at 0" "0" "$cr"

# Update files_touched
registry_update "test-sprint-1" "files_touched" '["src/auth.ts","src/middleware.ts"]' 2>/dev/null
ft=$(registry_get "test-sprint-1" | jq -r '.files_touched | length')
assert_eq "files_touched updated" "2" "$ft"

# Update ci_retries
registry_update "test-sprint-1" "ci_retries" '1' 2>/dev/null
cr=$(registry_get "test-sprint-1" | jq -r '.ci_retries')
assert_eq "ci_retries incremented" "1" "$cr"

# ── Config new fields ─────────────────────────────────────────────
echo "Test 6: config new fields"
ci_limit=$(config_get ci_retry_limit 2)
assert_eq "ci_retry_limit exists" "2" "$ci_limit"

ram_warn=$(config_get ram_warn_threshold 3)
assert_eq "ram_warn_threshold exists" "3" "$ram_warn"

auto_simp=$(config_get auto_simplify true)
assert_eq "auto_simplify exists" "true" "$auto_simp"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
