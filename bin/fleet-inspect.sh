#!/usr/bin/env bash
# fleet-inspect.sh — Deep view of a single agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/fleet-common.sh"
source "${SCRIPT_DIR}/../lib/clwatch-bridge.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge inspect <id> [options]

Deep view of an agent's configuration, bindings, and workspace.

Arguments:
  <id>       Agent identifier

Options:
  --json     Machine-readable JSON output
  --help     Show this help
EOF
}

AGENT_ID=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)    JSON_OUTPUT=true; shift ;;
    --help|-h) usage; exit 0 ;;
    -*)        log_error "Unknown option: $1"; usage; exit 1 ;;
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

# ── Gather agent data ─────────────────────────────────────────────────
agent=$(_get_agent "$AGENT_ID" 2>/dev/null) || true
workspace=$(_get_workspace "$AGENT_ID")
status=$(_validate_agent "$AGENT_ID")

# Check for pending config (created but not activated)
pending_config=""
if [[ -f "${workspace}/.clawforge/pending-config.json" ]]; then
  pending_config=$(cat "${workspace}/.clawforge/pending-config.json")
fi

# Use agent config or pending config
if [[ -z "$agent" || "$agent" == "null" ]]; then
  if [[ -n "$pending_config" ]]; then
    agent="$pending_config"
    status="created"
  else
    if [[ -d "$workspace" ]]; then
      # Workspace exists but no config at all
      agent=$(jq -n --arg id "$AGENT_ID" --arg ws "$workspace" '{id: $id, name: $id, workspace: $ws, model: "unknown"}')
      status="created"
    else
      log_error "Agent '$AGENT_ID' not found in config or workspace"
      exit 1
    fi
  fi
fi

agent_name=$(echo "$agent" | jq -r '.name // .id')
model_primary=$(_get_model_primary "$agent")
model_display=$(_resolve_model_display "$model_primary")
fallbacks=$(_get_model_fallbacks "$agent")
fallbacks_display=$(echo "$fallbacks" | jq -r 'if length > 0 then map(split("/") | last) | join(", ") else "none" end')
subagent_allow=$(echo "$agent" | jq -r '.subagents.allowAgents // [] | join(", ")')
[[ -z "$subagent_allow" ]] && subagent_allow="none"

# Skills
skills=$(echo "$agent" | jq -r '.skills // "all (no filter)"')
[[ "$skills" == "null" ]] && skills="all (no filter)"

# Heartbeat
heartbeat_info="empty (no periodic tasks)"
if [[ -f "${workspace}/HEARTBEAT.md" ]]; then
  hb_content=$(cat "${workspace}/HEARTBEAT.md" 2>/dev/null || true)
  hb_tasks=$(echo "$hb_content" | grep -c '^- ' 2>/dev/null || echo 0)
  hb_tasks="${hb_tasks//[^0-9]/}"
  hb_tasks="${hb_tasks:-0}"
  if [[ "$hb_tasks" -gt 0 ]]; then
    heartbeat_info="${hb_tasks} task(s) configured"
  fi
fi

# Bindings
bindings=$(_get_bindings "$AGENT_ID" 2>/dev/null) || bindings="[]"
binding_count=$(echo "$bindings" | jq 'length')
binding_display="none"
if [[ "$binding_count" -gt 0 ]]; then
  binding=$(echo "$bindings" | jq '.[0]')
  channel_type=$(echo "$binding" | jq -r '.match.channel // "unknown"')
  channel_id=$(echo "$binding" | jq -r '.match.peer.id // "unknown"')
  mention_req=$(echo "$binding" | jq -r '.match.mention // "not required"')
  binding_display="${channel_type} #${AGENT_ID} (${channel_id})"
fi

# Workspace files
file_details="[]"
for f in "${AGENT_FILES[@]}"; do
  filepath="${workspace}/${f}"
  fstatus=$(_workspace_file_status "$filepath")
  ficon=$(_file_status_icon "$fstatus")
  fsize="0"
  fsize_display="—"
  if [[ -f "$filepath" ]]; then
    fsize=$(wc -c < "$filepath" | tr -d ' ')
    fsize_display=$(_human_size "$fsize")
  fi
  file_details=$(echo "$file_details" | jq --arg name "$f" --arg status "$fstatus" --arg icon "$ficon" --arg size "$fsize_display" --argjson bytes "${fsize:-0}" \
    '. + [{name: $name, status: $status, icon: $icon, size: $size, bytes: $bytes}]')
done

# Memory & references
memory_count=$(_count_memory_files "$workspace")
ref_count=$(_count_reference_files "$workspace")

# ── JSON output ────────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  clwatch_info="{}"
  if _has_clwatch; then
    compat=$(_get_model_compat "$model_primary" 2>/dev/null || echo "{}")
    deps=$(_get_deprecations "$model_primary" 2>/dev/null || echo "[]")
    clwatch_info=$(jq -n --argjson compat "$compat" --argjson deps "$deps" '{available: true, compat: $compat, deprecations: $deps}')
  fi

  jq -n \
    --argjson agent "$agent" \
    --arg status "$status" \
    --arg model_display "$model_display" \
    --arg fallbacks_display "$fallbacks_display" \
    --arg subagents "$subagent_allow" \
    --arg skills "$skills" \
    --arg heartbeat "$heartbeat_info" \
    --arg binding "$binding_display" \
    --argjson files "$file_details" \
    --argjson memory_count "$memory_count" \
    --argjson ref_count "$ref_count" \
    --argjson clwatch "$clwatch_info" \
    '{
      agent: $agent,
      status: $status,
      model_display: $model_display,
      fallbacks: $fallbacks_display,
      subagents: $subagents,
      skills: $skills,
      heartbeat: $heartbeat,
      binding: $binding,
      files: $files,
      memory_count: $memory_count,
      reference_count: $ref_count,
      clwatch: $clwatch
    }'
  exit 0
fi

# ── Pretty output ─────────────────────────────────────────────────────
agent_emoji=$(echo "$agent" | jq -r '.emoji // ""')
echo ""
echo "${agent_emoji:+${agent_emoji} }${agent_name}"
echo ""

# Config section
echo " Config"
echo " ──────────────────────────────────"
printf " %-15s %s\n" "ID:" "$AGENT_ID"
printf " %-15s %s\n" "Model:" "${model_display} (${model_primary})"
printf " %-15s %s\n" "Fallbacks:" "$fallbacks_display"
printf " %-15s %s\n" "Workspace:" "$workspace"
printf " %-15s %s\n" "Can spawn:" "$subagent_allow"
printf " %-15s %s\n" "Skills:" "$skills"
printf " %-15s %s\n" "Heartbeat:" "$heartbeat_info"
printf " %-15s %s\n" "Status:" "$(_status_icon "$status") $status"

# Binding section
echo ""
echo " Binding"
echo " ──────────────────────────────────"
if [[ "$binding_count" -gt 0 ]]; then
  printf " %-15s %s\n" "Channel:" "$binding_display"
  printf " %-15s %s\n" "Mention:" "${mention_req:-not required}"
else
  echo " No bindings configured"
fi

# Workspace files section
echo ""
echo " Workspace Files"
echo " ──────────────────────────────────"
echo "$file_details" | jq -r '.[] | " \(.icon)  \(.name)\t\(.size)"' | column -t -s $'\t' | sed 's/^/ /'

echo ""
printf " %-15s %s daily logs\n" "Memory files:" "$memory_count"
printf " %-15s %s context docs\n" "References:" "$ref_count"

# clwatch section (optional)
if _has_clwatch; then
  echo ""
  echo " clwatch"
  echo " ──────────────────────────────────"
  compat_display=$(_get_model_compat_display "$model_primary" 2>/dev/null || echo "unknown")
  dep_display=$(_get_deprecation_display "$model_primary" 2>/dev/null || echo "none")
  printf " %-15s %s\n" "Model compat:" "${compat_display:-unknown}"
  printf " %-15s %s\n" "Deprecations:" "$dep_display"
fi

echo ""
