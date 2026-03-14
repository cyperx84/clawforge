#!/usr/bin/env bash
# fleet-import.sh — Import agent from .clawforge archive
# Usage: clawforge import <path|url> [--id <new-id>] [--model <model>]

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
CLAWFORGE_DIR="$(cd "$(dirname "$SOURCE")/.." && pwd)"

source "${CLAWFORGE_DIR}/lib/common.sh"
source "${CLAWFORGE_DIR}/lib/fleet-common.sh"

# ── Parse args ──────────────────────────────────────────────────────────
source_path=""
new_id=""
model_override=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      new_id="$2"
      shift 2
      ;;
    --model)
      model_override="$2"
      shift 2
      ;;
    -*)
      log_error "Unknown flag: $1"
      exit 1
      ;;
    *)
      if [[ -z "$source_path" ]]; then
        source_path="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$source_path" ]]; then
  log_error "Usage: clawforge import <path|url> [--id <new-id>] [--model <model>]"
  exit 1
fi

# ── Download if URL ─────────────────────────────────────────────────────
temp_download=""
if [[ "$source_path" =~ ^https?:// ]]; then
  log_info "Downloading from $source_path..."

  temp_download=$(mktemp --suffix=.clawforge)
  trap 'rm -f "$temp_download"' EXIT

  if command -v curl &>/dev/null; then
    curl -fsSL "$source_path" -o "$temp_download" || {
      log_error "Failed to download archive"
      exit 1
    }
  elif command -v wget &>/dev/null; then
    wget -q "$source_path" -O "$temp_download" || {
      log_error "Failed to download archive"
      exit 1
    }
  else
    log_error "curl or wget required to download from URL"
    exit 1
  fi

  source_path="$temp_download"
  log_debug "Downloaded to $source_path"
fi

# ── Validate archive ────────────────────────────────────────────────────
if [[ ! -f "$source_path" ]]; then
  log_error "Archive not found: $source_path"
  exit 1
fi

if ! tar -tzf "$source_path" &>/dev/null; then
  log_error "Invalid archive format (expected tar.gz)"
  exit 1
fi

# ── Extract to temp ─────────────────────────────────────────────────────
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir" "$temp_download"' EXIT

log_info "Extracting archive..."
tar -xzf "$source_path" -C "$temp_dir" || {
  log_error "Failed to extract archive"
  exit 1
}

# Find extracted directory (should be one top-level dir)
archive_dirs=($(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d))
if [[ ${#archive_dirs[@]} -ne 1 ]]; then
  log_error "Expected one top-level directory in archive, found ${#archive_dirs[@]}"
  exit 1
fi

archive_dir="${archive_dirs[0]}"

# ── Read manifest ───────────────────────────────────────────────────────
manifest_file="${archive_dir}/manifest.json"
if [[ ! -f "$manifest_file" ]]; then
  log_error "manifest.json not found in archive"
  exit 1
fi

manifest=$(cat "$manifest_file")

# Extract manifest fields
manifest_id=$(echo "$manifest" | jq -r '.id')
manifest_name=$(echo "$manifest" | jq -r '.name')
manifest_model=$(echo "$manifest" | jq -r '.model')
manifest_archetype=$(echo "$manifest" | jq -r '.archetype // "unknown"')
manifest_created=$(echo "$manifest" | jq -r '.created // "unknown"')
manifest_clawforge_version=$(echo "$manifest" | jq -r '.clawforgeVersion // "unknown"')

log_info "Archive manifest:"
echo ""
echo "  ID:        ${manifest_id}"
echo "  Name:      ${manifest_name}"
echo "  Model:     ${manifest_model}"
echo "  Archetype: ${manifest_archetype}"
echo "  Created:   ${manifest_created}"
echo "  Exported:  $(echo "$manifest" | jq -r '.exported // "unknown"')"
echo "  ClawForge: v${manifest_clawforge_version}"
echo ""

# ── Determine new agent ID ──────────────────────────────────────────────
if [[ -z "$new_id" ]]; then
  # Interactive prompt
  read -p "New agent ID [${manifest_id}]: " new_id
  new_id="${new_id:-$manifest_id}"
fi

# Validate ID
if [[ ! "$new_id" =~ ^[a-z0-9_-]+$ ]]; then
  log_error "Invalid agent ID. Use lowercase letters, numbers, hyphens, and underscores only."
  exit 1
fi

# ── Check for existing workspace ────────────────────────────────────────
workspace_path="${OPENCLAW_AGENTS_DIR}/${new_id}"

if [[ -d "$workspace_path" ]]; then
  log_error "Workspace already exists: ${workspace_path}"
  log_error "Refusing to overwrite. Choose a different ID with --id."
  exit 1
fi

# Check if agent exists in config
if _agent_exists_in_config "$new_id"; then
  log_error "Agent '${new_id}' already exists in config"
  log_error "Refusing to overwrite. Choose a different ID with --id."
  exit 1
fi

# ── Determine model ─────────────────────────────────────────────────────
final_model="${model_override:-$manifest_model}"

if [[ -n "$model_override" ]]; then
  log_info "Using model override: ${final_model}"
else
  # Interactive prompt
  read -p "Model [${manifest_model}]: " model_input
  final_model="${model_input:-$manifest_model}"
fi

# ── Create workspace ────────────────────────────────────────────────────
log_info "Creating workspace: ${workspace_path}"

mkdir -p "$workspace_path"

# Copy all files from archive
cp -r "${archive_dir}/"* "$workspace_path/" 2>/dev/null || true

# Remove manifest (it's metadata, not a workspace file)
rm -f "${workspace_path}/manifest.json"

# Create USER.md from template if not in archive
if [[ ! -f "${workspace_path}/USER.md" ]]; then
  log_info "Creating USER.md from template..."

  # Try to use main workspace USER.md as template
  main_user="${OPENCLAW_WORKSPACE}/USER.md"
  if [[ -f "$main_user" ]]; then
    cp "$main_user" "${workspace_path}/USER.md"
    log_debug "Copied from main workspace"
  else
    # Create minimal template
    cat > "${workspace_path}/USER.md" <<'EOF'
# USER.md - About Your Human

*Learn about the person you're helping. Update this as you go.*

- **Name:**
- **What to call them:**
- **Pronouns:** *(optional)*
- **Timezone:**
- **Notes:**

## Context

*(What do they care about? What projects are they working on? What annoys them? What makes them laugh? Build this over time.)*

---

The more you know, the better you can help. But remember — you're learning about a person, not building a dossier. Respect the difference.
EOF
    log_debug "Created minimal template"
  fi
fi

# ── Show next steps ─────────────────────────────────────────────────────
echo ""
log_info "✓ Imported agent: ${new_id}"
echo ""
echo "  Workspace: ${workspace_path}"
echo "  Model:     ${final_model}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Review and customize workspace files:"
echo "     $ clawforge edit ${new_id} --soul"
echo ""
echo "  2. Bind to a channel (optional):"
echo "     $ clawforge bind ${new_id} \"#${new_id}\""
echo ""
echo "  3. Activate the agent:"
echo "     $ clawforge activate ${new_id}"
echo ""
