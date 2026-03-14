#!/usr/bin/env bash
# changelog.sh — Module: clwatch integration for auto-patching reference files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Paths ──────────────────────────────────────────────────────────────
STATE_DIR="${HOME}/.clawforge"
PID_FILE="${STATE_DIR}/changelog-watch.pid"
LOG_FILE="${STATE_DIR}/changelog-watch.log"
LAST_CHECK_FILE="${STATE_DIR}/changelog-last-check"

# ── Tool-to-file mapping ───────────────────────────────────────────────
# Maps clwatch tool ID to reference filename
declare -A TOOL_MAP=(
  [claude-code]="claude-code-features.md"
  [codex-cli]="codex-cli-features.md"
  [gemini-cli]="gemini-cli-features.md"
  [opencode]="opencode-features.md"
  [openclaw]="openclaw-features.md"
)

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: changelog.sh <subcommand> [options]

Subcommands:
  check         Check for tool updates via clwatch (one-shot)
  watch         Run as a polling daemon
  status        Show current known versions vs latest
  ack <tool>    Mark a tool version as acknowledged

Options (check/watch):
  --auto          Auto-patch reference files without confirmation
  --notify        Send notification on changes (uses notify.sh)
  --webhook URL   POST to webhook on changes
  --interval N    Daemon poll interval (default: 6h, min 15m)
  --json          Machine-readable output
  --refs-dir DIR  Directory of reference files (auto-detect if omitted)
  --stop          Stop running changelog daemon
  --tools LIST    Comma-separated tools to watch (default: all)
  --dry-run       Show what would change without patching

Meta:
  --help          Show this help
EOF
}

# ── Logging ────────────────────────────────────────────────────────────
_log_to_file() {
  local level="$1" message="$2"
  mkdir -p "$STATE_DIR"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# ── Detect clwatch ─────────────────────────────────────────────────────
_check_clwatch() {
  if ! command -v clwatch &>/dev/null; then
    log_warn "clwatch not installed — changelog features unavailable"
    log_info "Install via: brew install cyperx/tap/clwatch"
    log_info "Or: https://github.com/cyperx84/clwatch"
    log_info "ClawForge works standalone without clwatch."
    return 1
  fi
  return 0
}

# ── Auto-detect references directory ───────────────────────────────────
_detect_refs_dir() {
  local custom_dir="${1:-}"

  # 1. User-provided
  if [[ -n "$custom_dir" && -d "$custom_dir" ]]; then
    echo "$custom_dir"
    return 0
  fi

  # 2. User config
  local config_refs
  config_refs=$(config_get "changelog_refs_dir" "" 2>/dev/null || true)
  if [[ -n "$config_refs" && -d "$config_refs" ]]; then
    echo "$config_refs"
    return 0
  fi

  # 3. ~/.clawforge/references/
  if [[ -d "${STATE_DIR}/references" ]]; then
    echo "${STATE_DIR}/references"
    return 0
  fi

  # 4. cwd/references/
  if [[ -d "references" ]]; then
    echo "references"
    return 0
  fi

  # 5. $CLAWFORGE_DIR/references/
  if [[ -d "${CLAWFORGE_DIR}/references" ]]; then
    echo "${CLAWFORGE_DIR}/references"
    return 0
  fi

  return 1
}

# ── Map tool ID to reference file path ─────────────────────────────────
_get_ref_file() {
  local tool_id="$1" refs_dir="$2"
  local filename="${TOOL_MAP[$tool_id]:-}"

  if [[ -z "$filename" ]]; then
    return 1
  fi

  echo "${refs_dir}/${filename}"
}

# ── Patch reference file via Claude Code ───────────────────────────────
_patch_via_claude() {
  local file="$1" tool="$2" version="$3"
  local features="$4" commands="$5" flags="$6" deprecated="$7" breaking="$8"
  local auto="${9:-false}"

  if ! command -v claude &>/dev/null; then
    log_warn "Claude Code not available — falling back to append mode"
    return 1
  fi

  # Build the patch prompt
  local prompt="Update the reference file at $file to reflect these changes from $tool $version:

New features:
$features

New commands:
$commands

New flags:
$flags

Deprecated commands:
$deprecated

Breaking changes:
$breaking

Instructions:
- Add new features/commands to the appropriate section
- Mark deprecated items clearly with a \"(deprecated since $version)\" note
- Highlight breaking changes prominently
- Do NOT remove existing content
- Keep the existing file structure and formatting"

  log_info "Preparing patch for $file via Claude Code..."

  if [[ "$auto" == "true" ]]; then
    # Auto-patch: use Claude without confirmation
    claude --permission-mode bypassPermissions <<EOF
File to update: $file
$prompt
EOF
    return $?
  else
    # Interactive: show diff and ask
    # For now, return failure to use append mode below
    return 1
  fi
}

# ── Patch reference file by appending ──────────────────────────────────
_patch_via_append() {
  local file="$1" tool="$2" version="$3"
  local features="$4" commands="$5" flags="$6" deprecated="$7" breaking="$8"

  mkdir -p "$(dirname "$file")"

  # Create append block
  cat >> "$file" <<EOF

## Updated: $tool v$version

### New Features
$features

### New Commands
$commands

### New Flags
$flags

### Deprecated
$deprecated

### Breaking Changes
$breaking
EOF

  log_info "Appended changes to $file"
  return 0
}

# ── Process a clwatch payload ──────────────────────────────────────────
_process_payload() {
  local tool_id="$1" payload_json="$2" refs_dir="$3" auto="${4:-false}" dry_run="${5:-false}"

  # Extract delta from payload
  local features commands flags deprecated breaking
  features=$(echo "$payload_json" | jq -r '.delta.new_features[]? // empty' | sed 's/^/  - /' || echo "(none)")
  commands=$(echo "$payload_json" | jq -r '.delta.new_commands[]? // empty' | sed 's/^/  - /' || echo "(none)")
  flags=$(echo "$payload_json" | jq -r '.delta.new_flags[]? // empty' | sed 's/^/  - /' || echo "(none)")
  deprecated=$(echo "$payload_json" | jq -r '.delta.deprecated_commands[]? // empty' | sed 's/^/  - /' || echo "(none)")
  breaking=$(echo "$payload_json" | jq -r '.delta.breaking_changes[]? // empty' | sed 's/^/  - /' || echo "(none)")

  # Check if there's actually a delta
  if [[ "$features" == "(none)" && "$commands" == "(none)" && "$flags" == "(none)" && "$deprecated" == "(none)" && "$breaking" == "(none)" ]]; then
    log_debug "No changes detected for $tool_id"
    return 0
  fi

  local version
  version=$(echo "$payload_json" | jq -r '.version // "unknown"')

  local ref_file
  ref_file=$(_get_ref_file "$tool_id" "$refs_dir") || {
    log_warn "No reference file mapping for tool: $tool_id"
    return 1
  }

  log_info "Changes detected: $tool_id v$version → $ref_file"

  if $dry_run; then
    log_info "[DRY-RUN] Would patch: $ref_file"
    echo "  Features: $features"
    echo "  Commands: $commands"
    echo "  Flags: $flags"
    echo "  Deprecated: $deprecated"
    echo "  Breaking: $breaking"
    return 0
  fi

  if ! $auto; then
    # Ask for confirmation
    read -p "Patch $ref_file? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Skipped patching $ref_file"
      return 0
    fi
  fi

  # Try Claude Code first, fall back to append
  if _patch_via_claude "$ref_file" "$tool_id" "$version" "$features" "$commands" "$flags" "$deprecated" "$breaking" "$auto"; then
    log_info "Successfully patched via Claude Code: $ref_file"
    _log_to_file "INFO" "Patched $tool_id v$version → $ref_file (Claude Code)"
  else
    # Fallback: append block
    if _patch_via_append "$ref_file" "$tool_id" "$version" "$features" "$commands" "$flags" "$deprecated" "$breaking"; then
      log_info "Patched via append: $ref_file"
      _log_to_file "INFO" "Patched $tool_id v$version → $ref_file (append)"
    else
      log_error "Failed to patch $ref_file"
      _log_to_file "ERROR" "Failed to patch $tool_id v$version"
      return 1
    fi
  fi
}

# ── Check for updates (one-shot) ───────────────────────────────────────
cmd_check() {
  ! _check_clwatch && exit 0

  local auto=false notify=false webhook="" json=false refs_dir="" dry_run=false
  local tools=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto)       auto=true; shift ;;
      --notify)     notify=true; shift ;;
      --webhook)    webhook="$2"; shift 2 ;;
      --json)       json=true; shift ;;
      --refs-dir)   refs_dir="$2"; shift 2 ;;
      --dry-run)    dry_run=true; shift ;;
      --tools)      tools="$2"; shift 2 ;;
      *)            log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Auto-detect refs directory
  refs_dir=$(_detect_refs_dir "$refs_dir") || {
    log_warn "Could not locate references directory"
    exit 0
  }

  # Get tool list to monitor
  if [[ -z "$tools" ]]; then
    tools=$(config_get "changelog_tools" "claude-code,codex-cli,gemini-cli,opencode,openclaw")
  fi

  log_info "Checking for updates ($tools)..."

  local changed=false
  local output="[]"

  IFS=',' read -ra TOOL_LIST <<< "$tools"
  for tool in "${TOOL_LIST[@]}"; do
    tool="${tool// /}"  # trim whitespace
    [[ -z "$tool" ]] && continue

    # Call clwatch refresh for this tool
    local payload
    payload=$(clwatch refresh "$tool" --json 2>/dev/null || echo '{}')

    if [[ -z "$payload" || "$payload" == "{}" ]]; then
      log_debug "No data from clwatch for $tool"
      continue
    fi

    # Process the payload
    if _process_payload "$tool" "$payload" "$refs_dir" "$auto" "$dry_run"; then
      changed=true
      output=$(echo "$output" | jq --argjson p "$payload" '. += [$p]')
    fi
  done

  # Update last check timestamp
  date +%s > "$LAST_CHECK_FILE"

  if $changed && $notify; then
    "${SCRIPT_DIR}/notify.sh" --message "📚 Reference files updated from clwatch" 2>/dev/null || true
  fi

  if $changed && [[ -n "$webhook" ]]; then
    curl -s -X POST "$webhook" -H "Content-Type: application/json" -d "$output" >/dev/null || true
  fi

  if $json; then
    echo "$output"
  elif $changed; then
    log_info "Update check complete — references patched"
  else
    log_debug "No updates detected"
  fi
}

# ── Watch daemon ───────────────────────────────────────────────────────
cmd_watch() {
  ! _check_clwatch && exit 0

  local interval="" notify=false webhook="" refs_dir="" tools=""
  local stop=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interval)   interval="$2"; shift 2 ;;
      --notify)     notify=true; shift ;;
      --webhook)    webhook="$2"; shift 2 ;;
      --refs-dir)   refs_dir="$2"; shift 2 ;;
      --tools)      tools="$2"; shift 2 ;;
      --stop)       stop=true; shift ;;
      *)            log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Stop daemon if requested
  if $stop; then
    if [[ -f "$PID_FILE" ]]; then
      local pid
      pid=$(cat "$PID_FILE" 2>/dev/null || true)
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PID_FILE"
        log_info "Changelog daemon stopped (PID: $pid)"
      else
        rm -f "$PID_FILE"
        log_info "Daemon was not running (stale PID file removed)"
      fi
    else
      log_info "No changelog daemon running"
    fi
    return 0
  fi

  # Check if daemon already running
  if [[ -f "$PID_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      log_error "Changelog daemon already running (PID: $existing_pid)"
      exit 1
    fi
  fi

  # Resolve interval from config
  if [[ -z "$interval" ]]; then
    local config_interval
    config_interval=$(config_get "changelog_check_interval" "6h")
    # Convert "6h" to seconds
    if [[ "$config_interval" =~ ^([0-9]+)h$ ]]; then
      interval=$((${BASH_REMATCH[1]} * 3600))
    elif [[ "$config_interval" =~ ^([0-9]+)m$ ]]; then
      interval=$((${BASH_REMATCH[1]} * 60))
    else
      interval=$((6 * 3600))  # default 6h
    fi
  fi

  # Enforce minimum interval (15 minutes)
  if [[ $interval -lt 900 ]]; then
    log_warn "Interval too low (min 15m), setting to 15m"
    interval=900
  fi

  # Write PID file and daemonize
  mkdir -p "$STATE_DIR"
  echo $$ > "$PID_FILE"

  log_info "Changelog daemon starting (interval: $((interval / 3600))h, PID: $$)"
  _log_to_file "INFO" "Daemon started with interval $interval seconds"

  # Trap cleanup
  trap '_log_to_file "INFO" "Daemon shutting down"; rm -f "$PID_FILE"' EXIT INT TERM

  # Main daemon loop
  while true; do
    cmd_check --auto $([ "$notify" = true ] && echo "--notify" || true) \
              $([ -n "$webhook" ] && echo "--webhook $webhook" || true) \
              $([ -n "$refs_dir" ] && echo "--refs-dir $refs_dir" || true) \
              $([ -n "$tools" ] && echo "--tools $tools" || true)

    log_debug "Next check in $((interval / 3600))h"
    sleep "$interval"
  done
}

# ── Show status ────────────────────────────────────────────────────────
cmd_status() {
  local refs_dir
  refs_dir=$(_detect_refs_dir "${1:-}") || {
    log_error "Could not locate references directory"
    return 1
  }

  ! _check_clwatch && {
    log_info "clwatch not installed — showing local reference versions only"
    for file in "${refs_dir}"/*.md; do
      if [[ -f "$file" ]]; then
        local version
        version=$(grep -m1 "^## v" "$file" 2>/dev/null | sed 's/^## v//' || echo "unknown")
        echo "  $(basename "$file"): $version (local)"
      fi
    done
    return 0
  }

  echo "Reference file versions:"
  for file in "${refs_dir}"/*.md; do
    if [[ -f "$file" ]]; then
      local filename local_version
      filename=$(basename "$file" .md)
      local_version=$(grep -m1 "^## v" "$file" 2>/dev/null | sed 's/^## v//' || echo "unknown")

      # Try to get latest from clwatch
      local tool_id
      for tid in "${!TOOL_MAP[@]}"; do
        if [[ "${TOOL_MAP[$tid]}" == "$(basename "$file")" ]]; then
          tool_id="$tid"
          break
        fi
      done

      if [[ -n "$tool_id" ]]; then
        local latest
        latest=$(clwatch list --json 2>/dev/null | jq -r --arg tid "$tool_id" '.[] | select(.tool == $tid) | .version // "?"' || echo "?")
        echo "  $filename: local=$local_version, latest=$latest"
      else
        echo "  $filename: $local_version (unmapped tool)"
      fi
    fi
  done
}

# ── Acknowledge tool version ───────────────────────────────────────────
cmd_ack() {
  local tool="$1"
  [[ -z "$tool" ]] && { log_error "Usage: changelog.sh ack <tool>"; exit 1; }

  mkdir -p "$STATE_DIR"
  date +%s > "${STATE_DIR}/changelog-ack-${tool}"
  log_info "Acknowledged $tool"
}

# ── Main ───────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    check)   cmd_check "$@" ;;
    watch)   cmd_watch "$@" ;;
    status)  cmd_status "$@" ;;
    ack)     cmd_ack "$@" ;;
    help|--help|-h)  usage; exit 0 ;;
    *)       log_error "Unknown subcommand: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
