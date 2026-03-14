#!/usr/bin/env bash
# patch-references.sh — Standalone reference file patcher from clwatch payload
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Tool-to-file mapping ───────────────────────────────────────────────
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
Usage: patch-references.sh --tool <id> --payload <json_file> [options]

Options:
  --tool <id>       Tool ID (e.g., claude-code)
  --payload <file>  Path to clwatch payload JSON file
  --refs-dir <dir>  Reference files directory (default: auto-detect)
  --auto            Apply patch without confirmation
  --dry-run         Show what would change without writing
  --help            Show this help
EOF
}

# ── Parse arguments ────────────────────────────────────────────────────
TOOL_ID="" PAYLOAD_FILE="" REFS_DIR="" AUTO=false DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)       TOOL_ID="$2"; shift 2 ;;
    --payload)    PAYLOAD_FILE="$2"; shift 2 ;;
    --refs-dir)   REFS_DIR="$2"; shift 2 ;;
    --auto)       AUTO=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)            log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Validate arguments ─────────────────────────────────────────────────
if [[ -z "$TOOL_ID" || -z "$PAYLOAD_FILE" ]]; then
  log_error "Missing required arguments: --tool and --payload"
  usage
  exit 1
fi

if [[ ! -f "$PAYLOAD_FILE" ]]; then
  log_error "Payload file not found: $PAYLOAD_FILE"
  exit 1
fi

# ── Auto-detect references directory ───────────────────────────────────
_detect_refs_dir() {
  local custom_dir="$1"

  # 1. User-provided
  if [[ -n "$custom_dir" && -d "$custom_dir" ]]; then
    echo "$custom_dir"
    return 0
  fi

  # 2. ~/.clawforge/references/
  if [[ -d "${HOME}/.clawforge/references" ]]; then
    echo "${HOME}/.clawforge/references"
    return 0
  fi

  # 3. cwd/references/
  if [[ -d "references" ]]; then
    echo "references"
    return 0
  fi

  # 4. $CLAWFORGE_DIR/references/
  if [[ -d "${CLAWFORGE_DIR}/references" ]]; then
    echo "${CLAWFORGE_DIR}/references"
    return 0
  fi

  return 1
}

# ── Get reference file path from tool ID ───────────────────────────────
_get_ref_file() {
  local tool="$1" refs_dir="$2"
  local filename="${TOOL_MAP[$tool]:-}"

  if [[ -z "$filename" ]]; then
    return 1
  fi

  echo "${refs_dir}/${filename}"
}

# ── Extract delta from payload ─────────────────────────────────────────
_extract_delta() {
  local payload_file="$1"

  # Check if delta is empty
  if ! jq '.delta' "$payload_file" >/dev/null 2>&1; then
    log_error "Invalid payload: missing 'delta' field"
    return 1
  fi

  local delta
  delta=$(jq '.delta' "$payload_file")

  # Check if all delta fields are empty
  local has_changes=false
  if jq '.delta.new_features[]?' "$payload_file" >/dev/null 2>&1; then has_changes=true; fi
  if jq '.delta.new_commands[]?' "$payload_file" >/dev/null 2>&1; then has_changes=true; fi
  if jq '.delta.new_flags[]?' "$payload_file" >/dev/null 2>&1; then has_changes=true; fi
  if jq '.delta.deprecated_commands[]?' "$payload_file" >/dev/null 2>&1; then has_changes=true; fi
  if jq '.delta.breaking_changes[]?' "$payload_file" >/dev/null 2>&1; then has_changes=true; fi

  if ! $has_changes; then
    log_debug "No changes in delta"
    return 1
  fi

  echo "$delta"
}

# ── Build formatted change lists ───────────────────────────────────────
_format_changes() {
  local delta_json="$1"

  local features commands flags deprecated breaking

  features=$(echo "$delta_json" | jq -r '.new_features[]? // empty' | sed 's/^/  - /')
  [[ -z "$features" ]] && features="(none)"

  commands=$(echo "$delta_json" | jq -r '.new_commands[]? // empty' | sed 's/^/  - /')
  [[ -z "$commands" ]] && commands="(none)"

  flags=$(echo "$delta_json" | jq -r '.new_flags[]? // empty' | sed 's/^/  - /')
  [[ -z "$flags" ]] && flags="(none)"

  deprecated=$(echo "$delta_json" | jq -r '.deprecated_commands[]? // empty' | sed 's/^/  - /')
  [[ -z "$deprecated" ]] && deprecated="(none)"

  breaking=$(echo "$delta_json" | jq -r '.breaking_changes[]? // empty' | sed 's/^/  - /')
  [[ -z "$breaking" ]] && breaking="(none)"

  echo "FEATURES:$features"
  echo "COMMANDS:$commands"
  echo "FLAGS:$flags"
  echo "DEPRECATED:$deprecated"
  echo "BREAKING:$breaking"
}

# ── Patch via append ───────────────────────────────────────────────────
_patch_append() {
  local file="$1" tool="$2" version="$3" delta_json="$4"

  mkdir -p "$(dirname "$file")"

  # Parse changes
  local features commands flags deprecated breaking
  features=$(echo "$delta_json" | jq -r '.new_features[]? // empty' | sed 's/^/  - /' || echo "(none)")
  commands=$(echo "$delta_json" | jq -r '.new_commands[]? // empty' | sed 's/^/  - /' || echo "(none)")
  flags=$(echo "$delta_json" | jq -r '.new_flags[]? // empty' | sed 's/^/  - /' || echo "(none)")
  deprecated=$(echo "$delta_json" | jq -r '.deprecated_commands[]? // empty' | sed 's/^/  - /' || echo "(none)")
  breaking=$(echo "$delta_json" | jq -r '.breaking_changes[]? // empty' | sed 's/^/  - /' || echo "(none)")

  cat >> "$file" <<EOF

## Updated: $tool v$version

### New Features
$features

### New Commands
$commands

### New Flags
$flags

### Deprecated (since $version)
$deprecated

### Breaking Changes
$breaking
EOF

  log_info "Appended changes to $file"
}

# ── Main execution ─────────────────────────────────────────────────────
main() {
  # Auto-detect refs dir
  REFS_DIR=$(_detect_refs_dir "$REFS_DIR") || {
    log_error "Could not locate references directory"
    return 1
  }

  # Get reference file path
  local ref_file
  ref_file=$(_get_ref_file "$TOOL_ID" "$REFS_DIR") || {
    log_error "Unknown tool ID: $TOOL_ID"
    exit 1
  }

  log_info "Tool: $TOOL_ID"
  log_info "Payload: $PAYLOAD_FILE"
  log_info "Reference file: $ref_file"

  # Extract and validate delta
  local delta
  delta=$(_extract_delta "$PAYLOAD_FILE") || {
    log_debug "No changes to apply"
    exit 0
  }

  # Get version
  local version
  version=$(jq -r '.version // "unknown"' "$PAYLOAD_FILE")

  # Show what would change
  log_info "Changes detected in v$version:"
  _format_changes "$delta" | while IFS=: read -r key value; do
    if [[ "$value" != "(none)" ]]; then
      echo "$key$value"
    fi
  done

  if $DRY_RUN; then
    log_info "[DRY-RUN] Would patch: $ref_file"
    return 0
  fi

  if ! $AUTO; then
    read -p "Apply patch to $ref_file? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Cancelled"
      return 0
    fi
  fi

  # Apply patch
  _patch_append "$ref_file" "$TOOL_ID" "$version" "$delta"
  log_info "Successfully patched $ref_file"
}

main "$@"
