#!/usr/bin/env bash
# fleet-export.sh — Package agent as shareable .clawforge archive
# Usage: clawforge export <id> [--no-memory|--with-memory] [--no-user] [--output <path>]

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

# ── Parse args ────────────────────────────────────────────────────────
agent_id=""
output_path=""
include_memory=false
include_user=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o)
      output_path="$2"
      shift 2
      ;;
    --with-memory)
      include_memory=true
      shift
      ;;
    --no-memory)
      include_memory=false
      shift
      ;;
    --no-user)
      include_user=false
      shift
      ;;
    -*)
      log_error "Unknown flag: $1"
      exit 1
      ;;
    *)
      if [[ -z "$agent_id" ]]; then
        agent_id="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$agent_id" ]]; then
  log_error "Usage: clawforge export <id> [--no-memory|--with-memory] [--no-user] [--output <path>]"
  exit 1
fi

# ── Get agent info ─────────────────────────────────────────────────────
agent_json=$(_get_agent "$agent_id") || {
  log_error "Agent '$agent_id' not found in config"
  exit 1
}

workspace=$(_get_workspace "$agent_id")

if [[ ! -d "$workspace" ]]; then
  log_error "Agent workspace not found: $workspace"
  exit 1
fi

# ── Prepare temp directory ─────────────────────────────────────────────
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

archive_dir="${temp_dir}/${agent_id}"
mkdir -p "$archive_dir"

# ── Create manifest.json ───────────────────────────────────────────────
log_info "Creating manifest for $agent_id..."

# Get agent name from IDENTITY.md if exists, else capitalize ID
agent_name="$agent_id"
if [[ -f "${workspace}/IDENTITY.md" ]]; then
  extracted_name=$(grep -E '^\*\*Name:\*\*' "${workspace}/IDENTITY.md" | head -1 | sed 's/\*\*Name:\*\* //' | xargs || true)
  if [[ -n "$extracted_name" && "$extracted_name" != " "* ]]; then
    agent_name="$extracted_name"
  fi
fi

# Get model
model=$(_get_model_primary "$agent_json")
fallbacks=$(_get_model_fallbacks "$agent_json")

# Get archetype source (from SOUL.md if we can detect it)
archetype_source="unknown"
if [[ -f "${workspace}/SOUL.md" ]]; then
  # Try to detect archetype from comments or structure
  if grep -q "coding specialist" "${workspace}/SOUL.md" 2>/dev/null; then
    archetype_source="coder"
  elif grep -q "monitoring" "${workspace}/SOUL.md" 2>/dev/null; then
    archetype_source="monitor"
  elif grep -q "research" "${workspace}/SOUL.md" 2>/dev/null; then
    archetype_source="researcher"
  elif grep -q "communication" "${workspace}/SOUL.md" 2>/dev/null; then
    archetype_source="communicator"
  elif grep -q "generalist\|orchestrat" "${workspace}/SOUL.md" 2>/dev/null; then
    archetype_source="generalist"
  fi
fi

# Get clawforge version
clawforge_version=$(cat "${CLAWFORGE_DIR}/VERSION" 2>/dev/null || echo "unknown")

# Get created date from workspace (use oldest file mtime)
created_date=$(find "$workspace" -type f -printf '%T@\n' 2>/dev/null | sort -n | head -1 | xargs -I{} date -u -r {} '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')

# Build manifest
cat > "${archive_dir}/manifest.json" <<EOF
{
  "id": "${agent_id}",
  "name": "${agent_name}",
  "model": "${model}",
  "modelFallbacks": ${fallbacks},
  "archetype": "${archetype_source}",
  "created": "${created_date}",
  "exported": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "clawforgeVersion": "${clawforge_version}",
  "exportOptions": {
    "includeMemory": ${include_memory},
    "includeUser": ${include_user}
  }
}
EOF

log_debug "Created manifest.json"

# ── Copy workspace files ────────────────────────────────────────────────
log_info "Copying workspace files..."

# Core files to include (always)
core_files=(SOUL.md AGENTS.md TOOLS.md IDENTITY.md HEARTBEAT.md)

for file in "${core_files[@]}"; do
  if [[ -f "${workspace}/${file}" ]]; then
    cp "${workspace}/${file}" "${archive_dir}/"
    log_debug "  ✓ ${file}"
  fi
done

# USER.md (optional based on flag)
if $include_user && [[ -f "${workspace}/USER.md" ]]; then
  cp "${workspace}/USER.md" "${archive_dir}/"
  log_debug "  ✓ USER.md"
fi

# Memory directory (optional based on flag)
if $include_memory; then
  if [[ -d "${workspace}/memory" ]]; then
    cp -r "${workspace}/memory" "${archive_dir}/"
    log_debug "  ✓ memory/ ($(find "${workspace}/memory" -type f | wc -l | tr -d ' ') files)"
  fi
fi

# References directory (always include if exists)
if [[ -d "${workspace}/references" ]]; then
  cp -r "${workspace}/references" "${archive_dir}/"
  log_debug "  ✓ references/ ($(find "${workspace}/references" -type f | wc -l | tr -d ' ') files)"
fi

# ── Create archive ─────────────────────────────────────────────────────
log_info "Creating archive..."

# Determine output path
if [[ -z "$output_path" ]]; then
  output_path="${agent_id}.clawforge"
fi

# Make output path absolute if not already
if [[ "${output_path:0:1}" != "/" ]]; then
  output_path="$(pwd)/${output_path}"
fi

# Create tar.gz archive
# Exclude common junk files
tar --create \
    --gzip \
    --file="$output_path" \
    --directory="$temp_dir" \
    --exclude=".git" \
    --exclude="__pycache__" \
    --exclude=".DS_Store" \
    --exclude="*.pyc" \
    --exclude="node_modules" \
    --exclude=".env" \
    "$agent_id" || {
  log_error "Failed to create archive"
  exit 1
}

# ── Report ─────────────────────────────────────────────────────────────
archive_size=$(wc -c < "$output_path" | xargs)
archive_size_human=$(_human_size "$archive_size")

echo ""
log_info "✓ Exported agent: ${agent_id}"
echo ""
echo "  Archive: ${output_path}"
echo "  Size:    ${archive_size_human}"
echo "  Files:   $(find "$archive_dir" -type f | wc -l | tr -d ' ')"
echo ""
echo "Contains:"
echo "  • manifest.json"
for file in "${core_files[@]}"; do
  if [[ -f "${archive_dir}/${file}" ]]; then
    echo "  • ${file}"
  fi
done
if $include_user && [[ -f "${archive_dir}/USER.md" ]]; then
  echo "  • USER.md"
fi
if $include_memory && [[ -d "${archive_dir}/memory" ]]; then
  echo "  • memory/"
fi
if [[ -d "${archive_dir}/references" ]]; then
  echo "  • references/"
fi
echo ""
echo "Share this file or import with:"
echo "  clawforge import ${output_path}"
