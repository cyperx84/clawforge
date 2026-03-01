#!/usr/bin/env bash
# test-learn.sh — Test module 9: learn
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
LEARNINGS_FILE="${CLAWFORGE_DIR}/registry/learnings.jsonl"

cleanup() {
  echo '{"tasks":[]}' > "$REGISTRY_FILE"
  rm -f "$LEARNINGS_FILE"
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
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

# Pre-clean
echo "{"tasks":[]}" > "$REGISTRY_FILE"
rm -f "$LEARNINGS_FILE"

echo "=== test-learn.sh ==="

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/learn.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: missing --task-id
echo "Test 2: missing task-id"
if "$BIN_DIR/learn.sh" 2>/dev/null; then
  assert_eq "exits with error" "false" "true"
else
  assert_eq "exits with error" "1" "1"
fi

# Test 3: learn from completed task
echo "Test 3: learn from completed task"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
rm -f "$LEARNINGS_FILE"
NOW=$(epoch_ms)
STARTED=$((NOW - 2700000))  # 45 min ago
registry_add "$(jq -n \
  --argjson started "$STARTED" \
  --argjson completed "$NOW" \
  '{id:"feat-auth",description:"Build auth",status:"done",agent:"claude",model:"claude-sonnet-4-5",retries:0,branch:"feat/auth",startedAt:$started,completedAt:$completed,checks:{"claude":"APPROVE: Looks good"}}')"

output=$("$BIN_DIR/learn.sh" --task-id "feat-auth" --auto 2>/dev/null)
task_id=$(echo "$output" | jq -r '.taskId')
assert_eq "taskId in output" "feat-auth" "$task_id"

success=$(echo "$output" | jq -r '.success')
assert_eq "success is true" "true" "$success"

agent=$(echo "$output" | jq -r '.agent')
assert_eq "agent captured" "claude" "$agent"

duration=$(echo "$output" | jq -r '.duration_minutes')
assert_eq "duration ~45min" "true" "$( [[ "$duration" -ge 40 && "$duration" -le 50 ]] && echo true || echo false )"

notes=$(echo "$output" | jq -r '.notes')
assert_contains "auto-notes generated" "One-shot" "$notes"

# Test 4: JSONL file written
echo "Test 4: JSONL file"
if [[ -f "$LEARNINGS_FILE" ]]; then
  line_count=$(wc -l < "$LEARNINGS_FILE" | tr -d ' ')
  assert_eq "one entry in file" "1" "$line_count"
else
  assert_eq "learnings file exists" "true" "false"
fi

# Test 5: learn failed task
echo "Test 5: learn from failed task"
registry_add "$(jq -n '{id:"fix-bug",description:"Fix bug",status:"failed",agent:"codex",model:"gpt-5.3-codex",retries:3,branch:"fix/bug",startedAt:1000000,completedAt:0,checks:{}}')"
fail_output=$("$BIN_DIR/learn.sh" --task-id "fix-bug" --auto 2>/dev/null)
fail_success=$(echo "$fail_output" | jq -r '.success')
assert_eq "failed task success=false" "false" "$fail_success"

# Test 6: custom tags
echo "Test 6: custom tags"
registry_add "$(jq -n '{id:"refactor-db",description:"Refactor DB",status:"done",agent:"claude",model:"claude-sonnet-4-5",retries:0,branch:"refactor/db",startedAt:1000000,completedAt:2000000,checks:{}}')"
tag_output=$("$BIN_DIR/learn.sh" --task-id "refactor-db" --tags "backend,database" 2>/dev/null)
tags=$(echo "$tag_output" | jq -r '.pattern_tags | join(",")')
assert_eq "custom tags set" "backend,database" "$tags"

# Test 7: summary
echo "Test 7: summary"
summary=$("$BIN_DIR/learn.sh" --summary 2>/dev/null)
assert_contains "summary header" "Learning Summary" "$summary"
assert_contains "shows total" "Total entries:" "$summary"
assert_contains "shows success rate" "Success rate:" "$summary"
assert_contains "shows by agent" "By agent:" "$summary"

# Test 8: auto-tags from branch
echo "Test 8: auto-tags from branch"
# feat-auth should have gotten "feature" tag
feat_tags=$(head -1 "$LEARNINGS_FILE" | jq -r '.pattern_tags | join(",")' 2>/dev/null || echo "")
assert_eq "auto-tagged feature" "feature" "$feat_tags"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
