#!/usr/bin/env bash
# fleet-common.sh — Shared functions for fleet management commands
# Provides helpers for reading/writing openclaw.json and agent workspace operations.

set -euo pipefail

FLEET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Paths ──────────────────────────────────────────────────────────────
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-${HOME}/.openclaw/openclaw.json}"
OPENCLAW_AGENTS_DIR="${HOME}/.openclaw/agents"
OPENCLAW_WORKSPACE="${HOME}/.openclaw/workspace"

# Workspace files every agent should have
AGENT_FILES=(SOUL.md AGENTS.md TOOLS.md USER.md IDENTITY.md MEMORY.md HEARTBEAT.md)

# ── jq guard ───────────────────────────────────────────────────────────
_require_jq() {
  if ! command -v jq &>/dev/null; then
    log_error "jq is required but not installed. Run: brew install jq"
    exit 1
  fi
}

# ── Config reading ─────────────────────────────────────────────────────
_read_openclaw_config() {
  _require_jq
  if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    log_error "OpenClaw config not found: $OPENCLAW_CONFIG"
    return 1
  fi
  cat "$OPENCLAW_CONFIG"
}

_write_openclaw_config() {
  # Safe write with .bak backup
  local new_content="$1"
  _require_jq

  if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    log_error "OpenClaw config not found: $OPENCLAW_CONFIG"
    return 1
  fi

  # Validate JSON before writing
  if ! echo "$new_content" | jq empty 2>/dev/null; then
    log_error "Invalid JSON — refusing to write"
    return 1
  fi

  # Backup
  cp "$OPENCLAW_CONFIG" "${OPENCLAW_CONFIG}.bak"
  log_debug "Backed up config to ${OPENCLAW_CONFIG}.bak"

  # Write
  echo "$new_content" > "$OPENCLAW_CONFIG"
  log_info "Config written: $OPENCLAW_CONFIG"
}

# ── Agent queries ──────────────────────────────────────────────────────
_list_agents() {
  # Returns JSON array of agents from config
  _require_jq
  local config
  config=$(_read_openclaw_config) || return 1
  echo "$config" | jq '.agents.list // []'
}

_get_agent() {
  # Get single agent config by ID
  local agent_id="$1"
  _require_jq
  local config
  config=$(_read_openclaw_config) || return 1
  local agent
  agent=$(echo "$config" | jq --arg id "$agent_id" '.agents.list[] | select(.id == $id)' 2>/dev/null)
  if [[ -z "$agent" || "$agent" == "null" ]]; then
    return 1
  fi
  echo "$agent"
}

_get_workspace() {
  # Resolve agent workspace path — from config or default convention
  local agent_id="$1"
  local agent
  agent=$(_get_agent "$agent_id" 2>/dev/null) || true

  if [[ -n "$agent" ]]; then
    local ws
    ws=$(echo "$agent" | jq -r '.workspace // empty')
    if [[ -n "$ws" ]]; then
      echo "$ws"
      return 0
    fi
  fi

  # Default convention
  echo "${OPENCLAW_AGENTS_DIR}/${agent_id}"
}

_get_bindings() {
  # Extract bindings for an agent from config
  local agent_id="$1"
  _require_jq
  local config
  config=$(_read_openclaw_config) || return 1
  echo "$config" | jq --arg id "$agent_id" '[.bindings[]? | select(.agentId == $id)]'
}

_validate_agent() {
  # Check workspace files exist, report status
  # Returns: "active", "created", "config-only", "unknown"
  local agent_id="$1"
  local workspace
  workspace=$(_get_workspace "$agent_id")

  local in_config=false
  local has_workspace=false
  local has_binding=false

  # Check config
  if _get_agent "$agent_id" &>/dev/null; then
    in_config=true
  fi

  # Check workspace
  if [[ -d "$workspace" ]]; then
    has_workspace=true
  fi

  # Check binding
  local bindings
  bindings=$(_get_bindings "$agent_id" 2>/dev/null) || bindings="[]"
  local binding_count
  binding_count=$(echo "$bindings" | jq 'length' 2>/dev/null || echo 0)
  if [[ "$binding_count" -gt 0 ]]; then
    has_binding=true
  fi

  if $in_config && $has_workspace && $has_binding; then
    echo "active"
  elif $has_workspace; then
    echo "created"
  elif $in_config; then
    echo "config-only"
  else
    echo "unknown"
  fi
}

_resolve_model_display() {
  # Short display name for model strings
  # "openai-codex/gpt-5.4" → "gpt-5.4"
  # "anthropic/claude-sonnet-4-6" → "claude-sonnet-4-6"
  local model="$1"

  # Handle object vs string model configs
  if echo "$model" | jq -e '.primary' &>/dev/null 2>&1; then
    model=$(echo "$model" | jq -r '.primary')
  fi

  # Strip provider prefix
  if [[ "$model" == */* ]]; then
    echo "${model#*/}"
  else
    echo "$model"
  fi
}

_get_model_primary() {
  # Extract primary model string from agent config (handles string or object)
  local agent_json="$1"
  local model
  model=$(echo "$agent_json" | jq -r '
    if .model | type == "object" then .model.primary
    elif .model | type == "string" then .model
    else "unknown"
    end
  ' 2>/dev/null)
  echo "${model:-unknown}"
}

_get_model_fallbacks() {
  # Extract fallback models as JSON array
  local agent_json="$1"
  echo "$agent_json" | jq '
    if .model | type == "object" then .model.fallbacks // []
    else []
    end
  ' 2>/dev/null || echo "[]"
}

_agent_exists_in_config() {
  local agent_id="$1"
  _get_agent "$agent_id" &>/dev/null
}

_workspace_file_status() {
  # Check status of a workspace file
  # Returns: "exists" (has content), "empty" (0 bytes or only whitespace), "missing"
  local filepath="$1"
  if [[ ! -f "$filepath" ]]; then
    echo "missing"
  elif [[ ! -s "$filepath" ]]; then
    echo "empty"
  else
    # Check if file is just template placeholders (not filled in)
    local content
    content=$(cat "$filepath")
    # Check for unfilled template markers
    if echo "$content" | grep -q '{{.*}}'; then
      echo "template"
    elif echo "$content" | grep -qE '^\*\(.*\)\*$|^\*(Fill|pick|Save)'; then
      echo "unfilled"
    else
      echo "exists"
    fi
  fi
}

_count_memory_files() {
  # Count daily log files in memory directory
  local workspace="$1"
  local memory_dir="${workspace}/memory"
  if [[ -d "$memory_dir" ]]; then
    find "$memory_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

_count_reference_files() {
  # Count reference files
  local workspace="$1"
  local refs_dir="${workspace}/references"
  if [[ -d "$refs_dir" ]]; then
    find "$refs_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# ── Status indicators ─────────────────────────────────────────────────
_status_icon() {
  case "$1" in
    active)      echo "●" ;;
    created)     echo "○" ;;
    config-only) echo "◌" ;;
    *)           echo "?" ;;
  esac
}

_file_status_icon() {
  case "$1" in
    exists)   echo "✓" ;;
    empty)    echo "○" ;;
    missing)  echo "✗" ;;
    template) echo "⚠" ;;
    unfilled) echo "⚠" ;;
    *)        echo "?" ;;
  esac
}

# ── Template substitution ─────────────────────────────────────────────
_substitute_placeholders() {
  # Replace {{PLACEHOLDER}} in file content
  local content="$1"
  local name="${2:-}"
  local role="${3:-}"
  local emoji="${4:-}"
  local role_desc="${5:-}"

  content="${content//\{\{NAME\}\}/$name}"
  content="${content//\{\{ROLE\}\}/$role}"
  content="${content//\{\{EMOJI\}\}/$emoji}"
  content="${content//\{\{ROLE_DESCRIPTION\}\}/$role_desc}"

  echo "$content"
}

# ── Formatting helpers ─────────────────────────────────────────────────
_human_size() {
  # Convert bytes to human-readable
  local bytes="$1"
  if [[ $bytes -lt 1024 ]]; then
    echo "${bytes} B"
  elif [[ $bytes -lt 1048576 ]]; then
    echo "$(( bytes / 1024 )).$(( (bytes % 1024) * 10 / 1024 )) KB"
  else
    echo "$(( bytes / 1048576 )).$(( (bytes % 1048576) * 10 / 1048576 )) MB"
  fi
}
