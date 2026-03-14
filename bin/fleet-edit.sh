#!/usr/bin/env bash
# fleet-edit.sh — Open agent workspace files for editing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

usage() {
  cat <<EOF
Usage: clawforge edit <id> [options]

Open agent workspace files in your editor.

Options:
  --soul       Open SOUL.md
  --agents     Open AGENTS.md
  --tools      Open TOOLS.md
  --heartbeat  Open HEARTBEAT.md
  --user       Open USER.md
  --identity   Open IDENTITY.md
  --all        Open all workspace files
  --help       Show this help

Default (no flag): opens SOUL.md
EOF
}

# Parse arguments
AGENT_ID=""
EDIT_SOUL=false
EDIT_AGENTS=false
EDIT_TOOLS=false
EDIT_HEARTBEAT=false
EDIT_USER=false
EDIT_IDENTITY=false
EDIT_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --soul)      EDIT_SOUL=true; shift ;;
    --agents)    EDIT_AGENTS=true; shift ;;
    --tools)     EDIT_TOOLS=true; shift ;;
    --heartbeat) EDIT_HEARTBEAT=true; shift ;;
    --user)      EDIT_USER=true; shift ;;
    --identity)  EDIT_IDENTITY=true; shift ;;
    --all)       EDIT_ALL=true; shift ;;
    --help|-h)   usage; exit 0 ;;
    -*)
      if [[ -z "$AGENT_ID" ]]; then
        log_error "Agent ID must come before flags"
        usage; exit 1
      fi
      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$AGENT_ID" ]]; then
        AGENT_ID="$1"
      else
        log_error "Unexpected argument: $1"; usage; exit 1
      fi
      shift ;;
  esac
done

# Validate
if [[ -z "$AGENT_ID" ]]; then
  log_error "Agent ID required"
  usage; exit 1
fi

# Get workspace path
WORKSPACE=$(_get_workspace "$AGENT_ID")
if [[ ! -d "$WORKSPACE" ]]; then
  log_error "Workspace not found for agent '$AGENT_ID': $WORKSPACE"
  exit 1
fi

# Determine which files to open
if $EDIT_ALL; then
  # Open all files
  FILES_TO_OPEN=()
  for file in "${AGENT_FILES[@]}"; do
    if [[ -f "${WORKSPACE}/${file}" ]]; then
      FILES_TO_OPEN+=("${WORKSPACE}/${file}")
    fi
  done
elif $EDIT_SOUL || $EDIT_AGENTS || $EDIT_TOOLS || $EDIT_HEARTBEAT || $EDIT_USER || $EDIT_IDENTITY; then
  # Open specific files
  FILES_TO_OPEN=()
  if $EDIT_SOUL; then FILES_TO_OPEN+=("${WORKSPACE}/SOUL.md"); fi
  if $EDIT_AGENTS; then FILES_TO_OPEN+=("${WORKSPACE}/AGENTS.md"); fi
  if $EDIT_TOOLS; then FILES_TO_OPEN+=("${WORKSPACE}/TOOLS.md"); fi
  if $EDIT_HEARTBEAT; then FILES_TO_OPEN+=("${WORKSPACE}/HEARTBEAT.md"); fi
  if $EDIT_USER; then FILES_TO_OPEN+=("${WORKSPACE}/USER.md"); fi
  if $EDIT_IDENTITY; then FILES_TO_OPEN+=("${WORKSPACE}/IDENTITY.md"); fi
else
  # Default: open SOUL.md
  FILES_TO_OPEN=("${WORKSPACE}/SOUL.md")
fi

# Verify files exist
for file in "${FILES_TO_OPEN[@]}"; do
  if [[ ! -f "$file" ]]; then
    log_error "File not found: $file"
    exit 1
  fi
done

# Determine editor
EDITOR_CMD="${EDITOR:-vi}"
if ! command -v "$EDITOR_CMD" &>/dev/null; then
  log_warn "EDITOR '$EDITOR_CMD' not found, falling back to vi"
  EDITOR_CMD="vi"
fi

# Open files
log_info "Opening ${#FILES_TO_OPEN[@]} file(s) for agent '$AGENT_ID'"
exec "$EDITOR_CMD" "${FILES_TO_OPEN[@]}"
