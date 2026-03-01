#!/usr/bin/env bash
# notify.sh — Module 6: Send Discord notifications via openclaw
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: notify.sh [options]

Options:
  --channel <id>      Discord channel target (default: from config)
  --message <text>    Raw message text
  --type <type>       Notification type: task-started, pr-ready, task-failed, task-done
  --task-id <id>      Task ID to look up details from registry
  --description <d>   Description (used with --type if no --task-id)
  --pr <number>       PR number (used with pr-ready type)
  --retry <n/m>       Retry count (used with task-failed type)
  --dry-run           Show command without executing
  --help              Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
CHANNEL="" MESSAGE="" TYPE="" TASK_ID="" DESCRIPTION="" PR_NUM="" RETRY="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel)     CHANNEL="$2"; shift 2 ;;
    --message)     MESSAGE="$2"; shift 2 ;;
    --type)        TYPE="$2"; shift 2 ;;
    --task-id)     TASK_ID="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --pr)          PR_NUM="$2"; shift 2 ;;
    --retry)       RETRY="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help|-h)     usage; exit 0 ;;
    *)             log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Resolve channel ──────────────────────────────────────────────────
if [[ -z "$CHANNEL" ]]; then
  CHANNEL=$(config_get "notify.defaultChannel" "channel:1476433491452498000")
fi

# ── Resolve task details from registry ────────────────────────────────
if [[ -n "$TASK_ID" ]]; then
  TASK_DATA=$(registry_get "$TASK_ID")
  if [[ -n "$TASK_DATA" ]]; then
    [[ -z "$DESCRIPTION" ]] && DESCRIPTION=$(echo "$TASK_DATA" | jq -r '.description // ""')
    [[ -z "$PR_NUM" ]] && PR_NUM=$(echo "$TASK_DATA" | jq -r '.pr // empty' 2>/dev/null || true)
  else
    log_warn "Task '$TASK_ID' not found in registry"
  fi
fi

# ── Build message from type ──────────────────────────────────────────
if [[ -n "$TYPE" && -z "$MESSAGE" ]]; then
  DESC="${DESCRIPTION:-unknown task}"
  case "$TYPE" in
    task-started)  MESSAGE="🔧 Agent spawned for: ${DESC}" ;;
    pr-ready)      MESSAGE="✅ PR #${PR_NUM:-?} ready for review: ${DESC}" ;;
    task-failed)   MESSAGE="❌ Task failed: ${DESC} (retry ${RETRY:-?/?})" ;;
    task-done)     MESSAGE="🎉 Task complete: ${DESC}" ;;
    *)             log_error "Unknown notification type: $TYPE"; exit 1 ;;
  esac
fi

if [[ -z "$MESSAGE" ]]; then
  log_error "No message to send. Use --message or --type"
  usage
  exit 1
fi

# ── Send ─────────────────────────────────────────────────────────────
CMD="openclaw message send --channel discord --target ${CHANNEL} --message \"${MESSAGE}\""

if $DRY_RUN; then
  echo "[dry-run] Would execute:"
  echo "  $CMD"
  exit 0
fi

log_info "Sending notification to $CHANNEL"
openclaw message send --channel discord --target "$CHANNEL" --message "$MESSAGE" 2>/dev/null || {
  log_error "Failed to send notification"
  log_error "Command was: $CMD"
  exit 1
}
log_info "Notification sent"
