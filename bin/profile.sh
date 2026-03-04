#!/usr/bin/env bash
# profile.sh — Manage reusable agent profiles
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

PROFILES_DIR="${HOME}/.clawforge/profiles"

usage() {
  cat <<EOF
Usage: clawforge profile <subcommand> [args]

Manage reusable agent profiles (saved parameter presets).

Subcommands:
  list                     List all profiles
  show <name>              Show profile details
  create <name> [options]  Create a new profile
  delete <name>            Delete a profile
  use <name>               Print spawn flags for a profile
  --help                   Show this help

Create options:
  --agent <name>           Agent: claude or codex
  --model <model>          Model to use
  --effort <level>         Effort: high, medium, low
  --timeout <minutes>      Timeout in minutes
  --auto-clean             Enable auto-clean
  --notify                 Enable notifications
  --routing <strategy>     Routing: auto, cheap, quality

Examples:
  clawforge profile create fast --agent claude --model claude-haiku-3.5 --timeout 5
  clawforge profile create quality --agent claude --model claude-opus-4 --effort high --notify
  clawforge profile create cheap --agent codex --model gpt-5.2-codex --routing cheap
  clawforge profile use fast
  clawforge sprint --repo . --task "fix bug" $(clawforge profile use fast)
EOF
}

[[ $# -eq 0 ]] && { usage; exit 0; }

mkdir -p "$PROFILES_DIR"

case "$1" in
  list)
    echo "── Agent Profiles ──"
    if [[ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]]; then
      echo "(none — create with: clawforge profile create <name>)"
      exit 0
    fi
    for f in "$PROFILES_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f" .json)
      agent=$(jq -r '.agent // "—"' "$f")
      model=$(jq -r '.model // "—"' "$f")
      printf "  %-15s agent=%-8s model=%s\n" "$name" "$agent" "$model"
    done
    ;;

  show)
    [[ -z "${2:-}" ]] && { log_error "Profile name required"; exit 1; }
    PROFILE_FILE="$PROFILES_DIR/$2.json"
    [[ -f "$PROFILE_FILE" ]] || { log_error "Profile '$2' not found"; exit 1; }
    echo "── Profile: $2 ──"
    jq '.' "$PROFILE_FILE"
    ;;

  create)
    shift
    [[ -z "${1:-}" ]] && { log_error "Profile name required"; exit 1; }
    PROFILE_NAME="$1"; shift

    AGENT="" MODEL="" EFFORT="" TIMEOUT="" AUTO_CLEAN=false NOTIFY=false ROUTING=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --agent)      AGENT="$2"; shift 2 ;;
        --model)      MODEL="$2"; shift 2 ;;
        --effort)     EFFORT="$2"; shift 2 ;;
        --timeout)    TIMEOUT="$2"; shift 2 ;;
        --auto-clean) AUTO_CLEAN=true; shift ;;
        --notify)     NOTIFY=true; shift ;;
        --routing)    ROUTING="$2"; shift 2 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
      esac
    done

    PROFILE_FILE="$PROFILES_DIR/${PROFILE_NAME}.json"
    jq -cn \
      --arg agent "$AGENT" \
      --arg model "$MODEL" \
      --arg effort "$EFFORT" \
      --arg timeout "$TIMEOUT" \
      --argjson autoClean "$AUTO_CLEAN" \
      --argjson notify "$NOTIFY" \
      --arg routing "$ROUTING" \
      '{agent:$agent,model:$model,effort:$effort,timeout:$timeout,autoClean:$autoClean,notify:$notify,routing:$routing} | with_entries(select(.value != "" and .value != null))' \
      > "$PROFILE_FILE"

    echo "Created profile '$PROFILE_NAME' at $PROFILE_FILE"
    jq '.' "$PROFILE_FILE"
    ;;

  delete)
    [[ -z "${2:-}" ]] && { log_error "Profile name required"; exit 1; }
    PROFILE_FILE="$PROFILES_DIR/$2.json"
    [[ -f "$PROFILE_FILE" ]] || { log_error "Profile '$2' not found"; exit 1; }
    rm "$PROFILE_FILE"
    echo "Deleted profile '$2'"
    ;;

  use)
    [[ -z "${2:-}" ]] && { log_error "Profile name required"; exit 1; }
    PROFILE_FILE="$PROFILES_DIR/$2.json"
    [[ -f "$PROFILE_FILE" ]] || { log_error "Profile '$2' not found"; exit 1; }

    FLAGS=""
    agent=$(jq -r '.agent // empty' "$PROFILE_FILE")
    model=$(jq -r '.model // empty' "$PROFILE_FILE")
    effort=$(jq -r '.effort // empty' "$PROFILE_FILE")
    timeout=$(jq -r '.timeout // empty' "$PROFILE_FILE")
    auto_clean=$(jq -r '.autoClean // false' "$PROFILE_FILE")
    notify=$(jq -r '.notify // false' "$PROFILE_FILE")

    [[ -n "$agent" ]] && FLAGS+="--agent $agent "
    [[ -n "$model" ]] && FLAGS+="--model $model "
    [[ -n "$effort" ]] && FLAGS+="--effort $effort "
    [[ -n "$timeout" ]] && FLAGS+="--timeout $timeout "
    [[ "$auto_clean" == "true" ]] && FLAGS+="--auto-clean "
    [[ "$notify" == "true" ]] && FLAGS+="--notify "

    echo "$FLAGS"
    ;;

  --help|-h) usage ;;
  *) log_error "Unknown subcommand: $1"; usage; exit 1 ;;
esac
