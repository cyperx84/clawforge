#!/usr/bin/env bash
# spawn-agent.sh — Module 2: Create worktree + tmux + launch coding agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: spawn-agent.sh --repo <path> --branch <name> --task <description> [options]

Options:
  --repo <path>        Path to the git repository (required)
  --branch <name>      Branch name to create (required)
  --task <description> Task description for the agent (required)
  --agent <name>       Agent to use: claude or codex (default: auto-detect)
  --model <model>      Model override
  --effort <level>     Effort level: high, medium, low (default: high)
  --after <id>         Wait for task <id> to complete before spawning
  --dry-run            Do everything except launch the agent
  --help               Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
REPO="" BRANCH="" TASK="" AGENT="" MODEL="" EFFORT="" DRY_RUN=false AFTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     REPO="$2"; shift 2 ;;
    --branch)   BRANCH="$2"; shift 2 ;;
    --task)     TASK="$2"; shift 2 ;;
    --agent)    AGENT="$2"; shift 2 ;;
    --model)    MODEL="$2"; shift 2 ;;
    --effort)   EFFORT="$2"; shift 2 ;;
    --after)    AFTER="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    *)          log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Validate ───────────────────────────────────────────────────────────
[[ -z "$REPO" ]]   && { log_error "--repo is required"; usage; exit 1; }
[[ -z "$BRANCH" ]] && { log_error "--branch is required"; usage; exit 1; }
[[ -z "$TASK" ]]   && { log_error "--task is required"; usage; exit 1; }
[[ -d "$REPO/.git" ]] || [[ -f "$REPO/.git" ]] || { log_error "Not a git repo: $REPO"; exit 1; }

# ── Wait for dependency ──────────────────────────────────────────────
if [[ -n "$AFTER" ]]; then
  log_info "Waiting for task $AFTER to complete before spawning..."
  WAIT_TIMEOUT=${CLAWFORGE_DEP_TIMEOUT:-3600}  # 1 hour default
  ELAPSED=0
  INTERVAL=5
  while [[ $ELAPSED -lt $WAIT_TIMEOUT ]]; do
    DEP_STATUS=""
    if [[ "$AFTER" =~ ^[0-9]+$ ]]; then
      DEP_STATUS=$(jq -r --argjson sid "$AFTER" '.tasks[] | select(.short_id == $sid) | .status' "$REGISTRY_FILE" 2>/dev/null || true)
    else
      DEP_STATUS=$(jq -r --arg id "$AFTER" '.tasks[] | select(.id == $id) | .status' "$REGISTRY_FILE" 2>/dev/null || true)
    fi
    case "$DEP_STATUS" in
      done)
        log_info "Dependency $AFTER completed. Spawning..."
        break
        ;;
      failed|timeout|cancelled)
        log_error "Dependency $AFTER ended with status: $DEP_STATUS. Aborting spawn."
        exit 1
        ;;
      *)
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        ;;
    esac
  done
  if [[ $ELAPSED -ge $WAIT_TIMEOUT ]]; then
    log_error "Dependency wait timed out after ${WAIT_TIMEOUT}s"
    exit 1
  fi
fi

# ── Resolve settings ──────────────────────────────────────────────────
RESOLVED_AGENT=$(detect_agent "${AGENT:-}")
EFFORT="${EFFORT:-$(config_get default_effort high)}"

if [[ -z "$MODEL" ]]; then
  if [[ "$RESOLVED_AGENT" == "claude" ]]; then
    MODEL=$(config_get default_model_claude "claude-sonnet-4-5")
  else
    MODEL=$(config_get default_model_codex "gpt-5.3-codex")
  fi
fi

SAFE_BRANCH=$(sanitize_branch "$BRANCH")
WORKTREE_BASE=$(config_get worktree_base "../worktrees")
REPO_ABS=$(cd "$REPO" && pwd)

# Resolve worktree path relative to repo
if [[ "$WORKTREE_BASE" == ../* ]]; then
  WORKTREE_DIR="$(cd "$REPO_ABS" && cd .. && pwd)/worktrees/${SAFE_BRANCH}"
else
  WORKTREE_DIR="${WORKTREE_BASE}/${SAFE_BRANCH}"
fi

TMUX_SESSION="agent-${SAFE_BRANCH}"
MAX_RETRIES=$(config_get max_retries 3)

log_info "Spawning agent: $RESOLVED_AGENT ($MODEL)"
log_info "Repo: $REPO_ABS"
log_info "Branch: $BRANCH → worktree: $WORKTREE_DIR"
log_info "tmux session: $TMUX_SESSION"

# ── Step 1: Create worktree ───────────────────────────────────────────
if [[ -d "$WORKTREE_DIR" ]]; then
  log_warn "Worktree already exists: $WORKTREE_DIR"
else
  log_info "Creating worktree..."
  mkdir -p "$(dirname "$WORKTREE_DIR")"
  git -C "$REPO_ABS" worktree add "$WORKTREE_DIR" -b "$BRANCH" 2>/dev/null || \
    git -C "$REPO_ABS" worktree add "$WORKTREE_DIR" "$BRANCH" 2>/dev/null || \
    git -C "$REPO_ABS" worktree add "$WORKTREE_DIR" -B "$BRANCH"
fi

# ── Step 2: Install deps ──────────────────────────────────────────────
if [[ -f "$WORKTREE_DIR/package.json" ]]; then
  log_info "Installing dependencies..."
  if ! $DRY_RUN; then
    if [[ -f "$WORKTREE_DIR/pnpm-lock.yaml" ]]; then
      (cd "$WORKTREE_DIR" && pnpm install --frozen-lockfile 2>/dev/null || pnpm install) || true
    else
      (cd "$WORKTREE_DIR" && npm install) || true
    fi
  else
    log_info "[dry-run] Would install deps in $WORKTREE_DIR"
  fi
fi

# ── Step 3: Build prompt (with memory injection) ─────────────────────
MEMORY_SECTION=""
MEMORY_BASE="$HOME/.clawforge/memory"
REPO_NAME=$(basename "$REPO_ABS")
# Try git remote for repo name
REMOTE_URL=$(git -C "$REPO_ABS" config --get remote.origin.url 2>/dev/null || true)
[[ -n "$REMOTE_URL" ]] && REPO_NAME=$(basename "$REMOTE_URL" .git)
MEMORY_FILE="${MEMORY_BASE}/${REPO_NAME}.jsonl"

if [[ -f "$MEMORY_FILE" ]] && [[ -s "$MEMORY_FILE" ]]; then
  MEMORIES=$(tail -20 "$MEMORY_FILE" | jq -r '.text' 2>/dev/null || true)
  if [[ -n "$MEMORIES" ]]; then
    MEMORY_SECTION="
## Project Notes
$MEMORIES
"
    log_info "Injected $(echo "$MEMORIES" | wc -l | tr -d ' ') memories into prompt"
  fi
fi

FULL_PROMPT="${MEMORY_SECTION}$TASK

When complete:
1. Commit your changes with a descriptive message
2. Push the branch: git push origin $BRANCH
3. Create a PR: gh pr create --fill --base main"

# ── Step 4: Register task ─────────────────────────────────────────────
NOW=$(epoch_ms)
TASK_JSON=$(jq -n \
  --arg id "$SAFE_BRANCH" \
  --arg tmux "$TMUX_SESSION" \
  --arg agent "$RESOLVED_AGENT" \
  --arg model "$MODEL" \
  --arg desc "$TASK" \
  --arg repo "$REPO_ABS" \
  --arg wt "$WORKTREE_DIR" \
  --arg branch "$BRANCH" \
  --argjson started "$NOW" \
  --argjson maxRetries "$MAX_RETRIES" \
  '{
    id: $id,
    tmuxSession: $tmux,
    agent: $agent,
    model: $model,
    description: $desc,
    repo: $repo,
    worktree: $wt,
    branch: $branch,
    startedAt: $started,
    status: "spawned",
    retries: 0,
    maxRetries: $maxRetries,
    pr: null,
    checks: {},
    completedAt: null,
    note: null
  }')

registry_add "$TASK_JSON"

# ── Step 5: Launch agent in tmux ──────────────────────────────────────
if $DRY_RUN; then
  log_info "[dry-run] Would create tmux session '$TMUX_SESSION' and launch $RESOLVED_AGENT"
  log_info "[dry-run] Working directory: $WORKTREE_DIR"
  log_info "[dry-run] Prompt: $(echo "$FULL_PROMPT" | head -1)..."
  registry_update "$SAFE_BRANCH" "status" '"running"'
  echo "$TASK_JSON"
  exit 0
fi

# Kill existing session if present (idempotent)
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

# Build agent command
if [[ "$RESOLVED_AGENT" == "claude" ]]; then
  AGENT_CMD="claude --model ${MODEL} --dangerously-skip-permissions -p \"$(echo "$FULL_PROMPT" | sed 's/"/\\"/g')\""
elif [[ "$RESOLVED_AGENT" == "codex" ]]; then
  AGENT_CMD="codex --model ${MODEL} --dangerously-bypass-approvals-and-sandbox \"$(echo "$FULL_PROMPT" | sed 's/"/\\"/g')\""
fi

# Create tmux session and launch
tmux new-session -d -s "$TMUX_SESSION" -c "$WORKTREE_DIR" "$AGENT_CMD"
registry_update "$SAFE_BRANCH" "status" '"running"'

log_info "Agent spawned successfully in tmux session: $TMUX_SESSION"
echo "$TASK_JSON"
