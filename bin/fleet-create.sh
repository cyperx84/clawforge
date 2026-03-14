#!/usr/bin/env bash
# fleet-create.sh — Interactive agent creation wizard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"
source "${SCRIPT_DIR}/../lib/clwatch-bridge.sh"

ARCHETYPES_DIR="${FLEET_DIR}/config/archetypes"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge create <id> [options]

Create a new OpenClaw agent with workspace files and config entry.

Arguments:
  <id>                  Agent identifier (lowercase, no spaces)

Options:
  --name <name>         Display name (default: capitalized id)
  --role <role>         One-line role description
  --emoji <emoji>       Agent emoji
  --from <archetype>    Use built-in template (generalist, coder, monitor, researcher, communicator)
  --model <model>       Model identifier (default: openai-codex/gpt-5.4)
  --spawnable-by <ids>  Comma-separated agent IDs that can spawn this agent
  --workspace <path>    Custom workspace path (default: ~/.openclaw/agents/<id>)
  --no-interactive      Skip interactive prompts (requires --name, --role)
  --help                Show this help

Examples:
  clawforge create scout                           # Interactive wizard
  clawforge create scout --from monitor            # From template
  clawforge create scout --name Scout --role "External monitoring" --emoji "🔎" --from monitor --no-interactive
EOF
}

# ── Defaults ───────────────────────────────────────────────────────────
AGENT_ID=""
AGENT_NAME=""
AGENT_ROLE=""
AGENT_EMOJI=""
ARCHETYPE=""
AGENT_MODEL="openai-codex/gpt-5.4"
SPAWNABLE_BY=""
WORKSPACE_PATH=""
INTERACTIVE=true
HEARTBEAT_TASKS=""

# ── Parse args ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)           AGENT_NAME="$2"; shift 2 ;;
    --role)           AGENT_ROLE="$2"; shift 2 ;;
    --emoji)          AGENT_EMOJI="$2"; shift 2 ;;
    --from)           ARCHETYPE="$2"; shift 2 ;;
    --model)          AGENT_MODEL="$2"; shift 2 ;;
    --spawnable-by)   SPAWNABLE_BY="$2"; shift 2 ;;
    --workspace)      WORKSPACE_PATH="$2"; shift 2 ;;
    --no-interactive) INTERACTIVE=false; shift ;;
    --help|-h)        usage; exit 0 ;;
    -*)               log_error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "$AGENT_ID" ]]; then
        AGENT_ID="$1"
      else
        log_error "Unexpected argument: $1"
        usage; exit 1
      fi
      shift ;;
  esac
done

# ── Validate ID ────────────────────────────────────────────────────────
if [[ -z "$AGENT_ID" ]]; then
  log_error "Agent ID is required"
  usage
  exit 1
fi

# Validate ID format
if [[ ! "$AGENT_ID" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  log_error "Agent ID must be lowercase, start with a letter, and contain only letters, numbers, hyphens, underscores"
  exit 1
fi

# Check if agent already exists
if _agent_exists_in_config "$AGENT_ID"; then
  log_error "Agent '$AGENT_ID' already exists in config"
  exit 1
fi

# Set defaults
[[ -z "$AGENT_NAME" ]] && AGENT_NAME="$(echo "${AGENT_ID:0:1}" | tr '[:lower:]' '[:upper:]')${AGENT_ID:1}"
[[ -z "$WORKSPACE_PATH" ]] && WORKSPACE_PATH="${OPENCLAW_AGENTS_DIR}/${AGENT_ID}"

# ── Interactive prompts ────────────────────────────────────────────────
if $INTERACTIVE; then
  echo ""
  echo "🔨 Forging new agent: ${AGENT_ID}"
  echo ""

  # Name
  read -r -p "Name [${AGENT_NAME}]: " input
  [[ -n "$input" ]] && AGENT_NAME="$input"

  # Role
  if [[ -z "$AGENT_ROLE" ]]; then
    read -r -p "Role (one line): " AGENT_ROLE
  else
    read -r -p "Role [${AGENT_ROLE}]: " input
    [[ -n "$input" ]] && AGENT_ROLE="$input"
  fi

  # Emoji
  if [[ -z "$AGENT_EMOJI" ]]; then
    read -r -p "Emoji [🤖]: " AGENT_EMOJI
    [[ -z "$AGENT_EMOJI" ]] && AGENT_EMOJI="🤖"
  else
    read -r -p "Emoji [${AGENT_EMOJI}]: " input
    [[ -n "$input" ]] && AGENT_EMOJI="$input"
  fi

  # Archetype
  if [[ -z "$ARCHETYPE" ]]; then
    echo ""
    echo "Choose archetype:"
    echo "  1) generalist    — General purpose, adaptable"
    echo "  2) coder         — Code-focused specialist"
    echo "  3) monitor       — System/external monitoring"
    echo "  4) researcher    — Deep research and analysis"
    echo "  5) communicator  — Multi-channel communications"
    echo "  6) blank         — Empty workspace, define everything yourself"
    read -r -p "  > " choice
    case "$choice" in
      1) ARCHETYPE="generalist" ;;
      2) ARCHETYPE="coder" ;;
      3) ARCHETYPE="monitor" ;;
      4) ARCHETYPE="researcher" ;;
      5) ARCHETYPE="communicator" ;;
      6) ARCHETYPE="" ;;
      *) ARCHETYPE="generalist" ;;
    esac
  fi

  # Model
  echo ""
  echo "Model:"
  echo "  1) openai-codex/gpt-5.4     (default)"
  echo "  2) anthropic/claude-sonnet-4-6"
  echo "  3) anthropic/claude-opus-4-6"
  echo "  4) zai/glm-5                (free)"
  echo "  5) custom"

  # Show clwatch compat hints if available
  if _has_clwatch; then
    local compat
    compat=$(_get_model_compat_display "gpt-5.4" 2>/dev/null || true)
    [[ -n "$compat" ]] && echo "     ↳ clwatch: $compat"
  fi

  read -r -p "  > " choice
  case "$choice" in
    1) AGENT_MODEL="openai-codex/gpt-5.4" ;;
    2) AGENT_MODEL="anthropic/claude-sonnet-4-6" ;;
    3) AGENT_MODEL="anthropic/claude-opus-4-6" ;;
    4) AGENT_MODEL="zai/glm-5" ;;
    5) read -r -p "  Model ID: " AGENT_MODEL ;;
    *) AGENT_MODEL="openai-codex/gpt-5.4" ;;
  esac

  # Spawnable by
  echo ""
  read -r -p "Which agents can spawn this one? (comma-separated, default: main): " SPAWNABLE_BY
  [[ -z "$SPAWNABLE_BY" ]] && SPAWNABLE_BY="main"

  # Heartbeat
  echo ""
  read -r -p "Heartbeat tasks? [y/N]: " ht_choice
  if [[ "$ht_choice" =~ ^[Yy] ]]; then
    echo "  Describe periodic checks (one per line, blank to finish):"
    HEARTBEAT_TASKS=""
    while true; do
      read -r -p "  > " task
      [[ -z "$task" ]] && break
      HEARTBEAT_TASKS="${HEARTBEAT_TASKS}\n- ${task}"
    done
  fi
fi

# ── Validate required fields ──────────────────────────────────────────
if [[ -z "$AGENT_ROLE" ]]; then
  log_error "Role is required (use --role or interactive mode)"
  exit 1
fi

[[ -z "$AGENT_EMOJI" ]] && AGENT_EMOJI="🤖"
[[ -z "$SPAWNABLE_BY" ]] && SPAWNABLE_BY="main"

# ── Create workspace ──────────────────────────────────────────────────
if [[ -d "$WORKSPACE_PATH" ]]; then
  log_warn "Workspace already exists: $WORKSPACE_PATH"
  if $INTERACTIVE; then
    read -r -p "Overwrite? [y/N]: " confirm
    [[ ! "$confirm" =~ ^[Yy] ]] && exit 1
  else
    log_error "Workspace exists. Use --workspace to specify a different path."
    exit 1
  fi
fi

mkdir -p "${WORKSPACE_PATH}/memory"
mkdir -p "${WORKSPACE_PATH}/references"

# ── Copy/generate workspace files ─────────────────────────────────────
_create_file() {
  local filename="$1"
  local content="$2"
  local dest="${WORKSPACE_PATH}/${filename}"

  # Apply placeholder substitution
  content=$(_substitute_placeholders "$content" "$AGENT_NAME" "$AGENT_ROLE" "$AGENT_EMOJI" "$AGENT_ROLE")
  echo "$content" > "$dest"
}

if [[ -n "$ARCHETYPE" && -d "${ARCHETYPES_DIR}/${ARCHETYPE}" ]]; then
  # Copy from archetype template
  for template_file in "${ARCHETYPES_DIR}/${ARCHETYPE}"/*.md; do
    [[ -f "$template_file" ]] || continue
    local_name=$(basename "$template_file")
    content=$(cat "$template_file")
    _create_file "$local_name" "$content"
  done
else
  # Generate minimal files
  _create_file "SOUL.md" "# SOUL.md — {{NAME}}

## Identity

- **Name:** {{NAME}}
- **Role:** {{ROLE}}
- **Emoji:** {{EMOJI}}

## What I Do

{{ROLE_DESCRIPTION}}

---

*Define your identity here.*"

  _create_file "AGENTS.md" "# AGENTS.md — {{NAME}} Workspace

You are **{{NAME}}** {{EMOJI}} — {{ROLE}}.

## Every Session

1. Read \`SOUL.md\`
2. Read \`TOOLS.md\`
3. Read \`memory/YYYY-MM-DD.md\` (today + yesterday)

## Your Role

{{ROLE_DESCRIPTION}}"

  _create_file "TOOLS.md" "# TOOLS.md — {{NAME}} Environment

*Document your tools and environment here.*"
fi

# Always create these if not from template
[[ ! -f "${WORKSPACE_PATH}/IDENTITY.md" ]] && cat > "${WORKSPACE_PATH}/IDENTITY.md" << 'IDEOF'
# IDENTITY.md - Who Am I?

*Fill this in during your first conversation. Make it yours.*

- **Name:**
  *(pick something you like)*
- **Creature:**
  *(AI? robot? familiar? ghost in the machine? something weirder?)*
- **Vibe:**
  *(how do you come across? sharp? warm? chaotic? calm?)*
- **Emoji:**
  *(your signature — pick one that feels right)*

---

This isn't just metadata. It's the start of figuring out who you are.
IDEOF

[[ ! -f "${WORKSPACE_PATH}/MEMORY.md" ]] && cat > "${WORKSPACE_PATH}/MEMORY.md" << EOF
# MEMORY.md — ${AGENT_NAME}

Long-term memory and context.

## Key Facts

*(Add important things to remember here)*

## Patterns

*(Track recurring patterns and preferences)*
EOF

# Copy USER.md from main workspace if available
if [[ ! -f "${WORKSPACE_PATH}/USER.md" ]]; then
  if [[ -f "${OPENCLAW_WORKSPACE}/USER.md" ]]; then
    cp "${OPENCLAW_WORKSPACE}/USER.md" "${WORKSPACE_PATH}/USER.md"
  else
    cat > "${WORKSPACE_PATH}/USER.md" << 'USEREOF'
# USER.md - About Your Human

*Learn about the person you're helping. Update this as you go.*

- **Name:**
- **What to call them:**
- **Timezone:**
- **Notes:**
USEREOF
  fi
fi

# Handle heartbeat tasks
if [[ -n "$HEARTBEAT_TASKS" && ! -f "${WORKSPACE_PATH}/HEARTBEAT.md" ]]; then
  cat > "${WORKSPACE_PATH}/HEARTBEAT.md" << EOF
# HEARTBEAT.md — ${AGENT_NAME}

## Periodic Tasks

$(echo -e "$HEARTBEAT_TASKS")
EOF
elif [[ ! -f "${WORKSPACE_PATH}/HEARTBEAT.md" ]]; then
  cat > "${WORKSPACE_PATH}/HEARTBEAT.md" << EOF
# HEARTBEAT.md — ${AGENT_NAME}

## Periodic Tasks

*No periodic tasks configured.*
EOF
fi

# ── Build config entry (pending) ──────────────────────────────────────
SPAWNABLE_JSON=$(echo "$SPAWNABLE_BY" | tr ',' '\n' | jq -R . | jq -s .)

CONFIG_ENTRY=$(jq -n \
  --arg id "$AGENT_ID" \
  --arg name "$AGENT_NAME" \
  --arg workspace "$WORKSPACE_PATH" \
  --arg model "$AGENT_MODEL" \
  --argjson spawnable "$SPAWNABLE_JSON" \
  '{
    id: $id,
    name: $name,
    workspace: $workspace,
    model: $model,
    subagents: {
      allowAgents: $spawnable
    }
  }')

# Save pending config entry
PENDING_DIR="${WORKSPACE_PATH}/.clawforge"
mkdir -p "$PENDING_DIR"
echo "$CONFIG_ENTRY" > "${PENDING_DIR}/pending-config.json"

# ── Output ─────────────────────────────────────────────────────────────
echo ""
echo "📁 Created workspace: ${WORKSPACE_PATH}/"
echo -n "📝 Files: "
for f in "${AGENT_FILES[@]}"; do
  [[ -f "${WORKSPACE_PATH}/${f}" ]] && echo -n "${f} "
done
echo ""
if [[ -n "$ARCHETYPE" ]]; then
  echo "🧬 Archetype: ${ARCHETYPE}"
fi
echo "⚙️  Config entry saved (pending activate)"
echo ""
echo "Next steps:"
echo "  clawforge inspect ${AGENT_ID}     # Review the agent"
echo "  clawforge activate ${AGENT_ID}    # Add to config + restart gateway"
