#!/usr/bin/env bash
# doctor.sh — Diagnose and fix orphaned resources
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge doctor [options]

Diagnose orphaned sessions, dangling worktrees, stale tasks, and disk usage.

Options:
  --fix       Auto-fix issues (kill orphans, remove dangling, archive stale)
  --json      Output as JSON
  --help      Show this help
EOF
}

FIX=false JSON_OUTPUT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)   FIX=true; shift ;;
    --json)  JSON_OUTPUT=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

_ensure_registry
ISSUES=0 FIXED=0

check() {
  local level="$1" msg="$2"
  case "$level" in
    OK)    echo "  ✅ $msg" ;;
    WARN)  echo "  ⚠️  $msg"; ISSUES=$((ISSUES+1)) ;;
    ERROR) echo "  ❌ $msg"; ISSUES=$((ISSUES+1)) ;;
  esac
}

echo "🩺 ClawForge Doctor"
echo ""

# 1. Registry integrity
echo "── Registry ──────────────────────────────"
if [[ -f "$REGISTRY_FILE" ]]; then
  if jq empty "$REGISTRY_FILE" 2>/dev/null; then
    task_count=$(jq '.tasks | length' "$REGISTRY_FILE")
    check OK "Registry valid ($task_count tasks)"
  else
    check ERROR "Registry JSON is malformed"
    if $FIX; then
      echo '{"tasks":[]}' > "$REGISTRY_FILE"
      echo "    → Fixed: reset registry"
      FIXED=$((FIXED+1))
    fi
  fi

  # Duplicate IDs
  dup_count=$(jq '[.tasks[].id] | group_by(.) | map(select(length > 1)) | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)
  if [[ "$dup_count" -gt 0 ]]; then
    check WARN "Found $dup_count duplicate task IDs"
  else
    check OK "No duplicate IDs"
  fi
else
  check WARN "No registry file found"
fi

# 2. Orphaned tmux sessions
echo ""
echo "── tmux Sessions ─────────────────────────"
TMUX_SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)
REGISTERED_SESSIONS=$(jq -r '.tasks[].tmuxSession // empty' "$REGISTRY_FILE" 2>/dev/null | sort -u || true)
ORPHANS=""

if [[ -n "$TMUX_SESSIONS" ]]; then
  while IFS= read -r sess; do
    # Match clawforge-like session names
    if [[ "$sess" =~ ^agent- ]] || [[ "$sess" =~ ^clawforge- ]] || [[ "$sess" =~ ^sprint ]] || [[ "$sess" =~ ^swarm ]]; then
      if ! echo "$REGISTERED_SESSIONS" | grep -qxF "$sess"; then
        check WARN "Orphaned tmux session: $sess"
        ORPHANS="$ORPHANS $sess"
        if $FIX; then
          tmux kill-session -t "$sess" 2>/dev/null || true
          echo "    → Fixed: killed $sess"
          FIXED=$((FIXED+1))
        fi
      fi
    fi
  done <<< "$TMUX_SESSIONS"
fi
[[ -z "$ORPHANS" ]] && check OK "No orphaned tmux sessions"

# 3. Dangling worktrees
echo ""
echo "── Worktrees ─────────────────────────────"
DANGLING=0
WORKTREES=$(jq -r '.tasks[] | select(.status == "done" or .status == "archived" or .status == "cancelled" or .status == "timeout") | .worktree // empty' "$REGISTRY_FILE" 2>/dev/null || true)

if [[ -n "$WORKTREES" ]]; then
  while IFS= read -r wt; do
    [[ -z "$wt" ]] && continue
    if [[ -d "$wt" ]]; then
      check WARN "Dangling worktree (task complete): $wt"
      DANGLING=$((DANGLING+1))
      if $FIX; then
        rm -rf "$wt" 2>/dev/null || true
        echo "    → Fixed: removed $wt"
        FIXED=$((FIXED+1))
      fi
    fi
  done <<< "$WORKTREES"
fi
[[ $DANGLING -eq 0 ]] && check OK "No dangling worktrees"

# 4. Stale tasks
echo ""
echo "── Stale Tasks ───────────────────────────"
NOW_MS=$(epoch_ms)
STALE_CUTOFF=$((NOW_MS - 7 * 86400 * 1000))  # 7 days
STALE_TASKS=$(jq -r --argjson cutoff "$STALE_CUTOFF"   '.tasks[] | select(.status == "running" and (.startedAt // 0) < $cutoff) | .id'   "$REGISTRY_FILE" 2>/dev/null || true)
STALE_COUNT=0

if [[ -n "$STALE_TASKS" ]]; then
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    check WARN "Stale running task (>7 days): $id"
    STALE_COUNT=$((STALE_COUNT+1))
    if $FIX; then
      registry_update "$id" "status" '"archived"'
      echo "    → Fixed: archived $id"
      FIXED=$((FIXED+1))
    fi
  done <<< "$STALE_TASKS"
fi
[[ $STALE_COUNT -eq 0 ]] && check OK "No stale tasks"

# 5. Merged branches not cleaned
echo ""
echo "── Branches ──────────────────────────────"
BRANCH_ISSUES=0
TASK_BRANCHES=$(jq -r '.tasks[] | select(.status == "done" or .status == "archived") | .branch // empty' "$REGISTRY_FILE" 2>/dev/null || true)
TASK_REPOS=$(jq -r '.tasks[] | select(.status == "done" or .status == "archived") | .repo // empty' "$REGISTRY_FILE" 2>/dev/null | sort -u || true)

if [[ -n "$TASK_REPOS" ]]; then
  while IFS= read -r repo; do
    [[ -z "$repo" || ! -d "$repo" ]] && continue
    MERGED=$(git -C "$repo" branch --merged 2>/dev/null | grep -E "sprint/|swarm/|quick/" | sed 's/^[* ]*//' || true)
    if [[ -n "$MERGED" ]]; then
      while IFS= read -r br; do
        check WARN "Merged branch not deleted: $br (in $repo)"
        BRANCH_ISSUES=$((BRANCH_ISSUES+1))
        if $FIX; then
          git -C "$repo" branch -d "$br" 2>/dev/null || true
          echo "    → Fixed: deleted $br"
          FIXED=$((FIXED+1))
        fi
      done <<< "$MERGED"
    fi
  done <<< "$TASK_REPOS"
fi
[[ $BRANCH_ISSUES -eq 0 ]] && check OK "No leftover merged branches"

# 6. Disk space
echo ""
echo "── Disk Space ────────────────────────────"
AVAIL_KB=$(df -k . 2>/dev/null | awk 'NR==2{print $4}')
if [[ -n "$AVAIL_KB" ]]; then
  AVAIL_GB=$((AVAIL_KB / 1048576))
  if [[ $AVAIL_GB -lt 1 ]]; then
    check ERROR "Critically low disk: ${AVAIL_GB}GB free"
  elif [[ $AVAIL_GB -lt 5 ]]; then
    check WARN "Low disk: ${AVAIL_GB}GB free"
  else
    check OK "Disk space: ${AVAIL_GB}GB free"
  fi
else
  check OK "Disk check skipped (df unavailable)"
fi

# Summary
echo ""
echo "────────────────────────────────────────"
if [[ $ISSUES -eq 0 ]]; then
  echo "✅ All checks passed. System is healthy."
else
  echo "Found $ISSUES issue(s)."
  if $FIX; then
    echo "Fixed $FIXED issue(s)."
  else
    echo "Run 'clawforge doctor --fix' to auto-fix."
  fi
fi
