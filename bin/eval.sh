#!/usr/bin/env bash
# eval.sh — Lightweight evaluation logging + weekly summaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

EVAL_DIR="${CLAWFORGE_DIR}/evals"
RUN_LOG_FILE="${EVAL_DIR}/run-log.jsonl"
SCORECARD_FILE="${EVAL_DIR}/scorecard.md"

usage() {
  cat <<USAGE
Usage: eval.sh <command> [options]

Commands:
  log        Append one run-eval entry to evals/run-log.jsonl
  weekly     Print weekly summary from run-log.jsonl
  compare    Compare two weekly summaries
  paths      Show eval file paths

log options:
  --command <name>         Required (sprint|swarm|review|dashboard|memory|init|history)
  --mode <name>            Required (e.g. quick, auto, multi-repo)
  --repo <path/name>       Required
  --status <ok|error|timeout|cancelled>  Required
  --duration-ms <n>        Required
  --retries <n>            Default: 0
  --cost-usd <n>           Default: 0
  --manual <n>             Manual interventions (default: 0)
  --tests-passed <true|false>            Default: true
  --review-comments <n>    Default: 0
  --reopened <true|false>  Default: false
  --reverted <true|false>  Default: false
  --task <text>            Optional
  --notes <text>           Optional

weekly options:
  --week <YYYY-WW>         Optional (default: current local week)

compare options:
  --week-a <YYYY-WW>       Required
  --week-b <YYYY-WW>       Required
USAGE
}

ensure_eval_files() {
  mkdir -p "$EVAL_DIR"
  [[ -f "$RUN_LOG_FILE" ]] || : > "$RUN_LOG_FILE"
  [[ -f "$SCORECARD_FILE" ]] || {
    cat > "$SCORECARD_FILE" <<'SC'
# ClawForge Evaluation Scorecard

See evals/run-log.jsonl for raw run entries.
SC
  }
}

current_week() {
  date +"%G-%V"
}

week_for_ts() {
  local ts="$1"
  python3 - <<PY2
import datetime
ms=int("$ts")
dt=datetime.datetime.fromtimestamp(ms/1000)
print(dt.strftime("%G-%V"))
PY2
}

cmd_log() {
  local command="" mode="" repo="" status="" duration_ms=""
  local retries=0 cost_usd=0 manual=0 tests_passed=true review_comments=0 reopened=false reverted=false
  local task="" notes=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --command) command="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      --repo) repo="$2"; shift 2 ;;
      --status) status="$2"; shift 2 ;;
      --duration-ms) duration_ms="$2"; shift 2 ;;
      --retries) retries="$2"; shift 2 ;;
      --cost-usd) cost_usd="$2"; shift 2 ;;
      --manual) manual="$2"; shift 2 ;;
      --tests-passed) tests_passed="$2"; shift 2 ;;
      --review-comments) review_comments="$2"; shift 2 ;;
      --reopened) reopened="$2"; shift 2 ;;
      --reverted) reverted="$2"; shift 2 ;;
      --task) task="$2"; shift 2 ;;
      --notes) notes="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) log_error "Unknown log option: $1"; usage; exit 1 ;;
    esac
  done

  if [[ -z "$command" || -z "$mode" || -z "$repo" || -z "$status" || -z "$duration_ms" ]]; then
    log_error "Missing required fields for eval log"
    usage
    exit 1
  fi

  ensure_eval_files
  local now_iso now_ms run_id
  now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  now_ms=$(epoch_ms)
  run_id="run-${now_ms}"

  jq -cn     --arg ts "$now_iso"     --arg runId "$run_id"     --arg command "$command"     --arg mode "$mode"     --arg repo "$repo"     --arg task "$task"     --arg status "$status"     --arg notes "$notes"     --argjson durationMs "$duration_ms"     --argjson retries "$retries"     --argjson costUsd "$cost_usd"     --argjson manualInterventions "$manual"     --argjson testsPassed "$tests_passed"     --argjson reviewComments "$review_comments"     --argjson reopened "$reopened"     --argjson reverted "$reverted"     '{
      ts:$ts, runId:$runId, command:$command, mode:$mode, repo:$repo, task:$task,
      status:$status, durationMs:$durationMs, retries:$retries, costUsd:$costUsd,
      manualInterventions:$manualInterventions,
      qualityOutcome:{testsPassed:$testsPassed, reviewComments:$reviewComments, reopened:$reopened, reverted:$reverted},
      notes:$notes
    }' >> "$RUN_LOG_FILE"

  echo "Logged eval run: $run_id"
}

summary_for_week() {
  local week="$1"
  ensure_eval_files

  jq -rc '. as $o | $o + {week:(($o.ts|fromdateiso8601)*1000)}' "$RUN_LOG_FILE" 2>/dev/null |   while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local ts_ms
    ts_ms=$(echo "$line" | jq -r '.week')
    local w
    w=$(week_for_ts "$ts_ms")
    if [[ "$w" == "$week" ]]; then
      echo "$line" | jq -c 'del(.week)'
    fi
  done
}

print_summary() {
  local week="$1"
  local entries
  entries=$(summary_for_week "$week" || true)
  if [[ -z "$entries" ]]; then
    echo "No eval entries for week $week"
    return 0
  fi

  local total ok errors med_dur retries cost manual
  total=$(echo "$entries" | wc -l | tr -d ' ')
  ok=$(echo "$entries" | jq -r 'select(.status=="ok") | .runId' | wc -l | tr -d ' ')
  errors=$((total - ok))
  med_dur=$(echo "$entries" | jq -s 'map(.durationMs) | sort | .[(length/2|floor)]')
  retries=$(echo "$entries" | jq -s 'map(.retries) | add')
  cost=$(echo "$entries" | jq -s 'map(.costUsd) | add')
  manual=$(echo "$entries" | jq -s 'map(.manualInterventions) | add')

  echo "Week: $week"
  echo "Runs: $total"
  echo "Success: $ok/$total"
  echo "Errors: $errors"
  echo "Median duration ms: $med_dur"
  echo "Total retries: $retries"
  echo "Total cost usd: $cost"
  echo "Manual interventions: $manual"

  echo ""
  echo "By command:"
  echo "$entries" | jq -s -r 'group_by(.command)[] | "- \(.[0].command): \(length) runs, \([.[]|select(.status=="ok")]|length) ok"'
}

cmd_weekly() {
  local week
  week=$(current_week)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --week) week="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) log_error "Unknown weekly option: $1"; usage; exit 1 ;;
    esac
  done
  print_summary "$week"
}

cmd_compare() {
  local wa="" wb=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --week-a) wa="$2"; shift 2 ;;
      --week-b) wb="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) log_error "Unknown compare option: $1"; usage; exit 1 ;;
    esac
  done
  if [[ -z "$wa" || -z "$wb" ]]; then
    log_error "compare requires --week-a and --week-b"
    usage
    exit 1
  fi

  echo "=== Week A ($wa) ==="
  print_summary "$wa"
  echo ""
  echo "=== Week B ($wb) ==="
  print_summary "$wb"
}

case "${1:-}" in
  log) shift; cmd_log "$@" ;;
  weekly) shift; cmd_weekly "$@" ;;
  compare) shift; cmd_compare "$@" ;;
  paths)
    ensure_eval_files
    echo "run_log=$RUN_LOG_FILE"
    echo "scorecard=$SCORECARD_FILE"
    ;;
  help|--help|-h|"") usage ;;
  *) log_error "Unknown eval command: $1"; usage; exit 1 ;;
esac
