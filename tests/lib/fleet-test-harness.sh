#!/usr/bin/env bash
# fleet-test-harness.sh — Reusable test harness for fleet integration tests
# Provides isolated temp environment for safe fleet command testing

set -euo pipefail

# ── Harness State ───────────────────────────────────────────────────────
_FLEET_HARNESS_ACTIVE=false
_FLEET_HARNESS_TEMP_DIRS=()

# ── Main Harness Functions ───────────────────────────────────────────────

# Initialize isolated test environment
# Creates temp config, workspace, and agents dirs
# Exports env vars so fleet scripts use temp paths
fleet_harness_init() {
  if $_FLEET_HARNESS_ACTIVE; then
    echo "ERROR: Harness already initialized" >&2
    return 1
  fi

  # Create temp directories
  local config_dir workspace_dir agents_dir
  
  config_dir=$(mktemp -d)
  workspace_dir=$(mktemp -d)
  agents_dir=$(mktemp -d)
  
  _FLEET_HARNESS_TEMP_DIRS+=("$config_dir" "$workspace_dir" "$agents_dir")
  
  # Export paths for fleet scripts
  export OPENCLAW_CONFIG="${config_dir}/openclaw.json"
  export OPENCLAW_WORKSPACE="$workspace_dir"
  export OPENCLAW_AGENTS_DIR="$agents_dir"
  
  # Skip gateway restart in tests
  export CLAWFORGE_SKIP_RESTART=1
  
  # Seed minimal valid openclaw.json
  _seed_minimal_config
  
  # Seed minimal USER.md in workspace
  _seed_user_template
  
  _FLEET_HARNESS_ACTIVE=true
  
  echo "✓ Fleet test harness initialized"
  echo "  Config:   $OPENCLAW_CONFIG"
  echo "  Workspace: $OPENCLAW_WORKSPACE"
  echo "  Agents:    $OPENCLAW_AGENTS_DIR"
}

# Cleanup temp directories
fleet_harness_cleanup() {
  if ! $_FLEET_HARNESS_ACTIVE; then
    return 0
  fi
  
  for dir in "${_FLEET_HARNESS_TEMP_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      rm -rf "$dir"
    fi
  done
  
  _FLEET_HARNESS_TEMP_DIRS=()
  _FLEET_HARNESS_ACTIVE=false
  
  # Unset exported vars
  unset OPENCLAW_CONFIG
  unset OPENCLAW_WORKSPACE
  unset OPENCLAW_AGENTS_DIR
  unset CLAWFORGE_SKIP_RESTART
  
  echo "✓ Fleet test harness cleaned up"
}

# Auto-cleanup on exit
fleet_harness_auto_cleanup() {
  trap fleet_harness_cleanup EXIT
}

# ── Config Helpers ───────────────────────────────────────────────────────

# Seed minimal valid openclaw.json
_seed_minimal_config() {
  cat > "$OPENCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "list": [
      {
        "id": "main",
        "name": "Main",
        "workspace": null,
        "model": "openai-codex/gpt-5.4",
        "subagents": {
          "allowAgents": []
        }
      }
    ]
  },
  "bindings": [],
  "routing": {
    "defaultAgent": "main"
  }
}
EOF
}

# Seed minimal USER.md template
_seed_user_template() {
  mkdir -p "$OPENCLAW_WORKSPACE"
  cat > "${OPENCLAW_WORKSPACE}/USER.md" <<'EOF'
# USER.md - About Your Human

- **Name:** Test User
- **What to call them:** Test
- **Timezone:** UTC

## Context

Test environment for fleet integration tests.
EOF
}

# Read current config as JSON
fleet_harness_read_config() {
  if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    echo "ERROR: Config not found at $OPENCLAW_CONFIG" >&2
    return 1
  fi
  cat "$OPENCLAW_CONFIG"
}

# Check if agent exists in config
fleet_harness_agent_in_config() {
  local agent_id="$1"
  local config
  config=$(fleet_harness_read_config) || return 1
  
  echo "$config" | jq -e --arg id "$agent_id" '.agents.list[] | select(.id == $id)' >/dev/null 2>&1
}

# Check if agent is in another agent's allowAgents
fleet_harness_agent_in_allowagents() {
  local agent_id="$1"
  local target_agent="$2"
  local config
  config=$(fleet_harness_read_config) || return 1
  
  echo "$config" | jq -e --arg target "$target_agent" --arg id "$agent_id" \
    '.agents.list[] | select(.id == $target) | .subagents.allowAgents[]? | select(. == $id)' >/dev/null 2>&1
}

# Get binding count for agent
fleet_harness_binding_count() {
  local agent_id="$1"
  local config
  config=$(fleet_harness_read_config) || return 1
  
  echo "$config" | jq --arg id "$agent_id" '[.bindings[]? | select(.agentId == $id)] | length'
}

# Check if binding exists
fleet_harness_binding_exists() {
  local agent_id="$1"
  local channel_id="$2"
  local config
  config=$(fleet_harness_read_config) || return 1
  
  echo "$config" | jq -e --arg aid "$agent_id" --arg cid "$channel_id" \
    '.bindings[]? | select(.agentId == $aid and .channelId == $cid)' >/dev/null 2>&1
}

# Count agents in config
fleet_harness_agent_count() {
  local config
  config=$(fleet_harness_read_config) || return 1
  echo "$config" | jq '.agents.list | length'
}

# ── Workspace Helpers ───────────────────────────────────────────────────

# Check if workspace directory exists
fleet_harness_workspace_exists() {
  local agent_id="$1"
  local ws_path="${OPENCLAW_AGENTS_DIR}/${agent_id}"
  [[ -d "$ws_path" ]]
}

# Check if workspace file exists
fleet_harness_workspace_file_exists() {
  local agent_id="$1"
  local filename="$2"
  local filepath="${OPENCLAW_AGENTS_DIR}/${agent_id}/${filename}"
  [[ -f "$filepath" ]]
}

# Check if workspace file contains text
fleet_harness_workspace_file_contains() {
  local agent_id="$1"
  local filename="$2"
  local expected="$3"
  local filepath="${OPENCLAW_AGENTS_DIR}/${agent_id}/${filename}"
  
  [[ -f "$filepath" ]] && grep -q "$expected" "$filepath"
}

# Check if workspace file does NOT contain placeholder
fleet_harness_workspace_file_no_placeholder() {
  local agent_id="$1"
  local filename="$2"
  local placeholder="$3"
  local filepath="${OPENCLAW_AGENTS_DIR}/${agent_id}/${filename}"
  
  [[ -f "$filepath" ]] && ! grep -q "$placeholder" "$filepath"
}

# ── Assertion Helpers ───────────────────────────────────────────────────

# Standard assertion functions for tests
# These follow the pattern from existing test files

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc"
    ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc"
    ((FAIL++)) || true
  fi
}

assert_equals() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected', got '$actual')"
    ((FAIL++)) || true
  fi
}

assert_file_exists() {
  local desc="$1" filepath="$2"
  if [[ -f "$filepath" ]]; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (missing: $filepath)"
    ((FAIL++)) || true
  fi
}

assert_dir_exists() {
  local desc="$1" dirpath="$2"
  if [[ -d "$dirpath" ]]; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (missing: $dirpath)"
    ((FAIL++)) || true
  fi
}

assert_file_contains() {
  local desc="$1" filepath="$2" expected="$3"
  if [[ -f "$filepath" ]] && grep -q "$expected" "$filepath"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in $filepath)"
    ((FAIL++)) || true
  fi
}

assert_file_not_contains() {
  local desc="$1" filepath="$2" unexpected="$3"
  if [[ -f "$filepath" ]] && ! grep -q "$unexpected" "$filepath"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (unexpected '$unexpected' in $filepath)"
    ((FAIL++)) || true
  fi
}

assert_config_unchanged() {
  local desc="$1"
  local backup_file="${OPENCLAW_CONFIG}.assert_backup"
  
  if [[ ! -f "$backup_file" ]]; then
    echo "  ⚠️  $desc (no backup to compare)"
    return
  fi
  
  if diff -q "$backup_file" "$OPENCLAW_CONFIG" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (config was modified)"
    ((FAIL++)) || true
  fi
}

# Backup config for comparison
backup_config() {
  cp "$OPENCLAW_CONFIG" "${OPENCLAW_CONFIG}.assert_backup"
}

# ── Utility Functions ───────────────────────────────────────────────────

# Get path to fleet script
fleet_script() {
  local name="$1"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "${script_dir}/../bin/${name}"
}

# Get path to clawforge CLI
clawforge_cli() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "${script_dir}/../bin/clawforge"
}
