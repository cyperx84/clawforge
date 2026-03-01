#!/usr/bin/env bash
# check-agents.sh — Module 4: Health check all running agents
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: check-agents.sh [options]

Options:
  --json       Output as JSON
  --dry-run    Don't auto-respawn or update registry
  --help       Show this help
EOF
}

JSON_OUTPUT=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     JSON_OUTPUT=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    *)          log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

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
