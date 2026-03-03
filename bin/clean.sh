#!/usr/bin/env bash
# clean.sh — Module 8: Clean up completed tasks (worktrees, tmux, registry)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

CLEANUP_LOG="${CLAWFORGE_DIR}/registry/cleanup-log.jsonl"
COMPLETED_TASKS="${CLAWFORGE_DIR}/registry/completed-tasks.jsonl"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clean.sh [options]

Options:
  --task-id <id>      Clean a specific task
  --all-done          Clean all tasks with status "done"
  --stale-days <n>    Clean tasks older than N days
  --force             Allow cleaning running tasks
  --dry-run           Show what would be cleaned without doing it
  --help              Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
TASK_ID="" ALL_DONE=false STALE_DAYS="" FORCE=false DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id)     TASK_ID="$2"; shift 2 ;;
    --all-done)    ALL_DONE=true; shift ;;
    --stale-days)  STALE_DAYS="$2"; shift 2 ;;
    --force)       FORCE=true; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help|-h)     usage; exit 0 ;;
    *)             log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$TASK_ID" ]] && ! $ALL_DONE && [[ -z "$STALE_DAYS" ]]; then
  log_error "Specify --task-id, --all-done, or --stale-days"
  usage
  exit 1
fi

_ensure_registry
mkdir -p "$(dirname "$CLEANUP_LOG")"

# ── Clean one task ────────────────────────────────────────────────────
clean_task() {
  local id="$1"
  local task_data
  task_data=$(registry_get "$id")

  if [[ -z "$task_data" ]]; then
    log_warn "Task '$id' not found in registry"
    return 1
  fi

  local status worktree tmux_session repo
  status=$(echo "$task_data" | jq -r '.status')
  worktree=$(echo "$task_data" | jq -r '.worktree // empty')
  tmux_session=$(echo "$task_data" | jq -r '.tmuxSession // empty')
  repo=$(echo "$task_data" | jq -r '.repo // empty')

  # Safety check
  if [[ "$status" == "running" || "$status" == "spawned" ]] && ! $FORCE; then
    log_warn "Skipping '$id' — status is '$status' (use --force to override)"
    return 1
  fi

  local cleaned_items=()

  # Kill tmux session
  if [[ -n "$tmux_session" ]]; then
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
      if $DRY_RUN; then
        echo "[dry-run] Would kill tmux session: $tmux_session"
      else
        tmux kill-session -t "$tmux_session" 2>/dev/null || true
        log_info "Killed tmux session: $tmux_session"
      fi
      cleaned_items+=("tmux:$tmux_session")
    fi
  fi

  # Remove worktree
  if [[ -n "$worktree" && -d "$worktree" ]]; then
    if $DRY_RUN; then
      echo "[dry-run] Would remove worktree: $worktree"
    else
      if [[ -n "$repo" && -d "$repo" ]]; then
        git -C "$repo" worktree remove "$worktree" --force 2>/dev/null || {
          log_warn "git worktree remove failed, removing directory"
          rm -rf "$worktree"
        }
      else
        rm -rf "$worktree"
      fi
      log_info "Removed worktree: $worktree"
    fi
    cleaned_items+=("worktree:$worktree")
  fi

  # Update registry (archive instead of remove)
  if $DRY_RUN; then
    echo "[dry-run] Would archive task: $id"
  else
    registry_update "$id" "status" '"archived"'
    registry_update "$id" "cleanedAt" "$(epoch_ms)"
    log_info "Archived task: $id"
  fi
  cleaned_items+=("registry:$id")

  # Log cleanup
  if ! $DRY_RUN; then
    local log_entry
    log_entry=$(jq -cn \
      --arg id "$id" \
      --arg status "$status" \
      --argjson timestamp "$(epoch_ms)" \
      --argjson items "$(printf '%s\n' "${cleaned_items[@]}" | jq -R . | jq -s .)" \
      '{timestamp: $timestamp, taskId: $id, previousStatus: $status, cleaned: $items}')
    echo "$log_entry" >> "$CLEANUP_LOG"

    # Append to completed-tasks history
    local desc mode agent model started_at completed_at dur_min cost pr
    desc=$(echo "$task_data" | jq -r '.description // "—"')
    mode=$(echo "$task_data" | jq -r '.mode // "—"')
    agent=$(echo "$task_data" | jq -r '.agent // "—"')
    model=$(echo "$task_data" | jq -r '.model // "—"')
    started_at=$(echo "$task_data" | jq -r '.startedAt // 0')
    completed_at=$(echo "$task_data" | jq -r '.completedAt // 0')
    dur_min=0
    if [[ "$started_at" -gt 0 && "$completed_at" -gt 0 ]]; then
      dur_min=$(( (completed_at - started_at) / 60000 ))
    fi
    cost=$(echo "$task_data" | jq -r '.cost // null')
    pr=$(echo "$task_data" | jq -r '.pr // null')

    local hist_entry
    hist_entry=$(jq -cn \
      --arg id "$id" \
      --arg description "$desc" \
      --arg mode "$mode" \
      --arg status "$status" \
      --arg agent "$agent" \
      --arg model "$model" \
      --arg repo "$(echo "$task_data" | jq -r '.repo // ""')" \
      --argjson duration_minutes "$dur_min" \
      --argjson completedAt "$(epoch_ms)" \
      --argjson timestamp "$(epoch_ms)" \
      '{id:$id, description:$description, mode:$mode, status:$status, agent:$agent, model:$model, repo:$repo, duration_minutes:$duration_minutes, completedAt:$completedAt, timestamp:$timestamp}')
    # Add cost and pr only if they exist
    [[ "$cost" != "null" ]] && hist_entry=$(echo "$hist_entry" | jq --arg c "$cost" '. + {cost:$c}')
    [[ "$pr" != "null" ]] && hist_entry=$(echo "$hist_entry" | jq --arg p "$pr" '. + {pr:$p}')
    echo "$hist_entry" >> "$COMPLETED_TASKS"
  fi

  echo "Cleaned: $id (${cleaned_items[*]})"
}

# ── Execute ──────────────────────────────────────────────────────────
CLEANED=0

if [[ -n "$TASK_ID" ]]; then
  clean_task "$TASK_ID" && CLEANED=$((CLEANED + 1))
fi

if $ALL_DONE; then
  DONE_IDS=$(jq -r '.tasks[] | select(.status == "done") | .id' "$REGISTRY_FILE" 2>/dev/null || true)
  if [[ -n "$DONE_IDS" ]]; then
    while IFS= read -r id; do
      clean_task "$id" && CLEANED=$((CLEANED + 1)) || true
    done <<< "$DONE_IDS"
  else
    log_info "No tasks with status 'done'"
  fi
fi

if [[ -n "$STALE_DAYS" ]]; then
  NOW_MS=$(epoch_ms)
  STALE_MS=$((STALE_DAYS * 86400 * 1000))
  CUTOFF=$((NOW_MS - STALE_MS))

  STALE_IDS=$(jq -r --argjson cutoff "$CUTOFF" \
    '.tasks[] | select(.startedAt < $cutoff and .status != "running" and .status != "spawned") | .id' \
    "$REGISTRY_FILE" 2>/dev/null || true)

  if $FORCE; then
    STALE_IDS=$(jq -r --argjson cutoff "$CUTOFF" \
      '.tasks[] | select(.startedAt < $cutoff) | .id' \
      "$REGISTRY_FILE" 2>/dev/null || true)
  fi

  if [[ -n "$STALE_IDS" ]]; then
    while IFS= read -r id; do
      clean_task "$id" && CLEANED=$((CLEANED + 1)) || true
    done <<< "$STALE_IDS"
  else
    log_info "No stale tasks older than $STALE_DAYS days"
  fi
fi

echo ""
echo "Total cleaned: $CLEANED"
