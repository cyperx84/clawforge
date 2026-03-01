#!/usr/bin/env bash
# review-pr.sh — Module 5: Multi-model code review
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: review-pr.sh --repo <path> --pr <number> [options]

Options:
  --repo <path>           Path to the git repository (required)
  --pr <number>           PR number to review (required)
  --reviewers <list>      Comma-separated reviewer models (default: claude)
  --dry-run               Show what would happen without executing
  --help                  Show this help
EOF
}

REPO="" PR_NUMBER="" REVIEWERS="" DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)       REPO="$2"; shift 2 ;;
    --pr)         PR_NUMBER="$2"; shift 2 ;;
    --reviewers)  REVIEWERS="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)            log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -z "$REPO" ]]      && { log_error "--repo is required"; usage; exit 1; }
[[ -z "$PR_NUMBER" ]] && { log_error "--pr is required"; usage; exit 1; }

REPO_ABS=$(cd "$REPO" && pwd)

# Default reviewers from config
if [[ -z "$REVIEWERS" ]]; then
  REVIEWERS=$(config_get reviewers "claude" | jq -r 'if type == "array" then join(",") else . end' 2>/dev/null || echo "claude")
fi

REVIEW_PROMPT=$(config_get review_prompt "Review this pull request for:
1. Bugs and logic errors
2. Edge cases and error handling
3. Security issues
4. Performance concerns
5. Code quality and conventions

Respond with: APPROVE, REQUEST_CHANGES, or COMMENT. Then list findings.")

log_info "Reviewing PR #${PR_NUMBER} in ${REPO_ABS}"
log_info "Reviewers: ${REVIEWERS}"

# ── Get PR diff ───────────────────────────────────────────────────────
if $DRY_RUN; then
  log_info "[dry-run] Would fetch diff for PR #${PR_NUMBER}"
  DIFF="[dry-run: diff would be fetched here]"
else
  DIFF=$(gh pr diff "$PR_NUMBER" --repo "$REPO_ABS" 2>/dev/null || true)
  if [[ -z "$DIFF" ]]; then
    log_error "Could not get diff for PR #${PR_NUMBER}"
    exit 1
  fi
fi

# ── Get PR info ───────────────────────────────────────────────────────
PR_TITLE=""
PR_BODY=""
if ! $DRY_RUN; then
  PR_INFO=$(gh pr view "$PR_NUMBER" --repo "$REPO_ABS" --json title,body 2>/dev/null || echo '{}')
  PR_TITLE=$(echo "$PR_INFO" | jq -r '.title // ""')
  PR_BODY=$(echo "$PR_INFO" | jq -r '.body // ""')
fi

# ── Review with each model ────────────────────────────────────────────
IFS=',' read -ra REVIEWER_LIST <<< "$REVIEWERS"
REVIEWS="[]"

for reviewer in "${REVIEWER_LIST[@]}"; do
  reviewer=$(echo "$reviewer" | xargs)  # trim whitespace
  log_info "Getting review from: $reviewer"

  FULL_REVIEW_PROMPT="${REVIEW_PROMPT}

PR Title: ${PR_TITLE}
PR Description: ${PR_BODY}

Diff:
${DIFF}"

  if $DRY_RUN; then
    log_info "[dry-run] Would send diff to $reviewer for review"
    log_info "[dry-run] Prompt starts with: $(echo "$REVIEW_PROMPT" | head -3)"
    REVIEW_RESULT="[dry-run] Review from $reviewer would appear here"
  else
    # Use claude for all reviews (with model flag for different models)
    case "$reviewer" in
      claude)
        REVIEW_RESULT=$(claude --model claude-sonnet-4-5 --dangerously-skip-permissions -p "$FULL_REVIEW_PROMPT" 2>/dev/null || echo "Review failed for $reviewer")
        ;;
      codex)
        REVIEW_RESULT=$(codex --model gpt-5.3-codex -q "$FULL_REVIEW_PROMPT" 2>/dev/null || echo "Review failed for $reviewer")
        ;;
      gemini)
        REVIEW_RESULT=$(claude --model gemini-2.5-pro -p "$FULL_REVIEW_PROMPT" 2>/dev/null || echo "Review failed for $reviewer")
        ;;
      *)
        REVIEW_RESULT=$(claude --model "$reviewer" --dangerously-skip-permissions -p "$FULL_REVIEW_PROMPT" 2>/dev/null || echo "Review failed for $reviewer")
        ;;
    esac
  fi

  # Store review
  review_entry=$(jq -n --arg r "$reviewer" --arg body "$REVIEW_RESULT" '{reviewer: $r, review: $body}')
  REVIEWS=$(echo "$REVIEWS" | jq --argjson entry "$review_entry" '. += [$entry]')

  # Post review comment
  if ! $DRY_RUN; then
    COMMENT_BODY="## 🤖 Review by \`${reviewer}\`

${REVIEW_RESULT}"
    gh pr review "$PR_NUMBER" --repo "$REPO_ABS" --comment --body "$COMMENT_BODY" 2>/dev/null || \
      log_warn "Failed to post review comment for $reviewer"
    log_info "Posted review from $reviewer"
  fi
done

# ── Update registry ───────────────────────────────────────────────────
# Find task by PR number and update
if ! $DRY_RUN; then
  _ensure_registry
  TASK_ID=$(jq -r --argjson pr "$PR_NUMBER" '.tasks[] | select(.pr == $pr) | .id' "$REGISTRY_FILE" 2>/dev/null || true)
  if [[ -n "$TASK_ID" ]]; then
    CHECKS_JSON=$(echo "$REVIEWS" | jq 'reduce .[] as $r ({}; .[$r.reviewer] = ($r.review | split("\n")[0]))')
    registry_update "$TASK_ID" "checks" "$CHECKS_JSON"
    registry_update "$TASK_ID" "status" '"reviewing"'
    log_info "Updated registry for task $TASK_ID"
  fi
fi

# ── Output ─────────────────────────────────────────────────────────────
echo "$REVIEWS" | jq '.'
