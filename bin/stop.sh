#!/usr/bin/env bash
# stop.sh — Stop a running agent
# Usage: clawforge stop <id> [--yes] [--clean]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge stop <id> [flags]

Stop a running agent. Kills the tmux session and marks task as stopped.

Arguments:
  <id>        Task short ID (#1), full ID, or sub-agent ID (3.2)

Flags:
  --yes       Skip confirmation prompt
  --clean     Also remove the worktree
  --help      Show this help

Examples:
  clawforge stop 1
  clawforge stop 3 --yes --clean
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
TASK_REF="" YES=false CLEAN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)    YES=true; shift ;;
    --clean)  CLEAN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --*)      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$TASK_REF" ]]; then
        TASK_REF="$1"
      else
        log_error "Unexpected argument: $1"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$TASK_REF" ]]; then
  log_error "Task ID is required"
  usage
  exit 1
fi

# ── Resolve task ──────────────────────────────────────────────────────
TASK_ID=$(resolve_task_id "$TASK_REF")
if [[ -z "$TASK_ID" ]]; then
  log_error "Could not resolve task: $TASK_REF"
  exit 1
fi

TASK=$(registry_get "$TASK_ID")
if [[ -z "$TASK" ]]; then
  log_error "Task not found: $TASK_ID"
  exit 1
fi

STATUS=$(echo "$TASK" | jq -r '.status')
TMUX_SESSION=$(echo "$TASK" | jq -r '.tmuxSession')
WORKTREE=$(echo "$TASK" | jq -r '.worktree')
DESCRIPTION=$(echo "$TASK" | jq -r '.description' | head -c 50)

# ── Already stopped? ──────────────────────────────────────────────────
if [[ "$STATUS" == "stopped" || "$STATUS" == "archived" ]]; then
  echo "Task $TASK_REF is already $STATUS."
  exit 0
fi

# ── Confirm ───────────────────────────────────────────────────────────
if ! $YES; then
  echo "Stop task $TASK_REF? [$STATUS] \"$DESCRIPTION\""
  $CLEAN && echo "  (will also remove worktree: $WORKTREE)"
  echo -n "  Confirm [y/N]: "
  read -r confirm
  if [[ ! "$confirm" =~ ^[yY] ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

# ── Kill tmux session ─────────────────────────────────────────────────
if [[ -n "$TMUX_SESSION" ]]; then
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  log_info "Killed tmux session: $TMUX_SESSION"
fi

# ── Update registry ───────────────────────────────────────────────────
NOW=$(epoch_ms)
registry_update "$TASK_ID" "status" '"stopped"'
registry_update "$TASK_ID" "completedAt" "$NOW"

# ── Clean worktree if requested ───────────────────────────────────────
if $CLEAN && [[ -n "$WORKTREE" ]] && [[ -d "$WORKTREE" ]]; then
  REPO=$(echo "$TASK" | jq -r '.repo')
  git -C "$REPO" worktree remove "$WORKTREE" --force 2>/dev/null || rm -rf "$WORKTREE"
  log_info "Removed worktree: $WORKTREE"
fi

# ── Also stop sub-agents if this is a swarm parent ────────────────────
MODE=$(echo "$TASK" | jq -r '.mode // ""')
if [[ "$MODE" == "swarm" ]]; then
  SUB_IDS=$(jq -r --arg pid "$TASK_ID" '.tasks[] | select(.parent_id == $pid) | .id' "$REGISTRY_FILE" 2>/dev/null || true)
  if [[ -n "$SUB_IDS" ]]; then
    while IFS= read -r sub_id; do
      SUB_TMUX=$(registry_get "$sub_id" | jq -r '.tmuxSession')
      if [[ -n "$SUB_TMUX" ]]; then
        tmux kill-session -t "$SUB_TMUX" 2>/dev/null || true
      fi
      registry_update "$sub_id" "status" '"stopped"'
      registry_update "$sub_id" "completedAt" "$NOW"
      if $CLEAN; then
        SUB_WT=$(registry_get "$sub_id" | jq -r '.worktree')
        SUB_REPO=$(registry_get "$sub_id" | jq -r '.repo')
        if [[ -n "$SUB_WT" ]] && [[ -d "$SUB_WT" ]]; then
          git -C "$SUB_REPO" worktree remove "$SUB_WT" --force 2>/dev/null || rm -rf "$SUB_WT"
        fi
      fi
      log_info "Stopped sub-agent: $sub_id"
    done <<< "$SUB_IDS"
  fi
fi

echo "Stopped: $TASK_REF ($DESCRIPTION)"
