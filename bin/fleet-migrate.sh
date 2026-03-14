#!/usr/bin/env bash
# fleet-migrate.sh — Workspace isolation migration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

usage() {
  cat <<EOF
Usage: clawforge migrate [options]

Migrate agent workspaces from nested to isolated layout.

Old layout (nested):
  ~/.openclaw/workspace/agents/<id>/

New layout (isolated):
  ~/.openclaw/agents/<id>/

Options:
  --cleanup     Remove old workspace copies after successful migration
  --dry-run     Show what would happen without making changes
  --help        Show this help

Notes:
  - Creates ~/.openclaw/agents/ directory
  - Copies workspace directories to new locations
  - Updates openclaw.json workspace paths
  - Skips agents already at new location
  - Special handling for 'main' agent (stays at ~/.openclaw/workspace/)
EOF
}

# Parse arguments
CLEANUP=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cleanup)  CLEANUP=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    -*)
      log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      log_error "Unexpected argument: $1"; usage; exit 1
      shift ;;
  esac
done

# Read current config
CONFIG=$(_read_openclaw_config) || exit 1

# Find agents that need migration
LEGACY_BASE="${OPENCLAW_WORKSPACE}/agents"
NEW_BASE="${OPENCLAW_AGENTS_DIR}"

# Get all non-main agents
AGENTS=$(echo "$CONFIG" | jq -r '.agents.list[] | select(.id != "main") | .id' 2>/dev/null || true)

if [[ -z "$AGENTS" ]]; then
  log_info "No agents found to migrate"
  exit 0
fi

# Categorize agents
TO_MIGRATE=()
ALREADY_MIGRATED=()
MISSING_WORKSPACE=()

while IFS= read -r agent_id; do
  [[ -z "$agent_id" ]] && continue
  
  # Check current workspace location
  WORKSPACE=$(_get_workspace "$agent_id")
  
  if [[ "$WORKSPACE" == "${NEW_BASE}/${agent_id}" ]]; then
    # Already at new location
    ALREADY_MIGRATED+=("$agent_id")
  elif [[ -d "${LEGACY_BASE}/${agent_id}" ]]; then
    # At legacy location, needs migration
    TO_MIGRATE+=("$agent_id")
  else
    # Workspace not found at either location
    MISSING_WORKSPACE+=("$agent_id")
  fi
done <<< "$AGENTS"

# Show migration plan
echo "Workspace Migration Plan"
echo "────────────────────────────────────────"
echo ""
echo "Agents to migrate:    ${#TO_MIGRATE[@]}"
echo "Already migrated:     ${#ALREADY_MIGRATED[@]}"
echo "Missing workspaces:   ${#MISSING_WORKSPACE[@]}"
echo ""

if [[ ${#ALREADY_MIGRATED[@]} -gt 0 ]]; then
  echo "Already at new location:"
  printf '  - %s\n' "${ALREADY_MIGRATED[@]}"
  echo ""
fi

if [[ ${#MISSING_WORKSPACE[@]} -gt 0 ]]; then
  log_warn "Missing workspaces:"
  printf '  - %s\n' "${MISSING_WORKSPACE[@]}"
  echo ""
fi

if [[ ${#TO_MIGRATE[@]} -eq 0 ]]; then
  if $DRY_RUN; then
    echo "[DRY-RUN] No agents need migration — all already at new location."
  else
    log_info "No agents need migration"
  fi
  exit 0
fi

echo "Agents to migrate:"
for agent_id in "${TO_MIGRATE[@]}"; do
  echo "  - $agent_id"
  echo "    ${LEGACY_BASE}/${agent_id}/ → ${NEW_BASE}/${agent_id}/"
done
echo ""

if $DRY_RUN; then
  echo "[DRY-RUN] Would perform migration:"
  echo "  1. Create ${NEW_BASE}/ directory"
  echo "  2. Copy ${#TO_MIGRATE[@]} workspace(s)"
  echo "  3. Update openclaw.json paths"
  if $CLEANUP; then
    echo "  4. Remove old workspace copies"
  fi
  exit 0
fi

# Confirm migration
echo "Proceed with migration? [y/N]"
read -r CONFIRM
if [[ ! "$CONFIM" =~ ^[Yy]$ ]]; then
  log_info "Migration cancelled"
  exit 0
fi

# Create new base directory
mkdir -p "$NEW_BASE"

# Migrate each agent
MIGRATED=0
FAILED=0

for agent_id in "${TO_MIGRATE[@]}"; do
  SRC="${LEGACY_BASE}/${agent_id}"
  DST="${NEW_BASE}/${agent_id}"
  
  echo ""
  log_info "Migrating $agent_id..."
  
  # Copy workspace
  if cp -R "$SRC" "$DST"; then
    # Update config
    NEW_CONFIG=$(echo "$CONFIG" | jq --arg id "$agent_id" --arg ws "$DST" \
      '(.agents.list[] | select(.id == $id)).workspace = $ws')
    CONFIG="$NEW_CONFIG"
    
    MIGRATED=$((MIGRATED + 1))
    log_info "✓ Migrated $agent_id"
  else
    log_error "Failed to copy workspace for $agent_id"
    FAILED=$((FAILED + 1))
  fi
done

# Write updated config if any migrations succeeded
if [[ $MIGRATED -gt 0 ]]; then
  _write_openclaw_config "$CONFIG"
fi

# Cleanup old copies if requested
if $CLEANUP && [[ $MIGRATED -gt 0 ]]; then
  echo ""
  log_info "Cleaning up old workspace copies..."
  for agent_id in "${TO_MIGRATE[@]}"; do
    SRC="${LEGACY_BASE}/${agent_id}"
    if [[ -d "$SRC" ]]; then
      rm -rf "$SRC"
      log_debug "Removed $SRC"
    fi
  done
  log_info "✓ Cleanup complete"
fi

# Summary
echo ""
echo "────────────────────────────────────────"
echo "Migration complete"
echo "  Migrated: $MIGRATED"
if [[ $FAILED -gt 0 ]]; then
  echo "  Failed:   $FAILED"
fi
echo ""
echo "Next steps:"
echo "  1. Verify agents work correctly"
echo "  2. Run 'clawforge doctor' to check fleet health"
if ! $CLEANUP; then
  echo "  3. Run 'clawforge migrate --cleanup' to remove old copies"
fi
