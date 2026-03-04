#!/usr/bin/env bash
# replay.sh — Re-run a completed task with the same parameters
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge replay <id> [options]

Re-run a completed task with the same parameters on a fresh worktree.

Arguments:
  <id>                 Task ID or short ID

Options:
  --model <model>      Override model (default: same as original)
  --agent <agent>      Override agent (default: same as original)
  --branch <name>      Override branch name (default: original-retry-N)
  --dry-run            Show what would run
  --help               Show this help

Examples:
  clawforge replay 1
  clawforge replay 1 --model claude-opus-4
  clawforge replay 1 --dry-run
EOF
}

TASK_REF="" MODEL_OVERRIDE="" AGENT_OVERRIDE="" BRANCH_OVERRIDE="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)   MODEL_OVERRIDE="$2"; shift 2 ;;
    --agent)   AGENT_OVERRIDE="$2"; shift 2 ;;
    --branch)  BRANCH_OVERRIDE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --*)       log_error "Unknown option: $1"; usage; exit 1 ;;
    *)         TASK_REF="$1"; shift ;;
  esac
done

[[ -z "$TASK_REF" ]] && { log_error "Task ID required"; usage; exit 1; }

_ensure_registry

# Resolve task (check completed tasks too)
TASK_DATA=""
if [[ "$TASK_REF" =~ ^[0-9]+$ ]]; then
  TASK_DATA=$(jq -r --argjson sid "$TASK_REF" '.tasks[] | select(.short_id == $sid)' "$REGISTRY_FILE" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  TASK_DATA=$(registry_get "$TASK_REF" 2>/dev/null || true)
fi
# Also check completed-tasks.jsonl
if [[ -z "$TASK_DATA" ]]; then
  COMPLETED_FILE="${CLAWFORGE_DIR}/registry/completed-tasks.jsonl"
  if [[ -f "$COMPLETED_FILE" ]]; then
    if [[ "$TASK_REF" =~ ^[0-9]+$ ]]; then
      TASK_DATA=$(jq -r --argjson sid "$TASK_REF" 'select(.short_id == $sid)' "$COMPLETED_FILE" 2>/dev/null | tail -1 || true)
    else
      TASK_DATA=$(jq -r --arg id "$TASK_REF" 'select(.id == $id)' "$COMPLETED_FILE" 2>/dev/null | tail -1 || true)
    fi
  fi
fi

if [[ -z "$TASK_DATA" ]]; then
  log_error "Task '$TASK_REF' not found in active or completed tasks"
  exit 1
fi

# Extract original parameters
ORIG_REPO=$(echo "$TASK_DATA" | jq -r '.repo // empty')
ORIG_BRANCH=$(echo "$TASK_DATA" | jq -r '.branch // empty')
ORIG_TASK=$(echo "$TASK_DATA" | jq -r '.description // empty')
ORIG_AGENT=$(echo "$TASK_DATA" | jq -r '.agent // "claude"')
ORIG_MODEL=$(echo "$TASK_DATA" | jq -r '.model // empty')
ORIG_MODE=$(echo "$TASK_DATA" | jq -r '.mode // "sprint"')
ORIG_EFFORT=$(echo "$TASK_DATA" | jq -r '.effort // "high"')
SHORT_ID=$(echo "$TASK_DATA" | jq -r '.short_id // 0')

# Apply overrides
AGENT="${AGENT_OVERRIDE:-$ORIG_AGENT}"
MODEL="${MODEL_OVERRIDE:-$ORIG_MODEL}"

# Generate retry branch name
if [[ -n "$BRANCH_OVERRIDE" ]]; then
  NEW_BRANCH="$BRANCH_OVERRIDE"
else
  # Find retry number
  RETRY=1
  while true; do
    NEW_BRANCH="${ORIG_BRANCH}-retry-${RETRY}"
    # Check if branch exists
    if [[ -n "$ORIG_REPO" ]] && git -C "$ORIG_REPO" rev-parse --verify "$NEW_BRANCH" >/dev/null 2>&1; then
      RETRY=$((RETRY + 1))
    else
      break
    fi
  done
fi

[[ -z "$ORIG_REPO" ]] && { log_error "Original task has no repo path — can't replay"; exit 1; }
[[ -z "$ORIG_TASK" ]] && { log_error "Original task has no description — can't replay"; exit 1; }

# Show replay plan
echo "🔄 Replaying task #${SHORT_ID}"
echo "  Description: $ORIG_TASK"
echo "  Mode:        $ORIG_MODE"
echo "  Agent:       $AGENT"
echo "  Model:       $MODEL"
echo "  Branch:      $NEW_BRANCH"
echo "  Repo:        $ORIG_REPO"
echo ""

if $DRY_RUN; then
  echo "[dry-run] Would run:"
  echo "  clawforge ${ORIG_MODE} --repo $ORIG_REPO --task \"$ORIG_TASK\" --agent $AGENT --model $MODEL"
  exit 0
fi

# Dispatch based on mode
SPAWN_CMD=(
  "${SCRIPT_DIR}/spawn-agent.sh"
  --repo "$ORIG_REPO"
  --branch "$NEW_BRANCH"
  --task "$ORIG_TASK"
  --agent "$AGENT"
)
[[ -n "$MODEL" ]] && SPAWN_CMD+=(--model "$MODEL")

exec "${SPAWN_CMD[@]}"
