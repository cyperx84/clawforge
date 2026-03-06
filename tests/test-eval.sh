#!/usr/bin/env bash
# test-eval.sh — Test eval command
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
PASS=0 FAIL=0

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
  if grep -qF -- "$needle" <<< "$haystack"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-eval.sh ==="

# isolate eval dir
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVAL_DIR="$REPO_ROOT/evals"
RUN_LOG="$EVAL_DIR/run-log.jsonl"
SCORECARD="$EVAL_DIR/scorecard.md"

mkdir -p "$EVAL_DIR"
RUN_BAK=""; SCORE_BAK=""
if [[ -f "$RUN_LOG" ]]; then RUN_BAK=$(mktemp); cp "$RUN_LOG" "$RUN_BAK"; fi
if [[ -f "$SCORECARD" ]]; then SCORE_BAK=$(mktemp); cp "$SCORECARD" "$SCORE_BAK"; fi
: > "$RUN_LOG"
[[ -f "$SCORECARD" ]] || : > "$SCORECARD"

cleanup() {
  rm -f "$RUN_LOG" "$SCORECARD"
  [[ -n "$RUN_BAK" && -f "$RUN_BAK" ]] && mv "$RUN_BAK" "$RUN_LOG" || true
  [[ -n "$SCORE_BAK" && -f "$SCORE_BAK" ]] && mv "$SCORE_BAK" "$SCORECARD" || true
}
trap cleanup EXIT

# paths command
paths_out=$("$BIN_DIR/eval.sh" paths 2>/dev/null)
assert_contains "paths includes run_log" "run_log=" "$paths_out"
assert_contains "paths includes scorecard" "scorecard=" "$paths_out"

# help
help_out=$("$BIN_DIR/eval.sh" --help 2>/dev/null)
assert_contains "help has Usage" "Usage:" "$help_out"
assert_contains "help has weekly" "weekly" "$help_out"

# log entries
"$BIN_DIR/eval.sh" log --command sprint --mode quick --repo api --status ok --duration-ms 120000 --cost-usd 0.3 --retries 1 --manual 1 --review-comments 2 --tests-passed true >/dev/null
"$BIN_DIR/eval.sh" log --command swarm --mode multi-repo --repo api,web --status error --duration-ms 240000 --cost-usd 1.7 --retries 2 --manual 3 --tests-passed false >/dev/null

log_lines=$(wc -l < "$RUN_LOG" | tr -d ' ')
assert_eq "two log lines written" "2" "$log_lines"

# weekly summary
week=$(date +"%G-%V")
weekly_out=$("$BIN_DIR/eval.sh" weekly --week "$week" 2>/dev/null)
assert_contains "weekly shows week" "Week: $week" "$weekly_out"
assert_contains "weekly shows runs" "Runs: 2" "$weekly_out"
assert_contains "weekly shows success" "Success: 1/2" "$weekly_out"
assert_contains "weekly shows command breakdown" "- sprint:" "$weekly_out"

# compare
cmp_out=$("$BIN_DIR/eval.sh" compare --week-a "$week" --week-b "$week" 2>/dev/null)
assert_contains "compare shows week A" "=== Week A" "$cmp_out"
assert_contains "compare shows week B" "=== Week B" "$cmp_out"

# top-level route
cli_eval_out=$("$BIN_DIR/clawforge" eval weekly --week "$week" 2>/dev/null)
assert_contains "clawforge eval routes" "Runs: 2" "$cli_eval_out"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
