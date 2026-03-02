#!/usr/bin/env bash
# review-mode.sh — Review mode: quality gate on an existing PR
# Usage: clawforge review [repo] --pr <num> [flags]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge review [repo] --pr <num> [flags]

Quality gate on an existing PR. No agent spawned — analysis only.

Arguments:
  [repo]               Path to git repository (default: auto-detect from cwd)

Flags:
  --pr <num>           PR number to review (required)
  --fix                Escalate: spawn agent to fix issues found
  --reviewers <list>   Comma-separated reviewer models (default: claude,gemini)
  --dry-run            Show review without posting comments
  --help               Show this help

Examples:
  clawforge review --pr 42
  clawforge review ~/github/api --pr 42 --fix
  clawforge review --pr 42 --reviewers claude,gemini,codex
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
REPO="" PR="" FIX=false REVIEWERS="" DRY_RUN=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)         PR="$2"; shift 2 ;;
    --fix)        FIX=true; shift ;;
    --reviewers)  REVIEWERS="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    --*)          log_error "Unknown option: $1"; usage; exit 1 ;;
    *)            POSITIONAL+=("$1"); shift ;;
  esac
done

# Positional: optional repo
if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  REPO="${POSITIONAL[0]}"
fi

# ── Validate ──────────────────────────────────────────────────────────
[[ -z "$PR" ]] && { log_error "--pr is required"; usage; exit 1; }

# ── Resolve repo ──────────────────────────────────────────────────────
if [[ -z "$REPO" ]]; then
  REPO=$(detect_repo) || { log_error "No --repo and no git repo found from cwd"; exit 1; }
fi
REPO_ABS=$(cd "$REPO" && pwd)

# ── Resolve reviewers ────────────────────────────────────────────────
if [[ -z "$REVIEWERS" ]]; then
  REVIEWERS=$(config_get reviewers "claude,gemini" | jq -r 'if type == "array" then join(",") else . end' 2>/dev/null || echo "claude,gemini")
fi

# ── Assign short ID ──────────────────────────────────────────────────
SHORT_ID=$(_next_short_id)

# ── Register in registry ─────────────────────────────────────────────
NOW=$(epoch_ms)
TASK_JSON=$(jq -n \
  --arg id "review-pr-${PR}" \
  --argjson sid "$SHORT_ID" \
  --arg desc "Review PR #${PR}" \
  --arg repo "$REPO_ABS" \
  --argjson pr "$PR" \
  --argjson started "$NOW" \
  '{
    id: $id,
    short_id: $sid,
    mode: "review",
    tmuxSession: "",
    agent: "multi",
    model: "multi",
    description: $desc,
    repo: $repo,
    worktree: "",
    branch: "",
    startedAt: $started,
    status: "reviewing",
    retries: 0,
    maxRetries: 0,
    pr: $pr,
    checks: {},
    completedAt: null,
    note: null,
    files_touched: [],
    ci_retries: 0
  }')
registry_add "$TASK_JSON"

log_info "Review mode: PR #$PR in $REPO_ABS"
log_info "Reviewers: $REVIEWERS"
log_info "Short ID: #$SHORT_ID"

# ── Run review ────────────────────────────────────────────────────────
REVIEW_ARGS=(--repo "$REPO_ABS" --pr "$PR" --reviewers "$REVIEWERS")
$DRY_RUN && REVIEW_ARGS+=(--dry-run)

echo ""
echo "  #${SHORT_ID}  review  reviewing  $(basename "$REPO_ABS")  \"Review PR #${PR}\""
echo ""

REVIEW_OUTPUT=$("${SCRIPT_DIR}/review-pr.sh" "${REVIEW_ARGS[@]}" 2>/dev/null || echo "[]")

# Store review results
registry_update "review-pr-${PR}" "checks" "$REVIEW_OUTPUT" 2>/dev/null || true

# ── Fix mode: spawn agent to fix issues ───────────────────────────────
if $FIX && ! $DRY_RUN; then
  log_info "Fix mode: spawning agent to fix issues found in PR #$PR..."

  # Get PR branch HEAD
  PR_BRANCH=$(gh pr view "$PR" --repo "$REPO_ABS" --json headRefName -q '.headRefName' 2>/dev/null || echo "")
  if [[ -z "$PR_BRANCH" ]]; then
    log_error "Could not determine PR branch for --fix"
    exit 1
  fi

  # Build fix prompt from review output
  FIX_PROMPT="Fix the issues found in PR #${PR} code review:

${REVIEW_OUTPUT}

When complete:
1. Commit your fixes
2. Push to the same branch: git push origin ${PR_BRANCH}"

  FIX_BRANCH="$PR_BRANCH"
  RESOLVED_AGENT=$(detect_agent "")

  "${SCRIPT_DIR}/spawn-agent.sh" \
    --repo "$REPO_ABS" \
    --branch "$FIX_BRANCH" \
    --task "$FIX_PROMPT" \
    --agent "$RESOLVED_AGENT" 2>/dev/null || true

  echo "  Agent spawned to fix issues on branch: $FIX_BRANCH"
  echo "  Attach: clawforge attach $SHORT_ID"
fi

# ── Mark complete ─────────────────────────────────────────────────────
if ! $FIX; then
  NOW=$(epoch_ms)
  registry_update "review-pr-${PR}" "status" '"done"'
  registry_update "review-pr-${PR}" "completedAt" "$NOW"
fi

echo ""
echo "  Review complete. Results stored in registry."
echo "$REVIEW_OUTPUT"
