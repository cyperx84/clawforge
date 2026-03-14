#!/usr/bin/env bash
# clwatch-bridge.sh — Optional clwatch integration helpers
# All functions gracefully return empty/defaults when clwatch isn't installed.

set -euo pipefail

# ── Availability ───────────────────────────────────────────────────────
_has_clwatch() {
  command -v clwatch &>/dev/null
}

# ── Model compatibility ───────────────────────────────────────────────
_get_model_compat() {
  # Returns JSON with harness compatibility for a model
  # Falls back to empty object if clwatch not available
  local model_id="$1"

  if ! _has_clwatch; then
    echo "{}"
    return 0
  fi

  clwatch compat "$model_id" --json 2>/dev/null || echo "{}"
}

_get_model_compat_display() {
  # Human-readable compatibility string for a model
  local model_id="$1"

  if ! _has_clwatch; then
    echo ""
    return 0
  fi

  local compat
  compat=$(clwatch compat "$model_id" 2>/dev/null || true)
  if [[ -n "$compat" ]]; then
    echo "$compat"
  fi
}

# ── Deprecations ───────────────────────────────────────────────────────
_get_deprecations() {
  # Returns JSON array of deprecations affecting given model(s)
  # Usage: _get_deprecations "model-id" or _get_deprecations (all)
  local model_id="${1:-}"

  if ! _has_clwatch; then
    echo "[]"
    return 0
  fi

  if [[ -n "$model_id" ]]; then
    clwatch deprecations --json --model "$model_id" 2>/dev/null || echo "[]"
  else
    clwatch deprecations --json 2>/dev/null || echo "[]"
  fi
}

_get_deprecation_display() {
  # Human-readable deprecation info for a model
  local model_id="$1"

  if ! _has_clwatch; then
    echo "none (clwatch not installed)"
    return 0
  fi

  local deps
  deps=$(_get_deprecations "$model_id")
  local count
  count=$(echo "$deps" | jq 'length' 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    echo "none"
  else
    echo "$deps" | jq -r '.[] | "⚠ \(.model // .id) deprecated \(.date // "unknown") → \(.migration // "see docs")"' 2>/dev/null || echo "check clwatch"
  fi
}

# ── Tool versions ──────────────────────────────────────────────────────
_get_tool_versions() {
  # Returns JSON with current tool versions via clwatch
  if ! _has_clwatch; then
    echo "{}"
    return 0
  fi

  clwatch diff --json 2>/dev/null || echo "{}"
}

_get_tool_version_display() {
  # Human-readable tool version for a specific tool
  local tool_name="$1"

  if ! _has_clwatch; then
    echo "unknown (clwatch not installed)"
    return 0
  fi

  local versions
  versions=$(_get_tool_versions)
  local version
  version=$(echo "$versions" | jq -r --arg t "$tool_name" '.[$t].current // "unknown"' 2>/dev/null || echo "unknown")
  local status
  status=$(echo "$versions" | jq -r --arg t "$tool_name" 'if .[$t].latest == .[$t].current then "current" elif .[$t].latest then "update available: \(.[$t].latest)" else "current" end' 2>/dev/null || echo "")

  if [[ -n "$status" && "$status" != "current" ]]; then
    echo "${version} (${status})"
  else
    echo "${version} (current)"
  fi
}

# ── Fleet-wide checks ─────────────────────────────────────────────────
_check_fleet_compat() {
  # Check all agents' models against clwatch data
  # Returns JSON report
  if ! _has_clwatch; then
    echo '{"available": false, "message": "clwatch not installed"}'
    return 0
  fi

  # This is a placeholder — actual fleet compat is built by the compat command
  echo '{"available": true}'
}
