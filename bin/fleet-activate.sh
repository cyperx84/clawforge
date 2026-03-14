#!/usr/bin/env bash
# fleet-activate.sh — Add agent to openclaw.json config + restart gateway
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge activate <id> [options]

Validate agent workspace, add to openclaw.json config, and restart gateway.

Arguments:
  <id>              Agent identifier

Options:
  --add-to <id>     Also add this agent to another agent's allowAgents list
  --model <model>   Override model (default: from pending config or openai-codex/gpt-5.4)
  --dry-run         Show what would change without writing
  --no-restart      Write config but don't restart gateway
  --help            Show this help

Examples:
  clawforge activate scout                     # Activate with pending config
  clawforge activate scout --add-to main       # Also allow main to spawn scout
  clawforge activate scout --dry-run           # Preview changes
EOF
}

AGENT_ID=""
ADD_TO=""
MODEL_OVERRIDE=""
DRY_RUN=false
NO_RESTART=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --add-to)      ADD_TO="$2"; shift 2 ;;
    --model)       MODEL_OVERRIDE="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --no-restart)  NO_RESTART=true; shift ;;
    --help|-h)     usage; exit 0 ;;
    -*)            log_error "Unknown option: $1"; usage; exit 1 ;;
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

if [[ -z "$AGENT_ID" ]]; then
  log_error "Agent ID is required"
  usage
  exit 1
fi

_require_jq

# ── Check if already active ───────────────────────────────────────────
if _agent_exists_in_config "$AGENT_ID"; then
  log_warn "Agent '$AGENT_ID' is already in config"
  echo "Use 'clawforge inspect $AGENT_ID' to view current configuration."
  exit 0
fi

# ── Validate workspace ────────────────────────────────────────────────
workspace=$(_get_workspace "$AGENT_ID")
if [[ ! -d "$workspace" ]]; then
  log_error "Workspace not found: $workspace"
  echo "Run 'clawforge create $AGENT_ID' first."
  exit 1
fi

# Check required files
missing_files=()
for f in SOUL.md AGENTS.md; do
  if [[ ! -f "${workspace}/${f}" ]]; then
    missing_files+=("$f")
  fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
  log_error "Missing required workspace files: ${missing_files[*]}"
  echo "These files must exist before activation."
  exit 1
fi

# ── Load pending config or build new ──────────────────────────────────
pending_file="${workspace}/.clawforge/pending-config.json"
if [[ -f "$pending_file" ]]; then
  agent_entry=$(cat "$pending_file")
  log_debug "Loaded pending config from $pending_file"
else
  # Build minimal config entry
  agent_entry=$(jq -n \
    --arg id "$AGENT_ID" \
    --arg name "$(echo "${AGENT_ID:0:1}" | tr '[:lower:]' '[:upper:]')${AGENT_ID:1}" \
    --arg workspace "$workspace" \
    --arg model "${MODEL_OVERRIDE:-openai-codex/gpt-5.4}" \
    '{
      id: $id,
      name: $name,
      workspace: $workspace,
      model: $model,
      subagents: { allowAgents: ["main"] }
    }')
fi

# Apply model override if specified
if [[ -n "$MODEL_OVERRIDE" ]]; then
  agent_entry=$(echo "$agent_entry" | jq --arg m "$MODEL_OVERRIDE" '.model = $m')
fi

# ── Build new config ──────────────────────────────────────────────────
config=$(_read_openclaw_config) || exit 1

# Add agent to agents.list
new_config=$(echo "$config" | jq --argjson entry "$agent_entry" '.agents.list += [$entry]')

# Add to another agent's allowAgents if specified
if [[ -n "$ADD_TO" ]]; then
  # Verify target agent exists
  if ! echo "$new_config" | jq -e --arg id "$ADD_TO" '.agents.list[] | select(.id == $id)' &>/dev/null; then
    log_error "Target agent '$ADD_TO' not found in config"
    exit 1
  fi
  new_config=$(echo "$new_config" | jq --arg target "$ADD_TO" --arg new_id "$AGENT_ID" '
    .agents.list = [.agents.list[] | 
      if .id == $target then
        .subagents.allowAgents = ((.subagents.allowAgents // []) + [$new_id] | unique)
      else . end
    ]')
fi

# ── Dry run ────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo ""
  echo "🔨 Dry run — activate ${AGENT_ID}"
  echo ""
  echo "Would add agent entry:"
  echo "$agent_entry" | jq '.'
  echo ""
  if [[ -n "$ADD_TO" ]]; then
    echo "Would add '$AGENT_ID' to ${ADD_TO}'s allowAgents"
  fi
  echo ""
  echo "Config diff: +1 agent in agents.list"
  echo "Would restart gateway: $(if $NO_RESTART; then echo "no (--no-restart)"; else echo "yes"; fi)"
  exit 0
fi

# ── Write config ──────────────────────────────────────────────────────
_write_openclaw_config "$new_config"

# Clean up pending config
if [[ -f "$pending_file" ]]; then
  rm "$pending_file"
  rmdir "${workspace}/.clawforge" 2>/dev/null || true
  log_debug "Removed pending config"
fi

echo ""
echo "✅ Agent '${AGENT_ID}' added to config"
if [[ -n "$ADD_TO" ]]; then
  echo "✅ Added to ${ADD_TO}'s allowAgents"
fi

# ── Restart gateway ───────────────────────────────────────────────────
if ! $NO_RESTART; then
  echo ""
  echo "🔄 Restarting gateway..."
  if command -v openclaw &>/dev/null; then
    openclaw gateway restart 2>&1 || log_warn "Gateway restart failed — restart manually with 'openclaw gateway restart'"
    echo "✅ Gateway restarted"
  else
    log_warn "openclaw CLI not found — restart gateway manually"
  fi
fi

echo ""
echo "Done. Run 'clawforge inspect ${AGENT_ID}' to verify."
