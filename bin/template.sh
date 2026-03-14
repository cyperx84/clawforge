#!/usr/bin/env bash
# template.sh — Manage built-in and user agent templates
# Usage: clawforge template <list|show|create|delete> [args]

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

# ── Paths ──────────────────────────────────────────────────────────────
BUILTIN_TEMPLATES="${CLAWFORGE_DIR}/config/archetypes"
USER_TEMPLATES="${HOME}/.clawforge/templates"

# ── Commands ────────────────────────────────────────────────────────────

list_templates() {
  echo "🔨 ClawForge Templates"
  echo ""

  # Built-in templates
  echo "Built-in archetypes:"
  if [[ -d "$BUILTIN_TEMPLATES" ]]; then
    for dir in "$BUILTIN_TEMPLATES"/*/; do
      if [[ -d "$dir" ]]; then
        name=$(basename "$dir")
        desc=""
        if [[ -f "${dir}/SOUL.md" ]]; then
          # Extract first line as description
          desc=$(head -1 "${dir}/SOUL.md" | sed 's/^# //' | cut -c1-60)
        fi
        printf "  %-20s %s\n" "$name" "${desc:-(no description)}"
      fi
    done
  else
    echo "  (none found)"
  fi

  echo ""

  # User templates
  echo "User templates:"
  if [[ -d "$USER_TEMPLATES" ]]; then
    local found=false
    for dir in "$USER_TEMPLATES"/*/; do
      if [[ -d "$dir" ]]; then
        found=true
        name=$(basename "$dir")
        desc=""
        if [[ -f "${dir}/SOUL.md" ]]; then
          desc=$(head -1 "${dir}/SOUL.md" | sed 's/^# //' | cut -c1-60)
        fi
        printf "  %-20s %s\n" "$name" "${desc:-(no description)}"
      fi
    done
    if ! $found; then
      echo "  (none yet — create with 'clawforge template create <name> --from <agent-id>')"
    fi
  else
    echo "  (none yet — create with 'clawforge template create <name> --from <agent-id>')"
  fi

  echo ""
  echo "Usage:"
  echo "  clawforge create <id> --from <template-name>"
  echo "  clawforge template show <name>"
}

show_template() {
  local name="$1"

  # Check built-in first
  local template_dir="${BUILTIN_TEMPLATES}/${name}"
  local is_builtin=true

  if [[ ! -d "$template_dir" ]]; then
    # Check user templates
    template_dir="${USER_TEMPLATES}/${name}"
    is_builtin=false
  fi

  if [[ ! -d "$template_dir" ]]; then
    log_error "Template not found: ${name}"
    echo ""
    echo "Available templates:"
    echo "  Run 'clawforge template list' to see all templates"
    exit 1
  fi

  echo "🔨 Template: ${name}"
  if $is_builtin; then
    echo "  Type: Built-in archetype"
  else
    echo "  Type: User template"
    echo "  Path: ${template_dir}"
  fi
  echo ""

  # Show SOUL.md
  if [[ -f "${template_dir}/SOUL.md" ]]; then
    echo "── SOUL.md ──────────────────────────────────────"
    cat "${template_dir}/SOUL.md"
    echo ""
    echo ""
  fi

  # Show AGENTS.md
  if [[ -f "${template_dir}/AGENTS.md" ]]; then
    echo "── AGENTS.md ────────────────────────────────────"
    cat "${template_dir}/AGENTS.md"
    echo ""
    echo ""
  fi

  # List other files
  echo "Other files:"
  for file in TOOLS.md IDENTITY.md HEARTBEAT.md; do
    if [[ -f "${template_dir}/${file}" ]]; then
      size=$(wc -c < "${template_dir}/${file}" | xargs)
      printf "  • %-15s %s bytes\n" "$file" "$size"
    fi
  done
  echo ""

  echo "Usage:"
  echo "  clawforge create my-agent --from ${name}"
}

create_template() {
  local name="$1"
  local from_agent=""

  # Parse args
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)
        from_agent="$2"
        shift 2
        ;;
      *)
        log_error "Unknown flag: $1"
        exit 1
        ;;
    esac
  done

  if [[ -z "$from_agent" ]]; then
    log_error "Usage: clawforge template create <name> --from <agent-id>"
    exit 1
  fi

  # Get source agent
  local agent_json
  agent_json=$(_get_agent "$from_agent") || {
    log_error "Agent '$from_agent' not found in config"
    exit 1
  }

  local workspace
  workspace=$(_get_workspace "$from_agent")

  if [[ ! -d "$workspace" ]]; then
    log_error "Agent workspace not found: $workspace"
    exit 1
  fi

  # Check if template name already exists
  local template_dir="${USER_TEMPLATES}/${name}"

  if [[ -d "$template_dir" ]]; then
    log_error "Template already exists: ${name}"
    log_error "Delete it first with 'clawforge template delete ${name}'"
    exit 1
  fi

  # Check if trying to overwrite built-in
  if [[ -d "${BUILTIN_TEMPLATES}/${name}" ]]; then
    log_error "Cannot overwrite built-in archetype: ${name}"
    log_error "Choose a different name for your template"
    exit 1
  fi

  # Create template directory
  log_info "Creating template: ${name}"
  mkdir -p "$template_dir"

  # Copy workspace files
  local files=(SOUL.md AGENTS.md TOOLS.md IDENTITY.md HEARTBEAT.md)

  for file in "${files[@]}"; do
    if [[ -f "${workspace}/${file}" ]]; then
      cp "${workspace}/${file}" "${template_dir}/"
      log_debug "  ✓ ${file}"
    fi
  done

  # Copy references if exists
  if [[ -d "${workspace}/references" ]]; then
    cp -r "${workspace}/references" "${template_dir}/"
    log_debug "  ✓ references/"
  fi

  log_success "✓ Created template: ${name}"
  echo ""
  echo "  Path: ${template_dir}"
  echo ""
  echo "Use it with:"
  echo "  clawforge create my-agent --from ${name}"
}

delete_template() {
  local name="$1"

  # Check if built-in
  if [[ -d "${BUILTIN_TEMPLATES}/${name}" ]]; then
    log_error "Cannot delete built-in archetype: ${name}"
    log_error "Built-in archetypes are part of ClawForge and cannot be removed"
    exit 1
  fi

  local template_dir="${USER_TEMPLATES}/${name}"

  if [[ ! -d "$template_dir" ]]; then
    log_error "Template not found: ${name}"
    exit 1
  fi

  # Confirm
  read -p "Delete template '${name}'? [y/N]: " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled"
    exit 0
  fi

  # Delete
  rm -rf "$template_dir"

  log_success "✓ Deleted template: ${name}"
}

# ── Route subcommand ───────────────────────────────────────────────────
COMMAND="${1:-list}"
shift 2>/dev/null || true

case "$COMMAND" in
  list)
    list_templates "$@"
    ;;
  show)
    if [[ $# -lt 1 ]]; then
      log_error "Usage: clawforge template show <name>"
      exit 1
    fi
    show_template "$1"
    ;;
  create)
    if [[ $# -lt 1 ]]; then
      log_error "Usage: clawforge template create <name> --from <agent-id>"
      exit 1
    fi
    create_template "$@"
    ;;
  delete)
    if [[ $# -lt 1 ]]; then
      log_error "Usage: clawforge template delete <name>"
      exit 1
    fi
    delete_template "$1"
    ;;
  *)
    log_error "Unknown template command: $COMMAND"
    echo "Commands: list, show, create, delete"
    exit 1
    ;;
esac
