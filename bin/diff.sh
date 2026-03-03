#!/usr/bin/env bash
# diff.sh — Show what an agent has changed without attaching
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge diff <id> [options]

Show git diff for a task's worktree without attaching to the agent.

Arguments:
  <id>                 Task ID or short ID

Options:
  --stat               Show diffstat only (files changed summary)
  --staged             Show staged changes only
  --name-only          Show only file names
  --save <path>        Save diff to file
  --help               Show this help

Examples:
  clawforge diff 1
  clawforge diff 1 --stat
  clawforge diff sprint-jwt --save /tmp/changes.diff
EOF
}

TASK_REF="" STAT=false STAGED=false NAME_ONLY=false SAVE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stat)       STAT=true; shift ;;
    --staged)     STAGED=true; shift ;;
    --name-only)  NAME_ONLY=true; shift ;;
    --save)       SAVE_PATH="$2"; shift 2 ;;
    --help|-h)    usage; exit 0 ;;
    --*)          log_error "Unknown option: $1"; usage; exit 1 ;;
    *)            TASK_REF="$1"; shift ;;
  esac
done

[[ -z "$TASK_REF" ]] && { log_error "Task ID required"; usage; exit 1; }

_ensure_registry

# Resolve task
TASK_DATA=""
if [[ "$TASK_REF" =~ ^[0-9]+$ ]]; then
  TASK_DATA=$(jq -r --argjson sid "$TASK_REF" '.tasks[] | select(.short_id == $sid)' "$REGISTRY_FILE" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  TASK_DATA=$(registry_get "$TASK_REF" 2>/dev/null || true)
fi
if [[ -z "$TASK_DATA" ]]; then
  log_error "Task '$TASK_REF' not found"
  exit 1
fi

WORKTREE=$(echo "$TASK_DATA" | jq -r '.worktree // empty')
BRANCH=$(echo "$TASK_DATA" | jq -r '.branch // empty')
SHORT_ID=$(echo "$TASK_DATA" | jq -r '.short_id // 0')
TASK_ID=$(echo "$TASK_DATA" | jq -r '.id')

if [[ -z "$WORKTREE" || ! -d "$WORKTREE" ]]; then
  log_error "Worktree not found: ${WORKTREE:-'(none)'}. Task may have been cleaned."
  exit 1
fi

# Build git diff args
DIFF_ARGS=()
$STAT && DIFF_ARGS+=(--stat)
$STAGED && DIFF_ARGS+=(--staged)
$NAME_ONLY && DIFF_ARGS+=(--name-only)

# Get default branch for comparison
DEFAULT_BRANCH=$(git -C "$WORKTREE" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")

echo "── Diff for #${SHORT_ID} ($TASK_ID) ──"
echo "Branch: $BRANCH"
echo "Worktree: $WORKTREE"
echo ""

# Show uncommitted changes
UNCOMMITTED=$(git -C "$WORKTREE" diff "${DIFF_ARGS[@]}" 2>/dev/null || true)
COMMITTED=$(git -C "$WORKTREE" diff "${DIFF_ARGS[@]}" "${DEFAULT_BRANCH}...HEAD" 2>/dev/null || true)

OUTPUT=""
if [[ -n "$COMMITTED" ]]; then
  OUTPUT+="── Committed changes (vs ${DEFAULT_BRANCH}) ──"$'\n'
  OUTPUT+="$COMMITTED"$'\n'
fi
if [[ -n "$UNCOMMITTED" ]]; then
  OUTPUT+="── Uncommitted changes ──"$'\n'
  OUTPUT+="$UNCOMMITTED"$'\n'
fi

if [[ -z "$OUTPUT" ]]; then
  echo "(no changes detected)"
else
  if [[ -n "$SAVE_PATH" ]]; then
    echo "$OUTPUT" > "$SAVE_PATH"
    echo "Saved diff to $SAVE_PATH"
  else
    echo "$OUTPUT"
  fi
fi
