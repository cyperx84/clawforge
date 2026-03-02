#!/usr/bin/env bash
# common.sh — Shared functions for clawforge
# Registry helpers, logging, config

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────
CLAWFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY_FILE="${CLAWFORGE_DIR}/registry/active-tasks.json"
CONFIG_FILE="${CLAWFORGE_DIR}/config/defaults.json"

# ── Logging ────────────────────────────────────────────────────────────
log_info()  { echo "[INFO]  $(date +%H:%M:%S) $*" >&2; }
log_warn()  { echo "[WARN]  $(date +%H:%M:%S) $*" >&2; }
log_error() { echo "[ERROR] $(date +%H:%M:%S) $*" >&2; }
log_debug() { [[ "${CLAWFORGE_DEBUG:-0}" == "1" ]] && echo "[DEBUG] $(date +%H:%M:%S) $*" >&2 || true; }

# ── Config ─────────────────────────────────────────────────────────────
config_get() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "$CONFIG_FILE" ]]; then
    local val
    val=$(jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$val" ]]; then
      echo "$val"
      return
    fi
  fi
  echo "$default"
}

# ── Registry helpers ───────────────────────────────────────────────────
_ensure_registry() {
  mkdir -p "$(dirname "$REGISTRY_FILE")"
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
}

registry_add() {
  local task_json="$1"
  _ensure_registry
  local tmp
  tmp=$(mktemp)
  jq --argjson task "$task_json" '.tasks += [$task]' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
  log_info "Registry: added task $(echo "$task_json" | jq -r '.id')"
}

registry_update() {
  local id="$1" field="$2" value="$3"
  _ensure_registry
  local tmp
  tmp=$(mktemp)
  # Try to parse value as JSON; if it fails, treat as string
  if echo "$value" | jq . >/dev/null 2>&1; then
    jq --arg id "$id" --arg field "$field" --argjson val "$value" \
      '(.tasks[] | select(.id == $id))[$field] = $val' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
  else
    jq --arg id "$id" --arg field "$field" --arg val "$value" \
      '(.tasks[] | select(.id == $id))[$field] = $val' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
  fi
  log_debug "Registry: updated $id.$field"
}

registry_get() {
  local id="$1"
  _ensure_registry
  jq --arg id "$id" '.tasks[] | select(.id == $id)' "$REGISTRY_FILE"
}

registry_list() {
  _ensure_registry
  local status_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ -n "$status_filter" ]]; then
    jq --arg s "$status_filter" '[.tasks[] | select(.status == $s)]' "$REGISTRY_FILE"
  else
    jq '.tasks' "$REGISTRY_FILE"
  fi
}

registry_remove() {
  local id="$1"
  _ensure_registry
  local tmp
  tmp=$(mktemp)
  jq --arg id "$id" '.tasks = [.tasks[] | select(.id != $id)]' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
  log_info "Registry: removed task $id"
}

# ── Agent detection ────────────────────────────────────────────────────
detect_agent() {
  local preferred="${1:-}"
  if [[ -n "$preferred" ]]; then
    if command -v "$preferred" &>/dev/null; then
      echo "$preferred"
      return 0
    else
      log_error "Requested agent '$preferred' not found"
      return 1
    fi
  fi
  if command -v claude &>/dev/null; then
    echo "claude"
  elif command -v codex &>/dev/null; then
    echo "codex"
  else
    log_error "No coding agent found (need claude or codex)"
    return 1
  fi
}

# ── Short ID management ───────────────────────────────────────────────
# Sequential short IDs (#1, #2, #3...) mapped in registry
_next_short_id() {
  _ensure_registry
  local max_id
  max_id=$(jq '[.tasks[].short_id // 0] | max // 0' "$REGISTRY_FILE" 2>/dev/null || echo 0)
  echo $((max_id + 1))
}

resolve_task_id() {
  # Accept short ID (#1, 1), sub-agent ID (3.2), or full UUID/slug
  local input="$1"
  _ensure_registry

  # Strip leading # if present
  input="${input#\#}"

  # Check if it's a sub-agent reference (e.g., 3.2)
  if [[ "$input" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    local parent_short="${BASH_REMATCH[1]}"
    local sub_index="${BASH_REMATCH[2]}"
    local parent_id
    parent_id=$(jq -r --argjson sid "$parent_short" '.tasks[] | select(.short_id == $sid) | .id' "$REGISTRY_FILE" 2>/dev/null || true)
    if [[ -n "$parent_id" ]]; then
      # Find sub-agent by parent_id and sub_index
      jq -r --arg pid "$parent_id" --argjson idx "$sub_index" \
        '.tasks[] | select(.parent_id == $pid and .sub_index == $idx) | .id' "$REGISTRY_FILE" 2>/dev/null || true
      return
    fi
  fi

  # Check if it's a numeric short ID
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    local resolved
    resolved=$(jq -r --argjson sid "$input" '.tasks[] | select(.short_id == $sid) | .id' "$REGISTRY_FILE" 2>/dev/null || true)
    if [[ -n "$resolved" ]]; then
      echo "$resolved"
      return
    fi
  fi

  # Fall through: treat as full ID/slug
  echo "$input"
}

# ── Auto-repo detection ──────────────────────────────────────────────
detect_repo() {
  # Walk up from cwd (or given path) to find .git
  local start="${1:-$(pwd)}"
  local dir="$start"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  log_error "No git repository found from $start"
  return 1
}

# ── Auto-branch naming ───────────────────────────────────────────────
slugify_task() {
  # Convert task description to a URL-safe branch slug
  local task="$1"
  local max_len="${2:-40}"
  echo "$task" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]//g' \
    | sed 's/^  *//;s/  *$//' \
    | sed 's/  */ /g' \
    | sed 's/ /-/g' \
    | cut -c1-"$max_len" \
    | sed 's/-$//'
}

auto_branch_name() {
  # Generate branch name with mode prefix and collision detection
  local mode="$1"    # sprint, quick, swarm
  local task="$2"
  local repo="${3:-}"

  local slug
  slug=$(slugify_task "$task")
  local prefix="${mode}/"
  local candidate="${prefix}${slug}"

  # Collision detection if repo is provided
  if [[ -n "$repo" ]] && [[ -d "$repo/.git" ]]; then
    local attempt=1
    local base="$candidate"
    while git -C "$repo" show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null; do
      attempt=$((attempt + 1))
      candidate="${base}-${attempt}"
    done
  fi

  echo "$candidate"
}

# ── Utilities ──────────────────────────────────────────────────────────
sanitize_branch() {
  echo "$1" | sed 's|/|-|g' | sed 's|[^a-zA-Z0-9_-]|-|g'
}

epoch_ms() {
  python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "$(date +%s)000"
}
