#!/usr/bin/env bash
# config.sh — Manage ClawForge user configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
Usage: clawforge config <subcommand> [args]

Manage user configuration at ~/.clawforge/config.json.
User config overrides project defaults.

Subcommands:
  show                 Show all config (user + defaults)
  get <key>            Get a config value
  set <key> <value>    Set a config value
  unset <key>          Remove a config key
  init                 Create default user config with common settings
  path                 Show config file path
  --help               Show this help

Common config keys:
  default_agent        Default agent: claude or codex
  default_model_claude Default Claude model
  default_model_codex  Default Codex model
  auto_clean           Auto-clean on completion (true/false)
  default_timeout      Default timeout in minutes
  max_agents           Default max parallel agents for swarm
  routing              Default routing strategy (auto/cheap/quality)
  review_models        Comma-separated models for multi-model review
  disk_warn_gb         Disk space warning threshold
  disk_error_gb        Disk space error threshold

Examples:
  clawforge config show
  clawforge config set default_agent claude
  clawforge config set auto_clean true
  clawforge config set default_timeout 30
  clawforge config set review_models "claude-sonnet-4-5,gpt-5.2-codex,claude-opus-4"
  clawforge config init
EOF
}

[[ $# -eq 0 ]] && { usage; exit 0; }

case "$1" in
  show)
    config_list
    ;;
  get)
    [[ -z "${2:-}" ]] && { log_error "Key required"; exit 1; }
    val=$(config_get "$2" "")
    if [[ -n "$val" ]]; then
      echo "$val"
    else
      echo "(not set)"
      exit 1
    fi
    ;;
  set)
    [[ -z "${2:-}" || -z "${3:-}" ]] && { log_error "Key and value required"; exit 1; }
    config_set "$2" "$3"
    echo "Set $2 = $3"
    ;;
  unset)
    [[ -z "${2:-}" ]] && { log_error "Key required"; exit 1; }
    mkdir -p "$(dirname "$USER_CONFIG_FILE")"
    if [[ -f "$USER_CONFIG_FILE" ]]; then
      tmp=$(mktemp)
      jq --arg k "$2" 'del(.[$k])' "$USER_CONFIG_FILE" > "$tmp" && mv "$tmp" "$USER_CONFIG_FILE"
      echo "Unset $2"
    fi
    ;;
  init)
    mkdir -p "$(dirname "$USER_CONFIG_FILE")"
    if [[ -f "$USER_CONFIG_FILE" ]]; then
      echo "Config already exists at $USER_CONFIG_FILE"
      echo "Use 'clawforge config set' to modify individual values."
      exit 0
    fi
    cat > "$USER_CONFIG_FILE" << 'INITJSON'
{
  "default_agent": "claude",
  "default_model_claude": "claude-sonnet-4-5",
  "default_model_codex": "gpt-5.3-codex",
  "auto_clean": "false",
  "default_timeout": "",
  "max_agents": "3",
  "routing": "",
  "review_models": "claude-sonnet-4-5,gpt-5.2-codex",
  "disk_warn_gb": "5",
  "disk_error_gb": "1"
}
INITJSON
    echo "Created config at $USER_CONFIG_FILE"
    echo "Edit with: clawforge config set <key> <value>"
    ;;
  path)
    echo "$USER_CONFIG_FILE"
    ;;
  --help|-h)
    usage
    ;;
  *)
    log_error "Unknown subcommand: $1"
    usage
    exit 1
    ;;
esac
