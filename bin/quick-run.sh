#!/usr/bin/env bash
# quick-run.sh — Zero-overhead direct agent execution in current directory.
# No worktree, no branch, no tmux. Just runs the agent and streams output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge quick-run "<task>" [options]

Run an agent directly in the current (or specified) directory.
No worktree, no branch, no tmux overhead — just streams output to your terminal.

Arguments:
  <task>               Task description (required)

Options:
  --dir <path>         Directory to run in (default: current working directory)
  --agent <name>       Agent to use: claude or codex (default: auto-detect)
  --model <model>      Model override
  --no-track           Don't register in task registry
  --save <file>        Save output to file (in addition to stdout)
  --budget <usd>       Max spend cap (passed to agent if supported)
  --dry-run            Show what would run without executing
  --help               Show this help

Examples:
  clawforge quick-run "Explain what this codebase does"
  clawforge quick-run "Add docstrings to all exported functions" --dir ~/github/mylib
  clawforge quick-run "Fix the failing test" --agent codex --model gpt-5.3-codex
  clawforge quick-run "Summarize recent git changes" --no-track
  clawforge quick-run "Refactor auth.ts" --save /tmp/agent-output.log

Notes:
  - Output streams directly to your terminal (and optionally a file).
  - The agent runs in the target directory with full file access.
  - Results are tracked in the registry (use --no-track to skip).
  - For tasks requiring a branch/PR, use: clawforge sprint "<task>"
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
TASK="" DIR="" AGENT="" MODEL="" NO_TRACK=false SAVE_PATH="" BUDGET="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)      DIR="$2"; shift 2 ;;
    --agent)    AGENT="$2"; shift 2 ;;
    --model)    MODEL="$2"; shift 2 ;;
    --no-track) NO_TRACK=true; shift ;;
    --save)     SAVE_PATH="$2"; shift 2 ;;
    --budget)   BUDGET="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    -*)         log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$TASK" ]]; then
        TASK="$1"; shift
      else
        log_error "Unexpected argument: $1"; usage; exit 1
      fi
      ;;
  esac
done

[[ -z "$TASK" ]] && { log_error "Task description is required"; usage; exit 1; }

# ── Resolve directory ──────────────────────────────────────────────────
if [[ -n "$DIR" ]]; then
  [[ -d "$DIR" ]] || { log_error "Directory not found: $DIR"; exit 1; }
  TARGET_DIR="$(cd "$DIR" && pwd)"
else
  TARGET_DIR="$(pwd)"
fi

# ── Resolve agent ──────────────────────────────────────────────────────
RESOLVED_AGENT=$(detect_agent "${AGENT:-}")
[[ -z "$RESOLVED_AGENT" ]] && { log_error "No agent (claude/codex) found in PATH"; exit 1; }

# ── Resolve model ──────────────────────────────────────────────────────
if [[ -z "$MODEL" ]]; then
  if [[ "$RESOLVED_AGENT" == "claude" ]]; then
    MODEL=$(config_get default_model_claude "claude-sonnet-4-5")
  else
    MODEL=$(config_get default_model_codex "gpt-5.3-codex")
  fi
fi

# ── Build task ID ──────────────────────────────────────────────────────
SAFE_SLUG=$(slugify_task "$TASK" 32)
TASK_ID="qr-${SAFE_SLUG}"
NOW=$(epoch_ms)

# ── Dry-run ────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo "──────────────────────────────────────────"
  echo "  clawforge quick-run [dry-run]"
  echo "──────────────────────────────────────────"
  echo "  task:      $TASK"
  echo "  dir:       $TARGET_DIR"
  echo "  agent:     $RESOLVED_AGENT"
  echo "  model:     $MODEL"
  echo "  track:     $( $NO_TRACK && echo no || echo yes)"
  [[ -n "$SAVE_PATH" ]] && echo "  Save to:   $SAVE_PATH"
  [[ -n "$BUDGET" ]]    && echo "  Budget:    \$$BUDGET"
  echo "──────────────────────────────────────────"
  exit 0
fi

# ── Register task ──────────────────────────────────────────────────────
SHORT_ID=""
if ! $NO_TRACK; then
  _ensure_registry
  TASK_JSON=$(jq -n \
    --arg id "$TASK_ID" \
    --arg agent "$RESOLVED_AGENT" \
    --arg model "$MODEL" \
    --arg desc "$TASK" \
    --arg dir "$TARGET_DIR" \
    --argjson started "$NOW" \
    '{
      id: $id,
      agent: $agent,
      model: $model,
      description: $desc,
      repo: $dir,
      worktree: $dir,
      branch: "",
      mode: "quick-run",
      status: "running",
      started_at: $started,
      files_touched: [],
      ci_retries: 0
    }')
  registry_add "$TASK_JSON"
  SHORT_ID=$(registry_get "$TASK_ID" | jq -r '.short_id // empty')
fi

# ── Set up output capture ──────────────────────────────────────────────
LOG_DIR="${CLAWFORGE_DIR}/registry/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${TASK_ID}.log"

if ! $NO_TRACK; then
  registry_update "$TASK_ID" "log_path" "\"$LOG_FILE\""
fi

# ── Build agent command ────────────────────────────────────────────────
ESCAPED_TASK=$(printf '%s' "$TASK" | sed "s/'/'\\''/g")

if [[ "$RESOLVED_AGENT" == "claude" ]]; then
  BUDGET_FLAG=""
  [[ -n "$BUDGET" ]] && BUDGET_FLAG="--max-budget-usd $BUDGET"
  AGENT_CMD=(claude --model "$MODEL" --dangerously-skip-permissions -p "$TASK" $BUDGET_FLAG)
elif [[ "$RESOLVED_AGENT" == "codex" ]]; then
  AGENT_CMD=(codex --model "$MODEL" --dangerously-bypass-approvals-and-sandbox "$TASK")
fi

# ── Run ────────────────────────────────────────────────────────────────
ID_LABEL=""
[[ -n "$SHORT_ID" ]] && ID_LABEL=" [#${SHORT_ID}]"

echo "──────────────────────────────────────────"
echo "  ⚡ clawforge quick-run${ID_LABEL}"
echo "──────────────────────────────────────────"
echo "  Task:  $TASK"
echo "  Dir:   $TARGET_DIR"
echo "  Agent: $RESOLVED_AGENT ($MODEL)"
echo "──────────────────────────────────────────"
echo ""

EXIT_CODE=0
START_MS=$NOW

if [[ -n "$SAVE_PATH" ]]; then
  (cd "$TARGET_DIR" && "${AGENT_CMD[@]}" 2>&1) | tee "$LOG_FILE" "$SAVE_PATH" || EXIT_CODE=$?
else
  (cd "$TARGET_DIR" && "${AGENT_CMD[@]}" 2>&1) | tee "$LOG_FILE" || EXIT_CODE=$?
fi

END_MS=$(epoch_ms)
DURATION_S=$(( (END_MS - START_MS) / 1000 ))

echo ""
echo "──────────────────────────────────────────"
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "  ✅ Done in ${DURATION_S}s"
else
  echo "  ❌ Agent exited with code $EXIT_CODE (${DURATION_S}s)"
fi
[[ -n "$SAVE_PATH" ]] && echo "  📄 Saved to: $SAVE_PATH"
echo "──────────────────────────────────────────"

# ── Update registry ────────────────────────────────────────────────────
if ! $NO_TRACK; then
  FINAL_STATUS="done"
  [[ $EXIT_CODE -ne 0 ]] && FINAL_STATUS="failed"
  registry_update "$TASK_ID" "status" "\"$FINAL_STATUS\""
  registry_update "$TASK_ID" "finished_at" "$(epoch_ms)"
fi

exit $EXIT_CODE
