#!/usr/bin/env bash
# check-agents.sh — Module 4: Health check all running agents
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
PID_FILE="${CLAWFORGE_DIR}/watch.pid"

usage() {
  cat <<EOF
Usage: check-agents.sh [options]

Options:
  --json       Output as JSON
  --dry-run    Don't auto-respawn or update registry
  --daemon     Run continuously in background (interval: 5 min)
  --interval N Daemon check interval in seconds (default: 300)
  --stop       Stop the running daemon
  --help       Show this help
EOF
}

JSON_OUTPUT=false
DRY_RUN=false
DAEMON=false
DAEMON_INTERVAL=300
STOP_DAEMON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       JSON_OUTPUT=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --daemon)     DAEMON=true; shift ;;
    --interval)   DAEMON_INTERVAL="$2"; shift 2 ;;
    --stop)       STOP_DAEMON=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)            log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Stop daemon ───────────────────────────────────────────────────────
if $STOP_DAEMON; then
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      rm -f "$PID_FILE"
      echo "Daemon stopped (PID: $PID)"
    else
      rm -f "$PID_FILE"
      echo "Daemon was not running (stale PID file removed)"
    fi
  else
    echo "No daemon running."
  fi
  exit 0
fi

# ── CI auto-feedback loop ────────────────────────────────────────────
_ci_feedback() {
  local id="$1" repo="$2" pr="$3" tmux_session="$4" branch="$5"
  local ci_retries ci_limit

  ci_retries=$(registry_get "$id" | jq -r '.ci_retries // 0')
  # Use per-task max_ci_retries if set, otherwise fall back to config
  ci_limit=$(registry_get "$id" | jq -r '.max_ci_retries // empty' 2>/dev/null || true)
  [[ -z "$ci_limit" ]] && ci_limit=$(config_get ci_retry_limit 2)

  if [[ "$ci_retries" -ge "$ci_limit" ]]; then
    log_warn "CI retry limit reached for $id ($ci_retries/$ci_limit)"
    return 0
  fi

  # Fetch failed CI log
  local ci_log
  ci_log=$(gh run list --repo "$repo" --branch "$branch" --status failure --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
  if [[ -z "$ci_log" ]]; then
    return 0
  fi

  local error_output
  error_output=$(gh run view "$ci_log" --repo "$repo" --log-failed 2>/dev/null | tail -50 || true)
  if [[ -z "$error_output" ]]; then
    return 0
  fi

  # Auto-steer the agent
  local steer_msg="CI failed on your PR. Here is the error output:

${error_output}

Fix the issues and push again."

  if tmux has-session -t "$tmux_session" 2>/dev/null; then
    if [[ ${#steer_msg} -gt 200 ]]; then
      local tmpfile
      tmpfile=$(mktemp)
      echo "$steer_msg" > "$tmpfile"
      tmux load-buffer "$tmpfile"
      tmux paste-buffer -t "$tmux_session"
      tmux send-keys -t "$tmux_session" Enter
      rm -f "$tmpfile"
    else
      tmux send-keys -t "$tmux_session" "$steer_msg" Enter
    fi

    # Increment ci_retries
    local new_retries=$((ci_retries + 1))
    registry_update "$id" "ci_retries" "$new_retries"
    log_info "CI feedback sent to $id (retry $new_retries/$ci_limit)"

    # Notify
    "${SCRIPT_DIR}/notify.sh" --type task-failed --description "CI failed for $id (auto-retry $new_retries)" --dry-run 2>/dev/null || true
  fi
}

_ensure_registry

# ── Check each task ───────────────────────────────────────────────────
TASKS=$(jq -c '.tasks[]' "$REGISTRY_FILE" 2>/dev/null || true)
if [[ -z "$TASKS" ]]; then
  if $JSON_OUTPUT; then
    echo '{"tasks":[],"summary":"No active tasks"}'
  else
    echo "No active tasks in registry."
  fi
  exit 0
fi

RESULTS="[]"

while IFS= read -r task; do
  id=$(echo "$task" | jq -r '.id')
  tmux_session=$(echo "$task" | jq -r '.tmuxSession')
  branch=$(echo "$task" | jq -r '.branch')
  repo=$(echo "$task" | jq -r '.repo')
  status=$(echo "$task" | jq -r '.status')
  retries=$(echo "$task" | jq -r '.retries')
  max_retries=$(echo "$task" | jq -r '.maxRetries')

  new_status="$status"
  pr_number=""
  ci_status=""

  # Skip completed tasks
  if [[ "$status" == "done" ]]; then
    RESULTS=$(echo "$RESULTS" | jq --argjson t "$task" '. += [$t]')
    continue
  fi

  # 1. Check tmux session
  tmux_alive=false
  if tmux has-session -t "$tmux_session" 2>/dev/null; then
    tmux_alive=true
  fi

  # 2. Check for PR
  if [[ -d "$repo" ]]; then
    pr_info=$(gh pr list --repo "$repo" --head "$branch" --json number,state 2>/dev/null || echo "[]")
    pr_number=$(echo "$pr_info" | jq -r '.[0].number // empty' 2>/dev/null || true)
  fi

  # 3. Determine status
  if [[ -n "$pr_number" ]]; then
    new_status="pr-created"
    if ! $DRY_RUN; then
      registry_update "$id" "pr" "$pr_number"
    fi

    # Check CI
    ci_result=$(gh pr checks "$pr_number" --repo "$repo" 2>/dev/null || true)
    if echo "$ci_result" | grep -q "pass"; then
      if ! echo "$ci_result" | grep -qE "fail|pending"; then
        new_status="ci-passing"
      fi
    fi

    # CI auto-feedback loop: if CI failed and agent is alive, steer with error context
    if echo "$ci_result" | grep -q "fail" && $tmux_alive && ! $DRY_RUN; then
      _ci_feedback "$id" "$repo" "$pr_number" "$tmux_session" "$branch"
    fi
  elif ! $tmux_alive; then
    # tmux dead + no PR = failed
    new_status="failed"
    if ! $DRY_RUN && [[ "$retries" -lt "$max_retries" ]]; then
      log_warn "Task $id failed, respawning (retry $((retries + 1))/$max_retries)..."
      new_retries=$((retries + 1))
      registry_update "$id" "retries" "$new_retries"
      registry_update "$id" "status" '"spawned"'

      # Respawn
      worktree=$(echo "$task" | jq -r '.worktree')
      agent=$(echo "$task" | jq -r '.agent')
      model=$(echo "$task" | jq -r '.model')
      desc=$(echo "$task" | jq -r '.description')

      FULL_PROMPT="$desc

When complete:
1. Commit your changes with a descriptive message
2. Push the branch: git push origin $branch
3. Create a PR: gh pr create --fill --base main"

      if [[ "$agent" == "claude" ]]; then
        AGENT_CMD="claude --model ${model} --dangerously-skip-permissions -p \"$(echo "$FULL_PROMPT" | sed 's/"/\\"/g')\""
      else
        AGENT_CMD="codex --model ${model} --dangerously-bypass-approvals-and-sandbox \"$(echo "$FULL_PROMPT" | sed 's/"/\\"/g')\""
      fi

      tmux kill-session -t "$tmux_session" 2>/dev/null || true
      tmux new-session -d -s "$tmux_session" -c "$worktree" "$AGENT_CMD"
      new_status="running"
      log_info "Respawned task $id"
    elif ! $DRY_RUN && [[ "$retries" -ge "$max_retries" ]]; then
      log_error "Task $id failed after $max_retries retries"
      registry_update "$id" "note" '"Max retries exceeded"'
    fi
  elif $tmux_alive; then
    if [[ "$status" == "spawned" ]]; then
      new_status="running"
    fi
  fi

  # Update status
  if [[ "$new_status" != "$status" ]] && ! $DRY_RUN; then
    registry_update "$id" "status" "\"$new_status\""
    if [[ "$new_status" == "done" || "$new_status" == "failed" ]]; then
      registry_update "$id" "completedAt" "$(epoch_ms)"
    fi
  fi

  # Build result entry
  result=$(echo "$task" | jq \
    --arg ns "$new_status" \
    --arg ta "$tmux_alive" \
    --arg pr "${pr_number:-null}" \
    '. + {currentStatus: $ns, tmuxAlive: ($ta == "true"), detectedPR: (if $pr == "null" then null else ($pr | tonumber) end)}')

  RESULTS=$(echo "$RESULTS" | jq --argjson r "$result" '. += [$r]')
done <<< "$TASKS"

# ── Output ─────────────────────────────────────────────────────────────
# ── Output ─────────────────────────────────────────────────────────────
_output_results() {
  if $JSON_OUTPUT; then
    echo "$RESULTS" | jq '{tasks: ., summary: {total: length, running: [.[] | select(.currentStatus == "running")] | length, failed: [.[] | select(.currentStatus == "failed")] | length, done: [.[] | select(.currentStatus == "done")] | length}}'
  else
    echo "=== Agent Status Check ==="
    echo ""
    echo "$RESULTS" | jq -r '.[] | "  [\(.currentStatus)] \(.id) — \(.agent)/\(.model) (tmux: \(.tmuxAlive), PR: \(.detectedPR // "none"))"'
    echo ""
    total=$(echo "$RESULTS" | jq 'length')
    running=$(echo "$RESULTS" | jq '[.[] | select(.currentStatus == "running")] | length')
    echo "Total: $total | Running: $running"
  fi
}

_output_results

# ── Daemon mode ───────────────────────────────────────────────────────
if $DAEMON; then
  # Write PID file
  echo $$ > "$PID_FILE"
  log_info "Watch daemon started (PID: $$, interval: ${DAEMON_INTERVAL}s)"
  log_info "PID file: $PID_FILE"
  log_info "Stop with: clawforge watch --stop"

  _daemon_cleanup() {
    rm -f "$PID_FILE"
    log_info "Watch daemon stopped"
  }
  trap _daemon_cleanup EXIT INT TERM

  while true; do
    sleep "$DAEMON_INTERVAL"

    # Re-run the check (re-read tasks from registry)
    TASKS=$(jq -c '.tasks[]' "$REGISTRY_FILE" 2>/dev/null || true)
    if [[ -z "$TASKS" ]]; then
      log_debug "Daemon: no active tasks"
      continue
    fi

    RESULTS="[]"
    while IFS= read -r task; do
      id=$(echo "$task" | jq -r '.id')
      tmux_session=$(echo "$task" | jq -r '.tmuxSession')
      branch=$(echo "$task" | jq -r '.branch')
      repo=$(echo "$task" | jq -r '.repo')
      status=$(echo "$task" | jq -r '.status')

      if [[ "$status" == "done" || "$status" == "stopped" || "$status" == "archived" ]]; then
        continue
      fi

      new_status="$status"
      tmux_alive=false
      tmux has-session -t "$tmux_session" 2>/dev/null && tmux_alive=true

      pr_number=""
      if [[ -d "$repo" ]]; then
        pr_info=$(gh pr list --repo "$repo" --head "$branch" --json number,state 2>/dev/null || echo "[]")
        pr_number=$(echo "$pr_info" | jq -r '.[0].number // empty' 2>/dev/null || true)
      fi

      if [[ -n "$pr_number" ]]; then
        if [[ "$status" != "pr-created" && "$status" != "ci-passing" && "$status" != "reviewing" ]]; then
          new_status="pr-created"
          registry_update "$id" "pr" "$pr_number"
          "${SCRIPT_DIR}/notify.sh" --type pr-ready --description "$(echo "$task" | jq -r '.description')" --pr "$pr_number" 2>/dev/null || true
        fi

        ci_result=$(gh pr checks "$pr_number" --repo "$repo" 2>/dev/null || true)
        if echo "$ci_result" | grep -q "pass" && ! echo "$ci_result" | grep -qE "fail|pending"; then
          new_status="ci-passing"
        elif echo "$ci_result" | grep -q "fail" && $tmux_alive; then
          _ci_feedback "$id" "$repo" "$pr_number" "$tmux_session" "$branch"
        fi
      elif ! $tmux_alive && [[ "$status" == "running" || "$status" == "spawned" ]]; then
        new_status="failed"
        "${SCRIPT_DIR}/notify.sh" --type task-failed --description "$(echo "$task" | jq -r '.description')" 2>/dev/null || true
      fi

      if [[ "$new_status" != "$status" ]]; then
        registry_update "$id" "status" "\"$new_status\""
        log_info "Daemon: $id status changed: $status → $new_status"
      fi
    done <<< "$TASKS"
  done
fi
