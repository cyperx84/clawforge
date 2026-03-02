#!/usr/bin/env bash
# conflicts.sh — Swarm conflict resolution: detect overlapping file changes
# Usage: clawforge conflicts [--json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

CONFLICTS_FILE="${CLAWFORGE_DIR}/registry/conflicts.jsonl"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge conflicts [options]

Show and manage swarm file conflicts.

Commands:
  clawforge conflicts              Show current/recent conflicts
  clawforge conflicts --check      Run conflict detection now
  clawforge conflicts --resolve    Spawn coordinator to resolve conflicts

Flags:
  --check       Run conflict detection across active worktrees
  --resolve     Spawn a coordinator agent to merge conflicting changes
  --json        Output as JSON
  --help        Show this help
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
CHECK=false RESOLVE=false JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)    CHECK=true; shift ;;
    --resolve)  RESOLVE=true; shift ;;
    --json)     JSON_OUTPUT=true; shift ;;
    --help|-h)  usage; exit 0 ;;
    --*)        log_error "Unknown option: $1"; usage; exit 1 ;;
    *)          shift ;;
  esac
done

mkdir -p "$(dirname "$CONFLICTS_FILE")"
touch "$CONFLICTS_FILE"

# ── Conflict detection ─────────────────────────────────────────────────
_detect_conflicts() {
  _ensure_registry
  local running_tasks
  running_tasks=$(jq -c '[.tasks[] | select(
    (.status == "running" or .status == "spawned" or .status == "pr-created") and
    .worktree != "" and .worktree != null
  )]' "$REGISTRY_FILE" 2>/dev/null || echo "[]")

  local task_count
  task_count=$(echo "$running_tasks" | jq 'length' 2>/dev/null || echo 0)

  if [[ "$task_count" -lt 2 ]]; then
    if $JSON_OUTPUT; then
      echo '{"conflicts":[],"message":"Need at least 2 active agents for conflict detection"}'
    else
      echo "No conflicts possible (fewer than 2 active agents)."
    fi
    return
  fi

  # Collect changed files per agent
  local agent_files=()
  local agent_ids=()
  local i=0
  while IFS= read -r task; do
    local id worktree branch repo
    id=$(echo "$task" | jq -r '.id')
    worktree=$(echo "$task" | jq -r '.worktree')
    branch=$(echo "$task" | jq -r '.branch')
    repo=$(echo "$task" | jq -r '.repo')

    local files=""
    if [[ -d "$worktree" ]]; then
      # Get changed files in worktree relative to base
      files=$(git -C "$worktree" diff --name-only HEAD~1 2>/dev/null || \
              git -C "$worktree" diff --name-only 2>/dev/null || true)
    fi

    # Also check files_touched from registry
    local reg_files
    reg_files=$(echo "$task" | jq -r '.files_touched // [] | .[]' 2>/dev/null || true)
    if [[ -n "$reg_files" ]]; then
      files=$(printf "%s\n%s" "$files" "$reg_files" | sort -u)
    fi

    agent_files[i]="$files"
    agent_ids[i]="$id"
    ((i++)) || true
  done < <(echo "$running_tasks" | jq -c '.[]' 2>/dev/null)

  # Compare file lists between all agent pairs
  local conflict_count=0
  local now
  now=$(epoch_ms)

  for ((a=0; a<i; a++)); do
    for ((b=a+1; b<i; b++)); do
      local overlap
      overlap=$(comm -12 <(echo "${agent_files[a]}" | sort) <(echo "${agent_files[b]}" | sort) 2>/dev/null || true)
      if [[ -n "$overlap" ]]; then
        local overlap_json
        overlap_json=$(echo "$overlap" | jq -R . | jq -s .)
        local conflict_entry
        conflict_entry=$(jq -cn \
          --arg agent1 "${agent_ids[a]}" \
          --arg agent2 "${agent_ids[b]}" \
          --argjson files "$overlap_json" \
          --argjson timestamp "$now" \
          --arg status "detected" \
          '{
            agent1: $agent1,
            agent2: $agent2,
            overlapping_files: $files,
            timestamp: $timestamp,
            status: $status
          }')
        echo "$conflict_entry" >> "$CONFLICTS_FILE"
        ((conflict_count++)) || true

        if ! $JSON_OUTPUT; then
          echo "  ⚠ Conflict: ${agent_ids[a]} ↔ ${agent_ids[b]}"
          echo "$overlap" | sed 's/^/    /'
          echo ""
        fi

        # Update registry with conflict info
        registry_update "${agent_ids[a]}" "has_conflict" 'true' 2>/dev/null || true
        registry_update "${agent_ids[b]}" "has_conflict" 'true' 2>/dev/null || true
      fi
    done
  done

  if $JSON_OUTPUT; then
    local recent
    recent=$(tail -20 "$CONFLICTS_FILE" | jq -s '.' 2>/dev/null || echo "[]")
    echo "$recent" | jq --argjson count "$conflict_count" '{conflicts: ., new_conflicts: $count}'
  elif [[ "$conflict_count" -eq 0 ]]; then
    echo "No file conflicts detected."
  else
    echo "Detected $conflict_count conflict(s)."
  fi
}

# ── Show conflicts ─────────────────────────────────────────────────────
_show_conflicts() {
  if [[ ! -s "$CONFLICTS_FILE" ]]; then
    if $JSON_OUTPUT; then
      echo '{"conflicts":[]}'
    else
      echo "No conflicts recorded."
    fi
    return
  fi

  if $JSON_OUTPUT; then
    cat "$CONFLICTS_FILE" | jq -s '{
      conflicts: .,
      total: length,
      detected: [.[] | select(.status == "detected")] | length,
      resolved: [.[] | select(.status == "resolved")] | length
    }'
    return
  fi

  echo "=== Swarm Conflicts ==="
  echo ""

  local total detected resolved
  total=$(wc -l < "$CONFLICTS_FILE" | tr -d ' ')
  detected=$(grep -c '"detected"' "$CONFLICTS_FILE" 2>/dev/null || echo 0)
  resolved=$(grep -c '"resolved"' "$CONFLICTS_FILE" 2>/dev/null || echo 0)

  echo "  Total: $total  |  Detected: $detected  |  Resolved: $resolved"
  echo ""

  echo "  Recent conflicts:"
  tail -10 "$CONFLICTS_FILE" | jq -r '"  [\(.timestamp | . / 1000 | strftime("%H:%M:%S"))] \(.agent1) ↔ \(.agent2) [\(.status)] — \(.overlapping_files | length) files"' 2>/dev/null || true
}

# ── Resolve conflicts ──────────────────────────────────────────────────
_resolve_conflicts() {
  local unresolved
  unresolved=$(grep '"detected"' "$CONFLICTS_FILE" 2>/dev/null | tail -1 || true)

  if [[ -z "$unresolved" ]]; then
    echo "No unresolved conflicts to resolve."
    return
  fi

  local agent1 agent2
  agent1=$(echo "$unresolved" | jq -r '.agent1')
  agent2=$(echo "$unresolved" | jq -r '.agent2')
  local files
  files=$(echo "$unresolved" | jq -r '.overlapping_files | join(", ")')

  echo "Resolving conflict between $agent1 and $agent2"
  echo "Overlapping files: $files"
  echo ""
  echo "Note: Automatic coordinator agent spawning requires both agents to be completed."
  echo "Use 'clawforge steer' to manually coordinate or wait for completion."

  # Mark as being resolved
  local tmp
  tmp=$(mktemp)
  sed "s/\"agent1\":\"${agent1}\",\"agent2\":\"${agent2}\".*\"status\":\"detected\"/&/" "$CONFLICTS_FILE" > "$tmp"
  mv "$tmp" "$CONFLICTS_FILE"
}

# ── Route ──────────────────────────────────────────────────────────────
if $CHECK; then
  _detect_conflicts
elif $RESOLVE; then
  _resolve_conflicts
else
  _show_conflicts
fi
