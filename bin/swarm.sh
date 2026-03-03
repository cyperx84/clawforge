#!/usr/bin/env bash
# swarm.sh — Swarm mode: parallel multi-agent orchestration
# Usage: clawforge swarm [repo] "<task>" [flags]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/routing.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge swarm [repo] "<task>" [flags]

Parallel multi-agent orchestration. Decomposes task, spawns N agents, coordinates.

Arguments:
  [repo]               Path to git repository (default: auto-detect from cwd)
  "<task>"             Task description (required)

Flags:
  --repos <paths>      Comma-separated repo paths (one agent per repo, skips decomposition)
  --repos-file <path>  File with repo paths, one per line
  --routing <strategy> Model routing: auto, cheap, or quality
  --max-agents <N>     Cap parallel agents (default: 3)
  --agent <name>       Force specific agent for all sub-tasks
  --auto-merge         Merge each PR automatically after CI + review
  --template <name>    Apply a task template
  --ci-loop            Enable CI auto-fix feedback loop
  --max-ci-retries <N> Max CI auto-fix retries (default: 3)
  --budget <dollars>   Kill agents if total cost exceeds budget
  --json               Output structured JSON
  --notify             Send OpenClaw event on completion
  --webhook <url>      POST completion payload to URL
  --dry-run            Show decomposition plan without spawning
  --yes                Skip RAM confirmation prompt
  --help               Show this help

Examples:
  clawforge swarm "Migrate all tests from jest to vitest"
  clawforge swarm "Add i18n to all user-facing strings" --max-agents 4
  clawforge swarm --repos ~/api,~/web,~/shared "Upgrade auth v2 to v3"
  clawforge swarm --repos-file repos.txt "Add health endpoint" --routing cheap
  clawforge swarm --template migration "Migrate to TypeScript"
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
REPO="" TASK="" MAX_AGENTS=3 AGENT="" AUTO_MERGE=false DRY_RUN=false SKIP_CONFIRM=false
TEMPLATE="" CI_LOOP=false MAX_CI_RETRIES=3 BUDGET="" JSON_OUTPUT=false NOTIFY=false WEBHOOK=""
REPOS="" REPOS_FILE="" ROUTING="" MULTI_REPO=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos)          REPOS="$2"; shift 2 ;;
    --repos-file)     REPOS_FILE="$2"; shift 2 ;;
    --routing)        ROUTING="$2"; shift 2 ;;
    --max-agents)     MAX_AGENTS="$2"; shift 2 ;;
    --agent)          AGENT="$2"; shift 2 ;;
    --auto-merge)     AUTO_MERGE=true; shift ;;
    --template)       TEMPLATE="$2"; shift 2 ;;
    --ci-loop)        CI_LOOP=true; shift ;;
    --max-ci-retries) MAX_CI_RETRIES="$2"; shift 2 ;;
    --budget)         BUDGET="$2"; shift 2 ;;
    --json)           JSON_OUTPUT=true; shift ;;
    --notify)         NOTIFY=true; shift ;;
    --webhook)        WEBHOOK="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    --yes)            SKIP_CONFIRM=true; shift ;;
    --help|-h)        usage; exit 0 ;;
    --*)              log_error "Unknown option: $1"; usage; exit 1 ;;
    *)                POSITIONAL+=("$1"); shift ;;
  esac
done

# ── Apply template (template < CLI flags) ─────────────────────────────
if [[ -n "$TEMPLATE" ]]; then
  TMPL_FILE=""
  if [[ -f "${CLAWFORGE_DIR}/lib/templates/${TEMPLATE}.json" ]]; then
    TMPL_FILE="${CLAWFORGE_DIR}/lib/templates/${TEMPLATE}.json"
  elif [[ -f "${HOME}/.clawforge/templates/${TEMPLATE}.json" ]]; then
    TMPL_FILE="${HOME}/.clawforge/templates/${TEMPLATE}.json"
  else
    log_error "Template '$TEMPLATE' not found"; exit 1
  fi
  log_info "Applying template: $TEMPLATE"
  TMPL_MAX_AGENTS=$(jq -r '.maxAgents // empty' "$TMPL_FILE" 2>/dev/null || true)
  TMPL_AUTO_MERGE=$(jq -r '.autoMerge // false' "$TMPL_FILE")
  TMPL_CI_LOOP=$(jq -r '.ciLoop // false' "$TMPL_FILE")
  [[ -n "$TMPL_MAX_AGENTS" ]] && MAX_AGENTS="$TMPL_MAX_AGENTS"
  [[ "$TMPL_AUTO_MERGE" == "true" ]] && AUTO_MERGE=true
  [[ "$TMPL_CI_LOOP" == "true" ]] && CI_LOOP=true
fi

# Parse positional args: [repo] "<task>"
case ${#POSITIONAL[@]} in
  0) log_error "Task description is required"; usage; exit 1 ;;
  1) TASK="${POSITIONAL[0]}" ;;
  2) REPO="${POSITIONAL[0]}"; TASK="${POSITIONAL[1]}" ;;
  *) log_error "Too many positional arguments"; usage; exit 1 ;;
esac

# ── Resolve multi-repo paths ─────────────────────────────────────────
REPO_LIST=()
if [[ -n "$REPOS" ]]; then
  IFS=',' read -ra REPO_LIST <<< "$REPOS"
  MULTI_REPO=true
elif [[ -n "$REPOS_FILE" ]]; then
  [[ -f "$REPOS_FILE" ]] || { log_error "Repos file not found: $REPOS_FILE"; exit 1; }
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | xargs)  # strip comments + whitespace
    [[ -n "$line" ]] && REPO_LIST+=("$line")
  done < "$REPOS_FILE"
  MULTI_REPO=true
fi

# Resolve absolute paths for multi-repo
if $MULTI_REPO; then
  RESOLVED_REPOS=()
  for rp in "${REPO_LIST[@]}"; do
    expanded=$(eval echo "$rp")  # expand ~ and env vars
    [[ -d "$expanded" ]] || { log_error "Repo path not found: $rp"; exit 1; }
    RESOLVED_REPOS+=("$(cd "$expanded" && pwd)")
  done
  REPO_LIST=("${RESOLVED_REPOS[@]}")
  # Use first repo as the "primary" for parent task
  REPO="${REPO_LIST[0]}"
fi

# ── Resolve repo (single-repo mode) ─────────────────────────────────
if [[ -z "$REPO" ]]; then
  REPO=$(detect_repo) || { log_error "No --repo and no git repo found from cwd"; exit 1; }
fi
REPO_ABS=$(cd "$REPO" && pwd)

# ── Resolve agent ─────────────────────────────────────────────────────
RESOLVED_AGENT=$(detect_agent "${AGENT:-}")
if [[ "$RESOLVED_AGENT" == "claude" ]]; then
  MODEL=$(config_get default_model_claude "claude-sonnet-4-5")
else
  MODEL=$(config_get default_model_codex "gpt-5.3-codex")
fi

# ── Load routing ─────────────────────────────────────────────────────
if [[ -n "$ROUTING" ]]; then
  load_routing "$ROUTING"
  log_info "Routing: strategy=$ROUTING"
  IMPL_MODEL=$(get_model_for_phase "implement")
  [[ -n "$IMPL_MODEL" ]] && MODEL="$IMPL_MODEL"
fi

# ── RAM warning ───────────────────────────────────────────────────────
AGENT_COUNT=$MAX_AGENTS
$MULTI_REPO && AGENT_COUNT=${#REPO_LIST[@]}
RAM_THRESHOLD=$(config_get ram_warn_threshold 3)
if [[ "$AGENT_COUNT" -gt "$RAM_THRESHOLD" ]] && ! $SKIP_CONFIRM && ! $DRY_RUN; then
  ESTIMATED_RAM=$((AGENT_COUNT * 2))
  echo ""
  echo "  Warning: $AGENT_COUNT agents will use ~${ESTIMATED_RAM}GB RAM (estimated). Continue? [Y/n]"
  read -r confirm
  if [[ "$confirm" =~ ^[nN] ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# ── Multi-repo mode ──────────────────────────────────────────────────
if $MULTI_REPO; then
  # ── Multi-repo: one agent per repo, skip decomposition ────────────
  SUB_TASK_COUNT=${#REPO_LIST[@]}
  log_info "Multi-repo swarm: $SUB_TASK_COUNT repos"

  # Build repo name list for context injection
  REPO_NAMES=()
  for rp in "${REPO_LIST[@]}"; do
    REPO_NAMES+=("$(basename "$rp")")
  done
  ALL_REPO_NAMES=$(IFS=', '; echo "${REPO_NAMES[*]}")

  # ── Assign parent short ID ───────────────────────────────────────
  PARENT_SHORT_ID=$(_next_short_id)
  PARENT_ID="swarm-$(slugify_task "$TASK" 30)"

  # ── Register parent task ─────────────────────────────────────────
  NOW=$(epoch_ms)
  PARENT_JSON=$(jq -n \
    --arg id "$PARENT_ID" \
    --argjson sid "$PARENT_SHORT_ID" \
    --arg desc "$TASK" \
    --arg repo "$REPO_ABS" \
    --argjson started "$NOW" \
    --argjson subcount "$SUB_TASK_COUNT" \
    --arg repos "$ALL_REPO_NAMES" \
    '{
      id: $id,
      short_id: $sid,
      mode: "swarm",
      tmuxSession: "",
      agent: "multi",
      model: "multi",
      description: $desc,
      repo: $repo,
      worktree: "",
      branch: "",
      startedAt: $started,
      status: "running",
      retries: 0,
      maxRetries: 0,
      pr: null,
      checks: {},
      completedAt: null,
      note: null,
      files_touched: [],
      ci_retries: 0,
      sub_task_count: $subcount,
      auto_merge: false,
      multi_repo: true,
      repos: $repos
    }')
  registry_add "$PARENT_JSON"
  $AUTO_MERGE && registry_update "$PARENT_ID" "auto_merge" 'true'
  $CI_LOOP && registry_update "$PARENT_ID" "ci_loop" 'true'
  registry_update "$PARENT_ID" "max_ci_retries" "$MAX_CI_RETRIES"
  [[ -n "$BUDGET" ]] && registry_update "$PARENT_ID" "budget" "$BUDGET"

  # ── Dry-run output ───────────────────────────────────────────────
  if $DRY_RUN; then
    echo "=== Swarm Dry Run (Multi-Repo) ==="
    echo "  Task:       $TASK"
    echo "  Repos:      $ALL_REPO_NAMES"
    echo "  Agent:      $RESOLVED_AGENT ($MODEL)"
    echo "  Short ID:   #$PARENT_SHORT_ID"
    echo "  Sub-tasks:  $SUB_TASK_COUNT (one per repo)"
    echo "  Auto-merge: $AUTO_MERGE"
    [[ -n "$ROUTING" ]] && echo "  Routing:    $ROUTING"
    echo ""
    echo "Repos:"
    for i in $(seq 0 $((SUB_TASK_COUNT - 1))); do
      echo "  #${PARENT_SHORT_ID}.${REPO_NAMES[$i]}: ${REPO_LIST[$i]}"
    done
    echo ""
    echo "Would spawn $SUB_TASK_COUNT agents, one per repo."
    exit 0
  fi

  # ── Spawn one agent per repo ─────────────────────────────────────
  echo ""
  echo "  #${PARENT_SHORT_ID}  swarm  running  multi-repo  \"$(echo "$TASK" | head -c 50)\"  ($SUB_TASK_COUNT repos)"
  echo ""

  for i in $(seq 0 $((SUB_TASK_COUNT - 1))); do
    SUB_INDEX=$((i + 1))
    SUB_REPO="${REPO_LIST[$i]}"
    SUB_REPO_NAME="${REPO_NAMES[$i]}"
    SUB_SHORT_ID=$(_next_short_id)

    # Build repo-aware task prompt
    OTHER_REPOS=$(printf '%s\n' "${REPO_NAMES[@]}" | grep -v "^${SUB_REPO_NAME}$" | paste -sd ', ' -)
    SUB_TASK="You are working on repo: ${SUB_REPO_NAME}. Other repos in this task: ${OTHER_REPOS}.

${TASK}"

    SUB_BRANCH=$(auto_branch_name "swarm" "$TASK" "$SUB_REPO")
    SUB_SAFE=$(sanitize_branch "$SUB_BRANCH")

    log_info "Spawning sub-agent #${PARENT_SHORT_ID}.${SUB_REPO_NAME}: $SUB_REPO"

    # Spawn agent
    SPAWN_ARGS=(--repo "$SUB_REPO" --branch "$SUB_BRANCH" --task "$SUB_TASK")
    [[ -n "${AGENT:-}" ]] && SPAWN_ARGS+=(--agent "$AGENT")
    [[ -n "$MODEL" ]] && SPAWN_ARGS+=(--model "$MODEL")

    "${SCRIPT_DIR}/spawn-agent.sh" "${SPAWN_ARGS[@]}" 2>/dev/null || true

    # Enhance registry entry with swarm + repo metadata
    registry_update "$SUB_SAFE" "short_id" "$SUB_SHORT_ID"
    registry_update "$SUB_SAFE" "mode" '"swarm"'
    registry_update "$SUB_SAFE" "parent_id" "\"$PARENT_ID\""
    registry_update "$SUB_SAFE" "sub_index" "$SUB_INDEX"
    registry_update "$SUB_SAFE" "repo_name" "\"$SUB_REPO_NAME\""
    registry_update "$SUB_SAFE" "repo" "\"$SUB_REPO\""
    registry_update "$SUB_SAFE" "files_touched" '[]'
    registry_update "$SUB_SAFE" "ci_retries" '0'

    echo "  #${PARENT_SHORT_ID}.${SUB_REPO_NAME}  swarm  spawned  $(basename "$SUB_REPO")  \"$(echo "$TASK" | head -c 40)\""
  done

else
  # ── Standard mode: decompose task into sub-tasks ───────────────────
  log_info "Swarm mode: decomposing task into sub-tasks..."
  log_info "Max agents: $MAX_AGENTS"

  # Use Claude to decompose the task into sub-tasks
  DECOMPOSE_PROMPT="Decompose this coding task into ${MAX_AGENTS} or fewer independent sub-tasks that can be worked on in parallel by separate coding agents. Each sub-task should be self-contained and not depend on others.

Task: ${TASK}

Respond with ONLY a JSON array of sub-task descriptions. Example:
[\"Sub-task 1 description\", \"Sub-task 2 description\", \"Sub-task 3 description\"]"

  # Try to decompose using agent, fall back to splitting by sentence
  SUB_TASKS="[]"
  if command -v claude &>/dev/null && ! $DRY_RUN; then
    DECOMPOSED=$(claude --model "$MODEL" -p "$DECOMPOSE_PROMPT" 2>/dev/null || true)
    # Try to extract JSON array from response
    if echo "$DECOMPOSED" | jq -e 'type == "array"' >/dev/null 2>&1; then
      SUB_TASKS="$DECOMPOSED"
    elif echo "$DECOMPOSED" | grep -o '\[.*\]' | jq -e 'type == "array"' >/dev/null 2>&1; then
      SUB_TASKS=$(echo "$DECOMPOSED" | grep -o '\[.*\]' | head -1)
    else
      # Fallback: treat the whole task as one sub-task
      SUB_TASKS=$(jq -n --arg t "$TASK" '[$t]')
    fi
  else
    # Dry-run or no agent: create placeholder sub-tasks
    SUB_TASKS=$(jq -n --arg t "$TASK" --argjson n "$MAX_AGENTS" \
      '[range($n) | "\($t) (part \(. + 1))"]')
  fi

  # Cap to max-agents
  SUB_TASK_COUNT=$(echo "$SUB_TASKS" | jq 'length')
  if [[ "$SUB_TASK_COUNT" -gt "$MAX_AGENTS" ]]; then
    SUB_TASKS=$(echo "$SUB_TASKS" | jq --argjson n "$MAX_AGENTS" '.[0:$n]')
    SUB_TASK_COUNT=$MAX_AGENTS
  fi

  # ── Assign parent short ID ───────────────────────────────────────
  PARENT_SHORT_ID=$(_next_short_id)
  PARENT_ID="swarm-$(slugify_task "$TASK" 30)"

  # ── Register parent task ─────────────────────────────────────────
  NOW=$(epoch_ms)
  PARENT_JSON=$(jq -n \
    --arg id "$PARENT_ID" \
    --argjson sid "$PARENT_SHORT_ID" \
    --arg desc "$TASK" \
    --arg repo "$REPO_ABS" \
    --argjson started "$NOW" \
    --argjson subcount "$SUB_TASK_COUNT" \
    '{
      id: $id,
      short_id: $sid,
      mode: "swarm",
      tmuxSession: "",
      agent: "multi",
      model: "multi",
      description: $desc,
      repo: $repo,
      worktree: "",
      branch: "",
      startedAt: $started,
      status: "running",
      retries: 0,
      maxRetries: 0,
      pr: null,
      checks: {},
      completedAt: null,
      note: null,
      files_touched: [],
      ci_retries: 0,
      sub_task_count: $subcount,
      auto_merge: false
    }')
  registry_add "$PARENT_JSON"
  $AUTO_MERGE && registry_update "$PARENT_ID" "auto_merge" 'true'
  $CI_LOOP && registry_update "$PARENT_ID" "ci_loop" 'true'
  registry_update "$PARENT_ID" "max_ci_retries" "$MAX_CI_RETRIES"
  [[ -n "$BUDGET" ]] && registry_update "$PARENT_ID" "budget" "$BUDGET"

  # ── Dry-run output ───────────────────────────────────────────────
  if $DRY_RUN; then
    echo "=== Swarm Dry Run ==="
    echo "  Task:       $TASK"
    echo "  Repo:       $REPO_ABS"
    echo "  Agent:      $RESOLVED_AGENT ($MODEL)"
    echo "  Short ID:   #$PARENT_SHORT_ID"
    echo "  Sub-tasks:  $SUB_TASK_COUNT"
    echo "  Auto-merge: $AUTO_MERGE"
    [[ -n "$ROUTING" ]] && echo "  Routing:    $ROUTING"
    echo ""
    echo "Decomposition:"
    echo "$SUB_TASKS" | jq -r 'to_entries[] | "  #\(.key + 1): \(.value)"'
    echo ""
    echo "Would spawn $SUB_TASK_COUNT agents, each in own worktree."
    exit 0
  fi

  # ── Spawn sub-agents ─────────────────────────────────────────────
  echo ""
  echo "  #${PARENT_SHORT_ID}  swarm  running  $(basename "$REPO_ABS")  \"$(echo "$TASK" | head -c 50)\"  ($SUB_TASK_COUNT agents)"
  echo ""

  for i in $(seq 0 $((SUB_TASK_COUNT - 1))); do
    SUB_INDEX=$((i + 1))
    SUB_TASK=$(echo "$SUB_TASKS" | jq -r ".[$i]")
    SUB_BRANCH=$(auto_branch_name "swarm" "$SUB_TASK" "$REPO_ABS")
    SUB_SAFE=$(sanitize_branch "$SUB_BRANCH")
    SUB_SHORT_ID=$(_next_short_id)

    log_info "Spawning sub-agent #${PARENT_SHORT_ID}.${SUB_INDEX}: $SUB_TASK"

    # Spawn agent
    SPAWN_ARGS=(--repo "$REPO_ABS" --branch "$SUB_BRANCH" --task "$SUB_TASK")
    [[ -n "${AGENT:-}" ]] && SPAWN_ARGS+=(--agent "$AGENT")
    [[ -n "$MODEL" ]] && SPAWN_ARGS+=(--model "$MODEL")

    "${SCRIPT_DIR}/spawn-agent.sh" "${SPAWN_ARGS[@]}" 2>/dev/null || true

    # Enhance registry entry with swarm metadata
    registry_update "$SUB_SAFE" "short_id" "$SUB_SHORT_ID"
    registry_update "$SUB_SAFE" "mode" '"swarm"'
    registry_update "$SUB_SAFE" "parent_id" "\"$PARENT_ID\""
    registry_update "$SUB_SAFE" "sub_index" "$SUB_INDEX"
    registry_update "$SUB_SAFE" "files_touched" '[]'
    registry_update "$SUB_SAFE" "ci_retries" '0'

    echo "  #${PARENT_SHORT_ID}.${SUB_INDEX}  swarm  spawned  \"$(echo "$SUB_TASK" | head -c 50)\""
  done
fi

# ── Notify ────────────────────────────────────────────────────────────
"${SCRIPT_DIR}/notify.sh" --type task-started --description "Swarm: $TASK ($SUB_TASK_COUNT agents)" --dry-run 2>/dev/null || true

# ── OpenClaw notify ──────────────────────────────────────────────────
if $NOTIFY; then
  openclaw system event --text "ClawForge: swarm started — $TASK (#$PARENT_SHORT_ID, $SUB_TASK_COUNT agents)" --mode now 2>/dev/null || true
fi

# ── Webhook ──────────────────────────────────────────────────────────
if [[ -n "$WEBHOOK" ]]; then
  PAYLOAD=$(jq -cn \
    --arg taskId "$PARENT_ID" \
    --argjson shortId "$PARENT_SHORT_ID" \
    --arg mode "swarm" \
    --arg status "running" \
    --argjson subTaskCount "$SUB_TASK_COUNT" \
    --arg description "$TASK" \
    --arg repo "$REPO_ABS" \
    '{taskId: $taskId, shortId: $shortId, mode: $mode, status: $status, subTaskCount: $subTaskCount, description: $description, repo: $repo}')
  curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK" >/dev/null 2>&1 || log_warn "Webhook POST failed"
fi

# ── Output ────────────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  jq -cn \
    --arg taskId "$PARENT_ID" \
    --argjson shortId "$PARENT_SHORT_ID" \
    --arg mode "swarm" \
    --arg status "running" \
    --argjson subTaskCount "$SUB_TASK_COUNT" \
    --arg description "$TASK" \
    --arg repo "$REPO_ABS" \
    --argjson autoMerge "$AUTO_MERGE" \
    --argjson ciLoop "$CI_LOOP" \
    '{taskId: $taskId, shortId: $shortId, mode: $mode, status: $status, subTaskCount: $subTaskCount, description: $description, repo: $repo, autoMerge: $autoMerge, ciLoop: $ciLoop}'
else
  echo ""
  echo "  All $SUB_TASK_COUNT agents spawned."
  echo "  Status: clawforge status"
  echo "  Attach: clawforge attach ${PARENT_SHORT_ID}.N  (where N is the agent number)"
  echo "  Steer:  clawforge steer ${PARENT_SHORT_ID}.N \"<message>\""
  echo ""
  $CI_LOOP && echo "  CI feedback loop: enabled (max retries: $MAX_CI_RETRIES)"
  [[ -n "$BUDGET" ]] && echo "  Budget cap: \$$BUDGET"
  [[ -n "$ROUTING" ]] && echo "  Routing: $ROUTING"
  echo "  Tip: Run 'clawforge watch --daemon' in another pane for auto-monitoring"
fi
