#!/usr/bin/env bash
# pr.sh — Create a PR from a task's branch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge pr <id> [options]

Create a GitHub PR from a task's branch. Auto-fills title and body from task data.

Arguments:
  <id>                 Task ID or short ID

Options:
  --title <text>       Override PR title (default: task description)
  --body <text>        Override PR body
  --draft              Create as draft PR
  --base <branch>      Base branch (default: main)
  --reviewers <list>   Comma-separated reviewer list
  --labels <list>      Comma-separated label list
  --dry-run            Show what would be created
  --help               Show this help

Examples:
  clawforge pr 1
  clawforge pr 1 --draft
  clawforge pr 1 --reviewers alice,bob --labels enhancement
EOF
}

TASK_REF="" TITLE="" BODY="" DRAFT=false BASE="" REVIEWERS="" LABELS="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)      TITLE="$2"; shift 2 ;;
    --body)       BODY="$2"; shift 2 ;;
    --draft)      DRAFT=true; shift ;;
    --base)       BASE="$2"; shift 2 ;;
    --reviewers)  REVIEWERS="$2"; shift 2 ;;
    --labels)     LABELS="$2"; shift 2 ;;
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
DESC=$(echo "$TASK_DATA" | jq -r '.description // "—"')
BRANCH=$(echo "$TASK_DATA" | jq -r '.branch // empty')
REPO=$(echo "$TASK_DATA" | jq -r '.repo // empty')
WORKTREE=$(echo "$TASK_DATA" | jq -r '.worktree // empty')
MODE=$(echo "$TASK_DATA" | jq -r '.mode // "sprint"')
SHORT_ID=$(echo "$TASK_DATA" | jq -r '.short_id // 0')
EXISTING_PR=$(echo "$TASK_DATA" | jq -r '.pr // empty')

# Check for existing PR
if [[ -n "$EXISTING_PR" && "$EXISTING_PR" != "null" ]]; then
  log_warn "Task #${SHORT_ID} already has PR #${EXISTING_PR}"
  echo "View: gh pr view $EXISTING_PR --repo $REPO"
  exit 0
fi

if [[ -z "$BRANCH" ]]; then
  log_error "No branch found for task #${SHORT_ID}"
  exit 1
fi

# Use worktree or repo for git operations
GIT_DIR=""
if [[ -n "$WORKTREE" && -d "$WORKTREE" ]]; then
  GIT_DIR="$WORKTREE"
elif [[ -n "$REPO" && -d "$REPO" ]]; then
  GIT_DIR="$REPO"
else
  log_error "Neither worktree nor repo directory found"
  exit 1
fi

# Default title from task description
[[ -z "$TITLE" ]] && TITLE="$DESC"

# Default body
if [[ -z "$BODY" ]]; then
  BODY="## Task
${DESC}

## Details
- Mode: ${MODE}
- Task ID: #${SHORT_ID} (${TASK_ID})
- Branch: ${BRANCH}

_Created by ClawForge_"
fi

# Default base branch
if [[ -z "$BASE" ]]; then
  BASE=$(git -C "$GIT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
fi

# Ensure branch is pushed
if ! git -C "$GIT_DIR" ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q "$BRANCH"; then
  if $DRY_RUN; then
    echo "[dry-run] Would push branch: $BRANCH"
  else
    log_info "Pushing branch $BRANCH..."
    git -C "$GIT_DIR" push -u origin "$BRANCH" 2>/dev/null || {
      log_error "Failed to push branch. Check if there are commits."
      exit 1
    }
  fi
fi

# Build gh pr create args
PR_ARGS=(--title "$TITLE" --body "$BODY" --base "$BASE" --head "$BRANCH")
$DRAFT && PR_ARGS+=(--draft)
[[ -n "$REVIEWERS" ]] && PR_ARGS+=(--reviewer "$REVIEWERS")
[[ -n "$LABELS" ]] && PR_ARGS+=(--label "$LABELS")

if $DRY_RUN; then
  echo "=== PR Dry Run ==="
  echo "  Task:      #${SHORT_ID}"
  echo "  Title:     $TITLE"
  echo "  Branch:    $BRANCH → $BASE"
  echo "  Repo:      $GIT_DIR"
  $DRAFT && echo "  Draft:     yes"
  [[ -n "$REVIEWERS" ]] && echo "  Reviewers: $REVIEWERS"
  [[ -n "$LABELS" ]] && echo "  Labels:    $LABELS"
  echo ""
  echo "Body:"
  echo "$BODY"
  exit 0
fi

# Create PR
log_info "Creating PR..."
PR_URL=$(gh pr create "${PR_ARGS[@]}" --repo "$REPO" 2>&1)
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || true)

if [[ -n "$PR_NUMBER" ]]; then
  registry_update "$TASK_ID" "pr" "$PR_NUMBER"
  log_info "PR created: $PR_URL"
fi

echo ""
echo "  #${SHORT_ID}  PR created: $PR_URL"
echo ""
