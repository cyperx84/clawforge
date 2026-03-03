#!/usr/bin/env bash
# memory.sh — Agent memory: per-repo JSONL knowledge base
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

MEMORY_BASE="$HOME/.clawforge/memory"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: memory.sh [subcommand] [options]

Subcommands:
  (none)              Show memory stats for current repo
  show                List all memories for current repo
  add <text>          Add a memory entry
  search <query>      Search memories by text
  forget --id <id>    Remove a specific memory
  clear               Wipe all memories for current repo

Options:
  --tags <t1,t2>      Tags for the memory (with add)
  --source <src>      Source label (default: manual)
  --repo-name <name>  Override auto-detected repo name
  --help              Show this help
EOF
}

# ── Detect repo name ──────────────────────────────────────────────────
get_repo_name() {
  local override="${REPO_NAME_OVERRIDE:-}"
  if [[ -n "$override" ]]; then
    echo "$override"
    return
  fi
  # Try git remote
  local remote_url
  remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
  if [[ -n "$remote_url" ]]; then
    basename "$remote_url" .git
    return
  fi
  # Fallback: directory name
  basename "$(pwd)"
}

memory_file() {
  local name
  name=$(get_repo_name)
  echo "${MEMORY_BASE}/${name}.jsonl"
}

# ── Generate UUID ─────────────────────────────────────────────────────
gen_id() {
  python3 -c 'import uuid; print(uuid.uuid4().hex[:12])' 2>/dev/null || \
    head -c 12 /dev/urandom | xxd -p 2>/dev/null | head -c 12 || \
    echo "$(date +%s)$$"
}

# ── Subcommands ───────────────────────────────────────────────────────

cmd_stats() {
  local file
  file=$(memory_file)
  local name
  name=$(get_repo_name)
  if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    echo "No memories for repo: $name"
    return 0
  fi
  local count
  count=$(wc -l < "$file" | tr -d ' ')
  local sources
  sources=$(jq -r '.source' "$file" | sort | uniq -c | sort -rn | head -5)
  echo "Memory: $name ($count entries)"
  echo "File: $file"
  echo ""
  echo "By source:"
  echo "$sources" | while read -r cnt src; do
    echo "  $src: $cnt"
  done
}

cmd_show() {
  local file
  file=$(memory_file)
  if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    echo "No memories for repo: $(get_repo_name)"
    return 0
  fi
  jq -r '"[\(.id)] [\(.source)] \(.text)" + if (.tags | length) > 0 then " [" + (.tags | join(",")) + "]" else "" end' "$file"
}

cmd_add() {
  local text="$1"
  local tags_csv="${TAGS:-}"
  local source="${SOURCE:-manual}"
  local file
  file=$(memory_file)
  mkdir -p "$(dirname "$file")"

  local tags_json="[]"
  if [[ -n "$tags_csv" ]]; then
    tags_json=$(echo "$tags_csv" | tr ',' '\n' | jq -R . | jq -s .)
  fi

  local entry
  entry=$(jq -cn \
    --arg id "$(gen_id)" \
    --arg text "$text" \
    --argjson tags "$tags_json" \
    --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "$source" \
    '{id:$id, text:$text, tags:$tags, created:$created, source:$source}')

  echo "$entry" >> "$file"
  log_info "Memory added for $(get_repo_name)"
  echo "$entry" | jq .
}

cmd_search() {
  local query="$1"
  local file
  file=$(memory_file)
  if [[ ! -f "$file" ]]; then
    echo "No memories for repo: $(get_repo_name)"
    return 0
  fi
  grep -i "$query" "$file" | jq -r '"[\(.id)] \(.text)"' 2>/dev/null || echo "No matches."
}

cmd_forget() {
  local target_id="$1"
  local file
  file=$(memory_file)
  if [[ ! -f "$file" ]]; then
    log_error "No memory file for $(get_repo_name)"
    return 1
  fi
  local before
  before=$(wc -l < "$file" | tr -d ' ')
  local tmp
  tmp=$(mktemp)
  jq -c "select(.id != \"$target_id\")" "$file" > "$tmp"
  mv "$tmp" "$file"
  local after
  after=$(wc -l < "$file" | tr -d ' ')
  if [[ "$before" -eq "$after" ]]; then
    echo "No memory with id: $target_id"
    return 1
  fi
  echo "Removed memory: $target_id ($before → $after entries)"
}

cmd_clear() {
  local file
  file=$(memory_file)
  if [[ -f "$file" ]]; then
    rm -f "$file"
    echo "Cleared all memories for $(get_repo_name)"
  else
    echo "No memories to clear for $(get_repo_name)"
  fi
}

# ── Parse args ────────────────────────────────────────────────────────
SUBCMD="" TEXT="" FORGET_ID="" TAGS="" SOURCE="manual" REPO_NAME_OVERRIDE=""

# First pass: extract global flags
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tags)       TAGS="$2"; shift 2 ;;
    --source)     SOURCE="$2"; shift 2 ;;
    --repo-name)  REPO_NAME_OVERRIDE="$2"; shift 2 ;;
    --id)         FORGET_ID="$2"; shift 2 ;;
    --help|-h)    usage; exit 0 ;;
    *)            POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

SUBCMD="${1:-}"
shift 2>/dev/null || true

case "$SUBCMD" in
  "")       cmd_stats ;;
  show)     cmd_show ;;
  add)
    TEXT="${1:-}"
    [[ -z "$TEXT" ]] && { log_error "Usage: memory add <text>"; exit 1; }
    cmd_add "$TEXT"
    ;;
  search)
    QUERY="${1:-}"
    [[ -z "$QUERY" ]] && { log_error "Usage: memory search <query>"; exit 1; }
    cmd_search "$QUERY"
    ;;
  forget)
    [[ -z "$FORGET_ID" ]] && { log_error "Usage: memory forget --id <id>"; exit 1; }
    cmd_forget "$FORGET_ID"
    ;;
  clear)    cmd_clear ;;
  *)        log_error "Unknown subcommand: $SUBCMD"; usage; exit 1 ;;
esac
