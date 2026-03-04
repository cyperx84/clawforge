#!/usr/bin/env bash
# multi-review.sh — Run a PR through multiple models and compare feedback
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge multi-review --pr <number> [options]

Run a PR through multiple AI models and compare their review feedback.

Options:
  --pr <number>        PR number (required)
  --repo <path>        Repository path (default: auto-detect)
  --models <list>      Comma-separated model list (default: from config review_models)
  --output <dir>       Save individual reviews to directory
  --diff-only          Show only where models disagree
  --json               Output as JSON
  --dry-run            Show what would run
  --help               Show this help

Examples:
  clawforge multi-review --pr 42
  clawforge multi-review --pr 42 --models "claude-sonnet-4-5,gpt-5.2-codex,claude-opus-4"
  clawforge multi-review --pr 42 --output /tmp/reviews --diff-only
EOF
}

PR="" REPO="" MODELS="" OUTPUT_DIR="" DIFF_ONLY=false JSON_OUTPUT=false DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)        PR="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --models)    MODELS="$2"; shift 2 ;;
    --output)    OUTPUT_DIR="$2"; shift 2 ;;
    --diff-only) DIFF_ONLY=true; shift ;;
    --json)      JSON_OUTPUT=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)   usage; exit 0 ;;
    --*)         log_error "Unknown option: $1"; usage; exit 1 ;;
    *)           shift ;;
  esac
done

[[ -z "$PR" ]] && { log_error "--pr required"; usage; exit 1; }

# Resolve repo
if [[ -z "$REPO" ]]; then
  REPO=$(detect_repo) || { log_error "No repo found"; exit 1; }
fi
REPO_ABS=$(cd "$REPO" && pwd)

# Resolve models
if [[ -z "$MODELS" ]]; then
  MODELS=$(config_get review_models "claude-sonnet-4-5,gpt-5.2-codex")
fi
IFS=',' read -ra MODEL_LIST <<< "$MODELS"
MODEL_COUNT=${#MODEL_LIST[@]}

log_info "Multi-model review: PR #${PR} with ${MODEL_COUNT} models"

# Get PR diff
PR_DIFF=$(gh pr diff "$PR" --repo "$REPO_ABS" 2>/dev/null || true)
if [[ -z "$PR_DIFF" ]]; then
  log_error "Could not fetch diff for PR #${PR}"
  exit 1
fi

PR_TITLE=$(gh pr view "$PR" --repo "$REPO_ABS" --json title -q '.title' 2>/dev/null || echo "PR #${PR}")
PR_BODY=$(gh pr view "$PR" --repo "$REPO_ABS" --json body -q '.body' 2>/dev/null || echo "")

# Build review prompt
REVIEW_PROMPT="Review this pull request. Focus on:
1. Bugs or logic errors
2. Security issues
3. Performance concerns
4. Code style and best practices
5. Missing edge cases or tests

PR: ${PR_TITLE}
${PR_BODY:+Description: ${PR_BODY}}

Diff:
\`\`\`diff
$(echo "$PR_DIFF" | head -500)
\`\`\`

Provide a structured review with severity levels (critical/warning/info) for each finding."

# Dry run
if $DRY_RUN; then
  echo "=== Multi-Review Dry Run ==="
  echo "  PR:     #${PR} — ${PR_TITLE}"
  echo "  Repo:   $REPO_ABS"
  echo "  Models: ${MODELS}"
  echo "  Count:  $MODEL_COUNT"
  [[ -n "$OUTPUT_DIR" ]] && echo "  Output: $OUTPUT_DIR"
  echo ""
  echo "Would run review with each model in parallel."
  exit 0
fi

# Create output dir
REVIEW_DIR="${OUTPUT_DIR:-$(mktemp -d)}"
mkdir -p "$REVIEW_DIR"

# Run reviews in parallel
PIDS=()
for model in "${MODEL_LIST[@]}"; do
  model=$(echo "$model" | xargs)  # trim whitespace
  SAFE_MODEL=$(echo "$model" | tr '/' '-' | tr '.' '-')
  OUT_FILE="${REVIEW_DIR}/review-${SAFE_MODEL}.md"

  log_info "Starting review with $model..."

  (
    if command -v claude &>/dev/null; then
      claude --model "$model" -p "$REVIEW_PROMPT" > "$OUT_FILE" 2>/dev/null
    else
      echo "Model $model: claude CLI not available" > "$OUT_FILE"
    fi
  ) &
  PIDS+=($!)
done

# Wait for all reviews
FAILED=0
for i in "${!PIDS[@]}"; do
  if ! wait "${PIDS[$i]}" 2>/dev/null; then
    FAILED=$((FAILED + 1))
    log_warn "Review with ${MODEL_LIST[$i]} failed"
  fi
done

log_info "All reviews complete ($((MODEL_COUNT - FAILED))/$MODEL_COUNT succeeded)"

# Collect results
REVIEWS=()
for model in "${MODEL_LIST[@]}"; do
  model=$(echo "$model" | xargs)
  SAFE_MODEL=$(echo "$model" | tr '/' '-' | tr '.' '-')
  OUT_FILE="${REVIEW_DIR}/review-${SAFE_MODEL}.md"
  if [[ -f "$OUT_FILE" ]]; then
    REVIEWS+=("$OUT_FILE")
  fi
done

# Generate comparison
if [[ ${#REVIEWS[@]} -gt 1 ]]; then
  COMPARE_FILE="${REVIEW_DIR}/comparison.md"

  {
    echo "# Multi-Model Review Comparison"
    echo "PR #${PR}: ${PR_TITLE}"
    echo "Models: ${MODELS}"
    echo "Date: $(date)"
    echo ""

    for model in "${MODEL_LIST[@]}"; do
      model=$(echo "$model" | xargs)
      SAFE_MODEL=$(echo "$model" | tr '/' '-' | tr '.' '-')
      OUT_FILE="${REVIEW_DIR}/review-${SAFE_MODEL}.md"
      if [[ -f "$OUT_FILE" ]]; then
        echo "---"
        echo "## ${model}"
        echo ""
        cat "$OUT_FILE"
        echo ""
      fi
    done

    echo "---"
    echo "## Summary"
    echo ""
    echo "| Model | Findings |"
    echo "|-------|----------|"
    for model in "${MODEL_LIST[@]}"; do
      model=$(echo "$model" | xargs)
      SAFE_MODEL=$(echo "$model" | tr '/' '-' | tr '.' '-')
      OUT_FILE="${REVIEW_DIR}/review-${SAFE_MODEL}.md"
      if [[ -f "$OUT_FILE" ]]; then
        FINDING_COUNT=$(grep -ciE "critical|warning|bug|issue|error|concern" "$OUT_FILE" 2>/dev/null || echo "0")
        echo "| $model | ~${FINDING_COUNT} findings |"
      fi
    done
  } > "$COMPARE_FILE"
fi

# Output
if $JSON_OUTPUT; then
  jq -n \
    --arg pr "$PR" \
    --arg title "$PR_TITLE" \
    --arg models "$MODELS" \
    --argjson count "$MODEL_COUNT" \
    --argjson failed "$FAILED" \
    --arg dir "$REVIEW_DIR" \
    '{pr:$pr, title:$title, models:$models, modelCount:$count, failed:$failed, outputDir:$dir}'
else
  echo ""
  echo "  Multi-Model Review: PR #${PR}"
  echo "  Models: ${MODELS}"
  echo "  Results: $((MODEL_COUNT - FAILED))/$MODEL_COUNT succeeded"
  echo ""
  echo "  Reviews saved to: $REVIEW_DIR"
  [[ -f "${REVIEW_DIR}/comparison.md" ]] && echo "  Comparison: ${REVIEW_DIR}/comparison.md"
  echo ""

  if ! $DIFF_ONLY && [[ -f "${REVIEW_DIR}/comparison.md" ]]; then
    cat "${REVIEW_DIR}/comparison.md"
  fi
fi
