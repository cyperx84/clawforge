#!/usr/bin/env bash
# test-multi-repo.sh — Test multi-repo swarm (--repos, --repos-file)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
BIN_DIR="${SCRIPT_DIR}/../bin"
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
    # Remove worktrees from all test repos
    for repo in "$TMPDIR"/repo-*; do
      [[ -d "$repo" ]] || continue
      git -C "$repo" worktree list --porcelain 2>/dev/null | grep "^worktree " | while read -r _ wt; do
        [[ "$wt" != "$repo" ]] && git -C "$repo" worktree remove "$wt" --force 2>/dev/null || true
      done
    done
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local desc="$1" expected="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if grep -q "$expected" <<< "$output"; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    FAIL=$((FAIL+1))
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

echo "=== test-multi-repo.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

# Setup: create 3 temp git repos
TMPDIR=$(mktemp -d)
for name in api web shared; do
  mkdir -p "$TMPDIR/repo-$name"
  git -C "$TMPDIR/repo-$name" init -b main >/dev/null 2>&1
  echo "# $name" > "$TMPDIR/repo-$name/README.md"
  git -C "$TMPDIR/repo-$name" add -A
  git -C "$TMPDIR/repo-$name" -c commit.gpgsign=false commit -m "init $name" >/dev/null 2>&1
done

# ── Help text tests ──────────────────────────────────────────────────
echo "Test 1: swarm help shows multi-repo flags"
assert_contains "help shows --repos" "repos" "$BIN_DIR/swarm.sh" --help
assert_contains "help shows --repos-file" "repos-file" "$BIN_DIR/swarm.sh" --help

# ── --repos dry-run ──────────────────────────────────────────────────
echo "Test 2: --repos dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
REPOS_ARG="$TMPDIR/repo-api,$TMPDIR/repo-web,$TMPDIR/repo-shared"
output=$("$BIN_DIR/swarm.sh" --repos "$REPOS_ARG" "Upgrade auth v2 to v3" --dry-run 2>&1 || true)
assert_contains "dry-run shows Multi-Repo" "Multi-Repo" echo "$output"
assert_contains "dry-run shows repo-api" "repo-api" echo "$output"
assert_contains "dry-run shows repo-web" "repo-web" echo "$output"
assert_contains "dry-run shows repo-shared" "repo-shared" echo "$output"
assert_contains "dry-run shows 3 repos" "3" echo "$output"

# Check registry has parent task with multi_repo field
parent_mode=$(jq -r '.tasks[0].mode // empty' "$REGISTRY_FILE")
assert_eq "parent is swarm mode" "swarm" "$parent_mode"
multi_repo=$(jq -r '.tasks[0].multi_repo // empty' "$REGISTRY_FILE")
assert_eq "parent has multi_repo=true" "true" "$multi_repo"
sub_count=$(jq -r '.tasks[0].sub_task_count // empty' "$REGISTRY_FILE")
assert_eq "parent has 3 sub-tasks" "3" "$sub_count"

# ── --repos-file dry-run ─────────────────────────────────────────────
echo "Test 3: --repos-file dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
REPOS_FILE="$TMPDIR/repos.txt"
cat > "$REPOS_FILE" <<EOF
$TMPDIR/repo-api
# this is a comment
$TMPDIR/repo-web
$TMPDIR/repo-shared
EOF
output=$("$BIN_DIR/swarm.sh" --repos-file "$REPOS_FILE" "Add health endpoint" --dry-run 2>&1 || true)
assert_contains "repos-file dry-run shows Multi-Repo" "Multi-Repo" echo "$output"
assert_contains "repos-file shows 3 repos" "3" echo "$output"

# Check comment lines are stripped
sub_count=$(jq -r '.tasks[0].sub_task_count // empty' "$REGISTRY_FILE")
assert_eq "repos-file: 3 sub-tasks (comment stripped)" "3" "$sub_count"

# ── Missing repos-file ───────────────────────────────────────────────
echo "Test 4: missing repos-file errors"
assert_fail "nonexistent repos-file fails" "$BIN_DIR/swarm.sh" --repos-file "/nonexistent/file.txt" "Test task" --dry-run

# ── Invalid repo path ───────────────────────────────────────────────
echo "Test 5: invalid repo path errors"
assert_fail "bad repo path fails" "$BIN_DIR/swarm.sh" --repos "/nonexistent/repo,/also/fake" "Test task" --dry-run

# ── Registry repo field ─────────────────────────────────────────────
echo "Test 6: registry repo field for sub-agents"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
# Manually simulate what multi-repo does to registry
TASK1='{"id":"swarm-test-parent","short_id":1,"mode":"swarm","tmuxSession":"","agent":"multi","model":"multi","description":"Test","repo":"/tmp","worktree":"","branch":"","startedAt":1000,"status":"running","retries":0,"maxRetries":0,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0,"sub_task_count":2,"auto_merge":false,"multi_repo":true}'
registry_add "$TASK1" 2>/dev/null
SUB1='{"id":"swarm-sub-api","short_id":2,"mode":"swarm","tmuxSession":"agent-swarm-sub-api","agent":"claude","model":"claude-sonnet-4-5","description":"Work on api","repo":"/home/user/api","worktree":"/tmp/wt-api","branch":"swarm/api","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0,"parent_id":"swarm-test-parent","sub_index":1,"repo_name":"api"}'
registry_add "$SUB1" 2>/dev/null
SUB2='{"id":"swarm-sub-web","short_id":3,"mode":"swarm","tmuxSession":"agent-swarm-sub-web","agent":"claude","model":"claude-sonnet-4-5","description":"Work on web","repo":"/home/user/web","worktree":"/tmp/wt-web","branch":"swarm/web","startedAt":1000,"status":"running","retries":0,"maxRetries":3,"pr":null,"checks":{},"completedAt":null,"note":null,"files_touched":[],"ci_retries":0,"parent_id":"swarm-test-parent","sub_index":2,"repo_name":"web"}'
registry_add "$SUB2" 2>/dev/null

# Verify repo field on sub-agents
sub1_repo=$(registry_get "swarm-sub-api" | jq -r '.repo')
assert_eq "sub-agent 1 has correct repo" "/home/user/api" "$sub1_repo"
sub1_name=$(registry_get "swarm-sub-api" | jq -r '.repo_name')
assert_eq "sub-agent 1 has repo_name" "api" "$sub1_name"
sub2_repo=$(registry_get "swarm-sub-web" | jq -r '.repo')
assert_eq "sub-agent 2 has correct repo" "/home/user/web" "$sub2_repo"
sub2_name=$(registry_get "swarm-sub-web" | jq -r '.repo_name')
assert_eq "sub-agent 2 has repo_name" "web" "$sub2_name"

# Verify parent has multi_repo
parent_multi=$(registry_get "swarm-test-parent" | jq -r '.multi_repo')
assert_eq "parent has multi_repo=true" "true" "$parent_multi"

# ── Normal swarm still works ─────────────────────────────────────────
echo "Test 7: normal swarm (no --repos) still works"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/swarm.sh" "$TMPDIR/repo-api" "Migrate tests" --dry-run 2>&1 || true)
assert_contains "normal swarm dry-run works" "Decomposition" echo "$output"
# Should NOT have Multi-Repo in output
if grep -q "Multi-Repo" <<< "$output"; then
  echo "  ❌ normal swarm should not show Multi-Repo"
  FAIL=$((FAIL+1))
else
  echo "  ✅ normal swarm does not show Multi-Repo"
  PASS=$((PASS+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
