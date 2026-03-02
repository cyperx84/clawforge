#!/usr/bin/env bash
# templates.sh — Task templates: pre-configured workflow settings
# Usage: clawforge templates [list|new|show] [name]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

BUILTIN_DIR="${CLAWFORGE_DIR}/lib/templates"
USER_DIR="${HOME}/.clawforge/templates"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge templates [command] [name]

Manage task templates for pre-configured workflows.

Commands:
  clawforge templates              List all available templates
  clawforge templates show <name>  Show template details
  clawforge templates new <name>   Create a new custom template

Template Usage:
  clawforge sprint --template refactor "Refactor auth module"
  clawforge swarm --template migration "Migrate to TypeScript"

Flags:
  --json       Output as JSON
  --help       Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
COMMAND="" NAME="" JSON_OUTPUT=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     JSON_OUTPUT=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    --*)        log_error "Unknown option: $1"; usage; exit 1 ;;
    *)          POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  COMMAND="${POSITIONAL[0]}"
fi
if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
  NAME="${POSITIONAL[1]}"
fi

# ── List templates ─────────────────────────────────────────────────────
_list_templates() {
  if $JSON_OUTPUT; then
    local result="[]"
  fi

  if ! $JSON_OUTPUT; then
    echo "=== Available Templates ==="
    echo ""
    echo "  Built-in:"
  fi

  # Built-in templates
  if [[ -d "$BUILTIN_DIR" ]]; then
    for f in "$BUILTIN_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      local name desc mode
      name=$(basename "$f" .json)
      desc=$(jq -r '.description // "No description"' "$f" 2>/dev/null)
      mode=$(jq -r '.mode // "—"' "$f" 2>/dev/null)
      if $JSON_OUTPUT; then
        local entry
        entry=$(jq -c --arg name "$name" --arg source "builtin" '. + {name: $name, source: $source}' "$f" 2>/dev/null)
        result=$(echo "$result" | jq --argjson e "$entry" '. += [$e]')
      else
        printf "    %-20s %-10s %s\n" "$name" "[$mode]" "$desc"
      fi
    done
  fi

  # User templates
  if [[ -d "$USER_DIR" ]]; then
    if ! $JSON_OUTPUT; then
      echo ""
      echo "  Custom:"
    fi
    local found=false
    for f in "$USER_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      found=true
      local name desc mode
      name=$(basename "$f" .json)
      desc=$(jq -r '.description // "No description"' "$f" 2>/dev/null)
      mode=$(jq -r '.mode // "—"' "$f" 2>/dev/null)
      if $JSON_OUTPUT; then
        local entry
        entry=$(jq -c --arg name "$name" --arg source "custom" '. + {name: $name, source: $source}' "$f" 2>/dev/null)
        result=$(echo "$result" | jq --argjson e "$entry" '. += [$e]')
      else
        printf "    %-20s %-10s %s\n" "$name" "[$mode]" "$desc"
      fi
    done
    if ! $found && ! $JSON_OUTPUT; then
      echo "    (none — create with: clawforge templates new <name>)"
    fi
  elif ! $JSON_OUTPUT; then
    echo ""
    echo "  Custom:"
    echo "    (none — create with: clawforge templates new <name>)"
  fi

  if $JSON_OUTPUT; then
    echo "$result" | jq '.'
  fi
}

# ── Show template ──────────────────────────────────────────────────────
_show_template() {
  local name="$1"
  local file=""

  # Check user templates first, then builtin
  if [[ -f "${USER_DIR}/${name}.json" ]]; then
    file="${USER_DIR}/${name}.json"
  elif [[ -f "${BUILTIN_DIR}/${name}.json" ]]; then
    file="${BUILTIN_DIR}/${name}.json"
  else
    log_error "Template '$name' not found"
    echo "Available templates:"
    _list_templates
    exit 1
  fi

  if $JSON_OUTPUT; then
    jq --arg name "$name" '. + {name: $name}' "$file"
  else
    echo "=== Template: $name ==="
    echo ""
    jq -r 'to_entries[] | "  \(.key): \(.value)"' "$file" 2>/dev/null
  fi
}

# ── Create new template ───────────────────────────────────────────────
_new_template() {
  local name="$1"
  mkdir -p "$USER_DIR"

  local target="${USER_DIR}/${name}.json"
  if [[ -f "$target" ]]; then
    log_error "Template '$name' already exists at $target"
    exit 1
  fi

  echo "Creating template: $name"
  echo ""

  # Interactive prompts (or defaults if non-interactive)
  local mode="sprint" max_agents=3 auto_merge=false ci_loop=false description=""

  if [[ -t 0 ]]; then
    printf "  Mode [sprint/swarm/review] (sprint): "
    read -r mode_input
    [[ -n "$mode_input" ]] && mode="$mode_input"

    if [[ "$mode" == "swarm" ]]; then
      printf "  Max agents (3): "
      read -r agents_input
      [[ -n "$agents_input" ]] && max_agents="$agents_input"
    fi

    printf "  Auto-merge [true/false] (false): "
    read -r merge_input
    [[ "$merge_input" == "true" ]] && auto_merge=true

    printf "  CI loop [true/false] (false): "
    read -r ci_input
    [[ "$ci_input" == "true" ]] && ci_loop=true

    printf "  Description: "
    read -r description
  fi

  # Build template JSON
  local template
  template=$(jq -cn \
    --arg mode "$mode" \
    --argjson maxAgents "$max_agents" \
    --argjson autoMerge "$auto_merge" \
    --argjson ciLoop "$ci_loop" \
    --arg description "${description:-Custom template: $name}" \
    '{
      mode: $mode,
      maxAgents: $maxAgents,
      autoMerge: $autoMerge,
      ciLoop: $ciLoop,
      description: $description
    }')

  echo "$template" | jq '.' > "$target"
  echo ""
  echo "Template saved: $target"
  echo "$template" | jq '.'
}

# ── Load template (called from sprint/swarm) ──────────────────────────
# Usage: source templates.sh && load_template <name>
# Returns JSON template to stdout
load_template() {
  local name="$1"
  local file=""

  if [[ -f "${USER_DIR}/${name}.json" ]]; then
    file="${USER_DIR}/${name}.json"
  elif [[ -f "${BUILTIN_DIR}/${name}.json" ]]; then
    file="${BUILTIN_DIR}/${name}.json"
  else
    log_error "Template '$name' not found"
    return 1
  fi

  cat "$file"
}

# ── Route ──────────────────────────────────────────────────────────────
case "${COMMAND:-list}" in
  list|"")
    _list_templates
    ;;
  show)
    [[ -z "$NAME" ]] && { log_error "Template name required"; usage; exit 1; }
    _show_template "$NAME"
    ;;
  new)
    [[ -z "$NAME" ]] && { log_error "Template name required"; usage; exit 1; }
    _new_template "$NAME"
    ;;
  *)
    # Treat as template name to show
    _show_template "$COMMAND"
    ;;
esac
