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

# ── Utilities ──────────────────────────────────────────────────────────
sanitize_branch() {
  echo "$1" | sed 's|/|-|g' | sed 's|[^a-zA-Z0-9_-]|-|g'
}

epoch_ms() {
  python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "$(date +%s)000"
}
