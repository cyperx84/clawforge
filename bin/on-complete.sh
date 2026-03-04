#!/usr/bin/env bash
# on-complete.sh — Fire completion hooks when a task finishes
# Called by watch daemon or manually after task reaches done/failed/timeout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge on-complete <id> [options]

Fire completion hooks for a finished task. Typically called by watch --daemon.

Arguments:
  <id>              Task ID or short ID

Options:
  --dry-run         Show what would fire without executing
  --help            Show this help

Hooks fired:
  1. OpenClaw event notification (if --notify was set on spawn)
  2. Webhook POST (if --webhook was set on spawn)
  3. Auto-clean (if --auto-clean was set on spawn)
  4. Completion log entry
EOF
}

TASK_REF="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true; shift ;;
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

TASK_ID=$(echo "$TASK_DATA" | jq -r '.id')
STATUS=$(echo "$TASK_DATA" | jq -r '.status')
DESC=$(echo "$TASK_DATA" | jq -r '.description // "—"')
MODE=$(echo "$TASK_DATA" | jq -r '.mode // "—"')
SHORT_ID=$(echo "$TASK_DATA" | jq -r '.short_id // 0')
WEBHOOK=$(echo "$TASK_DATA" | jq -r '.webhook // empty')
NOTIFY=$(echo "$TASK_DATA" | jq -r '.notify // false')
AUTO_CLEAN=$(echo "$TASK_DATA" | jq -r '.auto_clean // false')
REPO=$(echo "$TASK_DATA" | jq -r '.repo // ""')

# Check task is actually complete
case "$STATUS" in
  done|failed|timeout|cancelled) ;;
  *)
    log_warn "Task #${SHORT_ID} status is '$STATUS' — not a terminal state. Skipping hooks."
    exit 0
    ;;
esac

# Check if hooks already fired
HOOKS_FIRED=$(echo "$TASK_DATA" | jq -r '.hooks_fired // false')
if [[ "$HOOKS_FIRED" == "true" ]]; then
  log_info "Hooks already fired for #${SHORT_ID}. Skipping."
  exit 0
fi

log_info "Firing completion hooks for #${SHORT_ID} ($STATUS)"

# 1. OpenClaw notification
if [[ "$NOTIFY" == "true" ]]; then
  EMOJI="✅"
  [[ "$STATUS" == "failed" ]] && EMOJI="❌"
  [[ "$STATUS" == "timeout" ]] && EMOJI="⏰"
  [[ "$STATUS" == "cancelled" ]] && EMOJI="🚫"
  MSG="${EMOJI} ClawForge: ${MODE} #${SHORT_ID} ${STATUS} — ${DESC}"
  if $DRY_RUN; then
    echo "[dry-run] Would send OpenClaw event: $MSG"
  else
    openclaw system event --text "$MSG" --mode now 2>/dev/null || log_warn "OpenClaw notify failed"
    log_info "Sent OpenClaw event"
  fi
fi

# 2. Webhook POST
if [[ -n "$WEBHOOK" ]]; then
  PAYLOAD=$(jq -cn \
    --arg taskId "$TASK_ID" \
    --argjson shortId "$SHORT_ID" \
    --arg mode "$MODE" \
    --arg status "$STATUS" \
    --arg description "$DESC" \
    --arg repo "$REPO" \
    '{event:"task_complete", taskId:$taskId, shortId:$shortId, mode:$mode, status:$status, description:$description, repo:$repo}')
  if $DRY_RUN; then
    echo "[dry-run] Would POST to $WEBHOOK"
    echo "  Payload: $PAYLOAD"
  else
    curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK" >/dev/null 2>&1 || log_warn "Webhook POST failed"
    log_info "Sent webhook to $WEBHOOK"
  fi
fi

# 3. Discord/Slack webhook
DISCORD_WEBHOOK=$(echo "$TASK_DATA" | jq -r '.discord_webhook // empty')
if [[ -z "$DISCORD_WEBHOOK" ]]; then
  DISCORD_WEBHOOK=$(config_get discord_webhook "")
fi
if [[ -n "$DISCORD_WEBHOOK" ]]; then
  EMOJI="✅"
  COLOR=5763719  # green
  [[ "$STATUS" == "failed" ]] && { EMOJI="❌"; COLOR=15548997; }  # red
  [[ "$STATUS" == "timeout" ]] && { EMOJI="⏰"; COLOR=16776960; }  # yellow
  [[ "$STATUS" == "cancelled" ]] && { EMOJI="🚫"; COLOR=10070709; }  # grey

  DISCORD_PAYLOAD=$(jq -cn \
    --arg title "${EMOJI} ClawForge #${SHORT_ID} ${STATUS}" \
    --arg desc "$DESC" \
    --arg mode "$MODE" \
    --arg status "$STATUS" \
    --argjson color "$COLOR" \
    '{embeds:[{title:$title,description:$desc,color:$color,fields:[{name:"Mode",value:$mode,inline:true},{name:"Status",value:$status,inline:true}]}]}')

  if $DRY_RUN; then
    echo "[dry-run] Would send Discord webhook"
  else
    curl -s -X POST -H "Content-Type: application/json" -d "$DISCORD_PAYLOAD" "$DISCORD_WEBHOOK" >/dev/null 2>&1 || log_warn "Discord webhook failed"
    log_info "Sent Discord notification"
  fi
fi

SLACK_WEBHOOK=$(echo "$TASK_DATA" | jq -r '.slack_webhook // empty')
if [[ -z "$SLACK_WEBHOOK" ]]; then
  SLACK_WEBHOOK=$(config_get slack_webhook "")
fi
if [[ -n "$SLACK_WEBHOOK" ]]; then
  EMOJI="✅"
  [[ "$STATUS" == "failed" ]] && EMOJI="❌"
  [[ "$STATUS" == "timeout" ]] && EMOJI="⏰"
  SLACK_PAYLOAD=$(jq -cn \
    --arg text "${EMOJI} ClawForge #${SHORT_ID} ${STATUS}: ${DESC} (${MODE})" \
    '{text:$text}')

  if $DRY_RUN; then
    echo "[dry-run] Would send Slack webhook"
  else
    curl -s -X POST -H "Content-Type: application/json" -d "$SLACK_PAYLOAD" "$SLACK_WEBHOOK" >/dev/null 2>&1 || log_warn "Slack webhook failed"
    log_info "Sent Slack notification"
  fi
fi

# 4. Auto-clean
if [[ "$AUTO_CLEAN" == "true" ]]; then
  if $DRY_RUN; then
    echo "[dry-run] Would auto-clean task #${SHORT_ID}"
  else
    "${SCRIPT_DIR}/clean.sh" --task-id "$TASK_ID" 2>/dev/null || log_warn "Auto-clean failed"
    log_info "Auto-cleaned task #${SHORT_ID}"
  fi
fi

# 5. Mark hooks as fired
if ! $DRY_RUN; then
  registry_update "$TASK_ID" "hooks_fired" 'true' 2>/dev/null || true
fi

# 6. Log completion
COMPLETION_LOG="${CLAWFORGE_DIR}/registry/completions.jsonl"
if ! $DRY_RUN; then
  ENTRY=$(jq -cn \
    --arg id "$TASK_ID" \
    --argjson sid "$SHORT_ID" \
    --arg mode "$MODE" \
    --arg status "$STATUS" \
    --arg desc "$DESC" \
    --argjson ts "$(epoch_ms)" \
    '{timestamp:$ts, taskId:$id, shortId:$sid, mode:$mode, status:$status, description:$desc}')
  echo "$ENTRY" >> "$COMPLETION_LOG"
fi

echo "Hooks fired for #${SHORT_ID} ($STATUS)"
