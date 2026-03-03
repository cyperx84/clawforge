#!/usr/bin/env bash
# routing.sh — Model routing: pick the right model for each phase
# Usage: source bin/routing.sh; load_routing "auto"; get_model_for_phase "scope"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Routing config ────────────────────────────────────────────────────
ROUTING_DEFAULTS="${CLAWFORGE_DIR}/config/routing-defaults.json"
ROUTING_USER="${HOME}/.clawforge/routing.json"

# Internal state — set by load_routing
_ROUTING_STRATEGY=""
_ROUTING_CONFIG=""

# ── Model aliases ─────────────────────────────────────────────────────
_resolve_model_alias() {
  local alias="$1"
  case "$alias" in
    haiku)   echo "claude-haiku-4-5" ;;
    sonnet)  echo "claude-sonnet-4-5" ;;
    opus)    echo "claude-opus-4-6" ;;
    *)       echo "$alias" ;;  # pass through full model IDs
  esac
}

# ── load_routing(strategy) ────────────────────────────────────────────
# strategy: auto | cheap | quality | "" (disabled)
load_routing() {
  local strategy="${1:-}"
  _ROUTING_STRATEGY="$strategy"

  case "$strategy" in
    auto)
      # User config > defaults
      if [[ -f "$ROUTING_USER" ]]; then
        _ROUTING_CONFIG=$(cat "$ROUTING_USER")
        log_debug "Routing: loaded user config from $ROUTING_USER"
      elif [[ -f "$ROUTING_DEFAULTS" ]]; then
        _ROUTING_CONFIG=$(cat "$ROUTING_DEFAULTS")
        log_debug "Routing: loaded defaults from $ROUTING_DEFAULTS"
      else
        log_warn "Routing: no config found, falling back to agent defaults"
        _ROUTING_STRATEGY=""
      fi
      ;;
    cheap)
      _ROUTING_CONFIG='{"scope":"haiku","implement":"haiku","review":"haiku","ci-fix":"haiku"}'
      log_debug "Routing: cheap mode — haiku for all phases"
      ;;
    quality)
      _ROUTING_CONFIG='{"scope":"opus","implement":"opus","review":"opus","ci-fix":"opus"}'
      log_debug "Routing: quality mode — opus for all phases"
      ;;
    "")
      _ROUTING_CONFIG=""
      ;;
    *)
      log_error "Unknown routing strategy: $strategy (expected: auto, cheap, quality)"
      return 1
      ;;
  esac
}

# ── get_model_for_phase(phase) ────────────────────────────────────────
# phase: scope | implement | review | ci-fix
# Returns: full model ID string, or empty if no routing active
get_model_for_phase() {
  local phase="$1"

  # No routing loaded — return empty (caller uses its own default)
  if [[ -z "$_ROUTING_STRATEGY" || -z "$_ROUTING_CONFIG" ]]; then
    echo ""
    return
  fi

  local alias
  alias=$(echo "$_ROUTING_CONFIG" | jq -r --arg p "$phase" '.[$p] // empty' 2>/dev/null)

  if [[ -z "$alias" ]]; then
    log_debug "Routing: no mapping for phase '$phase', using default"
    echo ""
    return
  fi

  _resolve_model_alias "$alias"
}
