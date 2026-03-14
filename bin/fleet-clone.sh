#!/usr/bin/env bash
# fleet-clone.sh — Duplicate an agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

usage() {
  cat <<EOF
Usage: clawforge clone <source-id> <new-id> [options]

Duplicate an agent workspace and config.

Arguments:
  <source-id>   Agent to clone from
  <new-id>      ID for the new agent

Options:
  --with-memory  Include memory files (default: fresh start without memory)
  --dry-run      Show what would happen without making changes
  --help         Show this help

Examples:
  clawforge clone builder builder-v2
  clawforge clone ops ops-backup --with-memory
EOF
}

# Parse arguments
SOURCE_ID=""
NEW_ID=""
WITH_MEMORY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-memory) WITH_MEMORY=true; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help|-h)     usage; exit 0 ;;
    -*)
      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$SOURCE_ID" ]]; then
        SOURCE_ID="$1"
      elif [[ -z "$NEW_ID" ]]; then
        NEW_ID="$1"
      else
        log_error "Unexpected argument: $1"; usage; exit 1
      fi
      shift ;;
  esac
done

# Validate
if [[ -z "$SOURCE_ID" ]]; then
  log_error "Source agent ID required"
  usage; exit 1
fi

if [[ -z "$NEW_ID" ]]; then
  log_error "New agent ID required"
  usage; exit 1
fi

# Validate source exists
if ! _agent_exists_in_config "$SOURCE_ID"; then
  log_error "Source agent '$SOURCE_ID' not found in config"
  exit 1
fi

# Check new ID doesn't already exist
if _agent_exists_in_config "$NEW_ID"; then
  log_error "Agent '$NEW_ID' already exists in config"
  exit 1
fi

# Get source workspace
SOURCE_WORKSPACE=$(_get_workspace "$SOURCE_ID")
if [[ ! -d "$SOURCE_WORKSPACE" ]]; then
  log_error "Source workspace not found: $SOURCE_WORKSPACE"
  exit 1
fi

# Determine new workspace path
NEW_WORKSPACE="${OPENCLAW_AGENTS_DIR}/${NEW_ID}"
if [[ -d "$NEW_WORKSPACE" ]]; then
  log_error "Workspace already exists: $NEW_WORKSPACE"
  exit 1
fi

# Get source agent config
SOURCE_CONFIG=$(_get_agent "$SOURCE_ID")

if $DRY_RUN; then
  echo "[DRY-RUN] Would clone agent '$SOURCE_ID' to '$NEW_ID'"
  echo ""
  echo "Source workspace: $SOURCE_WORKSPACE"
  echo "New workspace:    $NEW_WORKSPACE"
  echo "Copy memory:      $WITH_MEMORY"
  echo ""
  echo "Would update:"
  echo "  - SOUL.md: change name references to '$NEW_ID'"
  echo "  - IDENTITY.md: change name references to '$NEW_ID'"
  echo "  - Config: add new agent entry based on '$SOURCE_ID'"
  exit 0
fi

# Create new workspace directory
mkdir -p "$NEW_WORKSPACE"

# Copy workspace files
log_info "Copying workspace files..."
cp -R "$SOURCE_WORKSPACE"/* "$NEW_WORKSPACE/" 2>/dev/null || true

# Remove memory files unless --with-memory
if ! $WITH_MEMORY; then
  MEMORY_DIR="${NEW_WORKSPACE}/memory"
  if [[ -d "$MEMORY_DIR" ]]; then
    rm -rf "$MEMORY_DIR"
    mkdir -p "$MEMORY_DIR"
    log_debug "Reset memory directory (fresh start)"
  fi
fi

# Update SOUL.md with new name
SOUL_FILE="${NEW_WORKSPACE}/SOUL.md"
if [[ -f "$SOUL_FILE" ]]; then
  # Replace source ID with new ID (case-insensitive)
  sed -i.bak "s/${SOURCE_ID}/${NEW_ID}/gi" "$SOUL_FILE" 2>/dev/null || \
    sed -i '' "s/${SOURCE_ID}/${NEW_ID}/gI" "$SOUL_FILE" 2>/dev/null || \
    sed -i "s/${SOURCE_ID}/${NEW_ID}/g" "$SOUL_FILE"
  rm -f "${SOUL_FILE}.bak"
  log_debug "Updated SOUL.md with new name"
fi

# Update IDENTITY.md with new name
IDENTITY_FILE="${NEW_WORKSPACE}/IDENTITY.md"
if [[ -f "$IDENTITY_FILE" ]]; then
  sed -i.bak "s/${SOURCE_ID}/${NEW_ID}/gi" "$IDENTITY_FILE" 2>/dev/null || \
    sed -i '' "s/${SOURCE_ID}/${NEW_ID}/gI" "$IDENTITY_FILE" 2>/dev/null || \
    sed -i "s/${SOURCE_ID}/${NEW_ID}/g" "$IDENTITY_FILE"
  rm -f "${IDENTITY_FILE}.bak"
  log_debug "Updated IDENTITY.md with new name"
fi

# Add new agent to config
log_info "Adding agent to config..."
CONFIG=$(_read_openclaw_config) || exit 1

# Create new agent config based on source
NEW_AGENT=$(echo "$SOURCE_CONFIG" | jq \
  --arg id "$NEW_ID" \
  --arg name "$NEW_ID" \
  --arg ws "$NEW_WORKSPACE" \
  '.id = $id | .name = $name | .workspace = $ws')

# Add to agents.list
NEW_CONFIG=$(echo "$CONFIG" | jq --argjson agent "$NEW_AGENT" \
  '.agents.list += [$agent]')

_write_openclaw_config "$NEW_CONFIG"

# Success message
log_info "✓ Cloned agent '$SOURCE_ID' to '$NEW_ID'"
echo ""
echo "Workspace: $NEW_WORKSPACE"
echo ""
echo "Next steps:"
echo "  1. Edit the soul:  clawforge edit $NEW_ID --soul"
echo "  2. Edit identity:  clawforge edit $NEW_ID --identity"
echo "  3. Bind to channel: clawforge bind $NEW_ID <channel-id>"
echo "  4. Apply changes:   clawforge apply"
