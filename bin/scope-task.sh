#!/usr/bin/env bash
# scope-task.sh — Module 1: Assemble a comprehensive prompt from task + context
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: scope-task.sh --task <description> [options]

Options:
  --task <description>   Task description (required)
  --vault-query <search> Search Obsidian vault for relevant context
  --prd <path>           Path to PRD or spec file
  --context <file>       Additional context file (repeatable)
  --template <name>      Prompt template name (default: default)
  --output prompt|json   Output format (default: prompt)
  --dry-run              Show what would be included without assembling
  --help                 Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
TASK="" VAULT_QUERY="" PRD="" OUTPUT="prompt" TEMPLATE="default" DRY_RUN=false
CONTEXT_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)        TASK="$2"; shift 2 ;;
    --vault-query) VAULT_QUERY="$2"; shift 2 ;;
    --prd)         PRD="$2"; shift 2 ;;
    --context)     CONTEXT_FILES+=("$2"); shift 2 ;;
    --template)    TEMPLATE="$2"; shift 2 ;;
    --output)      OUTPUT="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help|-h)     usage; exit 0 ;;
    *)             log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -z "$TASK" ]] && { log_error "--task is required"; usage; exit 1; }

# ── Resolve paths ─────────────────────────────────────────────────────
VAULT_PATH=$(config_get vault_path "/Users/cyperx/Library/Mobile Documents/iCloud~md~obsidian/Documents/cyperx")
VAULT_MAX_LINES=$(config_get vault_max_lines 2000)
TEMPLATE_DIR="${CLAWFORGE_DIR}/config/prompt-templates"
TEMPLATE_FILE="${TEMPLATE_DIR}/${TEMPLATE}.md"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log_warn "Template '${TEMPLATE}' not found, using inline default"
  TEMPLATE_FILE=""
fi

# ── Vault search ──────────────────────────────────────────────────────
VAULT_CONTEXT=""
if [[ -n "$VAULT_QUERY" ]]; then
  log_info "Searching vault for: $VAULT_QUERY"
  if [[ -d "$VAULT_PATH" ]] && command -v rg &>/dev/null; then
    VAULT_RESULTS=$(rg -l --type md -i "$VAULT_QUERY" "$VAULT_PATH" 2>/dev/null | head -10 || true)
    if [[ -n "$VAULT_RESULTS" ]]; then
      VAULT_CONTEXT="## Vault Context (matching: ${VAULT_QUERY})"$'\n\n'
      while IFS= read -r file; do
        fname=$(basename "$file")
        VAULT_CONTEXT+="### ${fname}"$'\n'
        VAULT_CONTEXT+=$(head -100 "$file")$'\n\n'
      done <<< "$VAULT_RESULTS"
      # Truncate
      line_count=$(echo "$VAULT_CONTEXT" | wc -l)
      if [[ "$line_count" -gt "$VAULT_MAX_LINES" ]]; then
        VAULT_CONTEXT=$(echo "$VAULT_CONTEXT" | head -"$VAULT_MAX_LINES")
        VAULT_CONTEXT+=$'\n[...truncated to '"$VAULT_MAX_LINES"' lines]'
        log_info "Vault context truncated to $VAULT_MAX_LINES lines"
      fi
      log_info "Found $(echo "$VAULT_RESULTS" | wc -l | tr -d ' ') matching files"
    else
      log_info "No vault matches for: $VAULT_QUERY"
    fi
  elif [[ ! -d "$VAULT_PATH" ]]; then
    log_warn "Vault path not found: $VAULT_PATH"
  elif ! command -v rg &>/dev/null; then
    log_warn "ripgrep (rg) not found, skipping vault search"
  fi
fi

# ── PRD content ───────────────────────────────────────────────────────
PRD_CONTENT=""
if [[ -n "$PRD" ]]; then
  if [[ -f "$PRD" ]]; then
    PRD_CONTENT="## PRD / Specification"$'\n\n'
    PRD_CONTENT+=$(cat "$PRD")
    log_info "Included PRD: $PRD"
  else
    log_error "PRD file not found: $PRD"
    exit 1
  fi
fi

# ── Extra context ─────────────────────────────────────────────────────
EXTRA_CONTEXT=""
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
  EXTRA_CONTEXT="## Additional Context"$'\n\n'
  for ctx_file in "${CONTEXT_FILES[@]}"; do
    if [[ -f "$ctx_file" ]]; then
      fname=$(basename "$ctx_file")
      EXTRA_CONTEXT+="### ${fname}"$'\n'
      EXTRA_CONTEXT+=$(cat "$ctx_file")$'\n\n'
      log_info "Included context: $ctx_file"
    else
      log_warn "Context file not found: $ctx_file"
    fi
  done
fi

# ── Dry run ───────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo "=== Scope Dry Run ==="
  echo "Task: $TASK"
  echo "Template: ${TEMPLATE_FILE:-inline}"
  echo "Vault query: ${VAULT_QUERY:-none}"
  echo "Vault matches: $(echo "$VAULT_CONTEXT" | grep -c '^### ' 2>/dev/null || echo 0)"
  echo "PRD: ${PRD:-none}"
  echo "Context files: ${#CONTEXT_FILES[@]}"
  [[ -n "$VAULT_CONTEXT" ]] && echo "Vault context lines: $(echo "$VAULT_CONTEXT" | wc -l | tr -d ' ')"
  [[ -n "$PRD_CONTENT" ]] && echo "PRD lines: $(echo "$PRD_CONTENT" | wc -l | tr -d ' ')"
  exit 0
fi

# ── Assemble prompt ──────────────────────────────────────────────────
if [[ -n "$TEMPLATE_FILE" ]]; then
  PROMPT=$(cat "$TEMPLATE_FILE")
  PROMPT="${PROMPT//\{\{TASK_DESCRIPTION\}\}/$TASK}"
  PROMPT="${PROMPT//\{\{VAULT_CONTEXT\}\}/$VAULT_CONTEXT}"
  PROMPT="${PROMPT//\{\{PRD_CONTENT\}\}/$PRD_CONTENT}"
  PROMPT="${PROMPT//\{\{EXTRA_CONTEXT\}\}/$EXTRA_CONTEXT}"
else
  PROMPT="# Task"$'\n\n'"$TASK"$'\n\n'
  [[ -n "$VAULT_CONTEXT" ]] && PROMPT+="$VAULT_CONTEXT"$'\n\n'
  [[ -n "$PRD_CONTENT" ]]   && PROMPT+="$PRD_CONTENT"$'\n\n'
  [[ -n "$EXTRA_CONTEXT" ]] && PROMPT+="$EXTRA_CONTEXT"$'\n\n'
  PROMPT+="# Instructions"$'\n\n'
  PROMPT+="- Follow existing code conventions and style"$'\n'
  PROMPT+="- Create small, atomic commits with imperative messages"$'\n'
  PROMPT+="- When complete, push the branch and create a PR against main"
fi

# ── Output ────────────────────────────────────────────────────────────
if [[ "$OUTPUT" == "json" ]]; then
  jq -n \
    --arg task "$TASK" \
    --arg vault_query "${VAULT_QUERY:-}" \
    --arg prd "${PRD:-}" \
    --arg template "$TEMPLATE" \
    --arg prompt "$PROMPT" \
    --argjson context_count "${#CONTEXT_FILES[@]}" \
    --argjson timestamp "$(epoch_ms)" \
    '{
      timestamp: $timestamp,
      task: $task,
      vaultQuery: (if $vault_query == "" then null else $vault_query end),
      prd: (if $prd == "" then null else $prd end),
      template: $template,
      contextFiles: $context_count,
      prompt: $prompt
    }'
else
  echo "$PROMPT"
fi
