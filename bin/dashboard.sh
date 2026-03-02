#!/usr/bin/env bash
# dashboard.sh — Live TUI dashboard with vim keybindings and forge animation
# Usage: clawforge dashboard [--no-anim]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: clawforge dashboard [options]

Live terminal UI for monitoring all ClawForge agents.

Options:
  --no-anim    Skip startup animation
  --help       Show this help

Keybindings:
  j/k          Navigate agent list
  Enter        Attach to selected agent's tmux session
  s            Steer selected agent (prompts for message)
  x            Stop selected agent
  /            Filter agents
  r            Force refresh
  ?            Show help overlay
  q            Quit dashboard
EOF
}

# ── Parse args ─────────────────────────────────────────────────────────
SKIP_ANIM=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-anim) SKIP_ANIM=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --*)       log_error "Unknown option: $1"; usage; exit 1 ;;
    *)         shift ;;
  esac
done

# ── Terminal setup ─────────────────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)
SELECTED=0
FILTER=""
SHOW_HELP=false
REFRESH_INTERVAL=2

# Amber/orange forge colors via tput
COLOR_RESET=$(tput sgr0 2>/dev/null || echo "")
COLOR_AMBER=$(tput setaf 208 2>/dev/null || tput setaf 3 2>/dev/null || echo "")
COLOR_ORANGE=$(tput setaf 166 2>/dev/null || tput setaf 1 2>/dev/null || echo "")
COLOR_DIM=$(tput dim 2>/dev/null || echo "")
COLOR_BOLD=$(tput bold 2>/dev/null || echo "")
COLOR_REV=$(tput rev 2>/dev/null || echo "")
COLOR_GREEN=$(tput setaf 2 2>/dev/null || echo "")
COLOR_RED=$(tput setaf 1 2>/dev/null || echo "")
COLOR_YELLOW=$(tput setaf 3 2>/dev/null || echo "")
COLOR_CYAN=$(tput setaf 6 2>/dev/null || echo "")

# ── Forge ASCII art frames ────────────────────────────────────────────
FORGE_FRAME_1() {
  cat <<'ART'
          ╔═══════════════════════════════╗
          ║         ClawForge             ║
          ╚═══════════════════════════════╝

              _______________
             /               \
            /   ███████████   \
           │   ███████████████ │
           │   ████  ▓▓  █████│
           │   ███████████████ │
            \   ███████████   /
             \_____     _____/
                   │   │
              ═════╧═══╧═════
             /  ░░░░░░░░░░░░  \
            /_________________  \
           ╔═══════════════════╗
           ║  ▒▒▒▒▒▒▒▒▒▒▒▒▒  ║
           ╚═══════════════════╝
ART
}

FORGE_FRAME_2() {
  cat <<'ART'
          ╔═══════════════════════════════╗
          ║        ClawForge  ⚒          ║
          ╚═══════════════════════════════╝

              _______________
             /               \
            /   ▓▓▓▓▓▓▓▓▓▓▓   \
           │   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
           │   ▓▓▓▓  ██  ▓▓▓▓▓│
           │   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
            \   ▓▓▓▓▓▓▓▓▓▓▓   /
             \_____     _____/
                   │ ⚡│
              ═════╧═══╧═════
             /  ▓▓▓▓▓▓▓▓▓▓▓▓  \
            /_________________  \
           ╔═══════════════════╗
           ║  ████████████████ ║
           ╚═══════════════════╝
ART
}

FORGE_FRAME_3() {
  cat <<'ART'
          ╔═══════════════════════════════╗
          ║      ClawForge  ⚒  ⚒        ║
          ╚═══════════════════════════════╝
                    *  *  *
              _______________
             /    * * * *    \
            /   ████████████   \
           │   █████████████████│
           │   █████  ░░  ██████│
           │   █████████████████│
            \   ████████████   /
             \_____     _____/
                   │⚡⚡│
              ═════╧═══╧═════
             /  ████████████████\
            /_________________  \
           ╔═══════════════════╗
           ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
           ╚═══════════════════╝
ART
}

# ── Startup animation ─────────────────────────────────────────────────
_forge_animation() {
  tput civis 2>/dev/null || true  # hide cursor
  local frames=("1" "2" "3" "2" "3" "1" "3" "2")
  for frame in "${frames[@]}"; do
    tput clear 2>/dev/null || clear
    echo ""
    echo "${COLOR_AMBER}"
    case "$frame" in
      1) FORGE_FRAME_1 ;;
      2) FORGE_FRAME_2 ;;
      3) FORGE_FRAME_3 ;;
    esac
    echo "${COLOR_RESET}"
    sleep 0.2
  done
  # Final flash
  tput clear 2>/dev/null || clear
  echo ""
  echo "${COLOR_ORANGE}${COLOR_BOLD}"
  FORGE_FRAME_3
  echo "${COLOR_RESET}"
  sleep 0.4
}

# ── Data fetching ──────────────────────────────────────────────────────
TASK_DATA="[]"
TASK_COUNT=0

_refresh_data() {
  _ensure_registry
  TASK_DATA=$(jq '.tasks' "$REGISTRY_FILE" 2>/dev/null || echo "[]")

  # Apply filter
  if [[ -n "$FILTER" ]]; then
    TASK_DATA=$(echo "$TASK_DATA" | jq --arg f "$FILTER" \
      '[.[] | select(
        (.id | ascii_downcase | contains($f | ascii_downcase)) or
        (.description // "" | ascii_downcase | contains($f | ascii_downcase)) or
        (.mode // "" | ascii_downcase | contains($f | ascii_downcase)) or
        (.status // "" | ascii_downcase | contains($f | ascii_downcase))
      )]' 2>/dev/null || echo "$TASK_DATA")
  fi

  TASK_COUNT=$(echo "$TASK_DATA" | jq 'length' 2>/dev/null || echo 0)

  # Clamp selection
  if [[ "$TASK_COUNT" -gt 0 ]]; then
    if [[ "$SELECTED" -ge "$TASK_COUNT" ]]; then
      SELECTED=$((TASK_COUNT - 1))
    fi
    [[ "$SELECTED" -lt 0 ]] && SELECTED=0
  else
    SELECTED=0
  fi
}

# ── Cost data ──────────────────────────────────────────────────────────
_get_task_cost() {
  local task_id="$1"
  local costs_file="${CLAWFORGE_DIR}/registry/costs.jsonl"
  if [[ -f "$costs_file" ]]; then
    grep "\"taskId\":\"${task_id}\"" "$costs_file" 2>/dev/null | tail -1 | jq -r '.totalCost // 0' 2>/dev/null || echo "—"
  else
    echo "—"
  fi
}

# ── Conflict data ──────────────────────────────────────────────────────
_get_conflict_count() {
  local conflicts_file="${CLAWFORGE_DIR}/registry/conflicts.jsonl"
  if [[ -f "$conflicts_file" ]]; then
    wc -l < "$conflicts_file" 2>/dev/null | tr -d ' '
  else
    echo "0"
  fi
}

# ── Render functions ───────────────────────────────────────────────────
_render_header() {
  local ver
  ver=$(cat "${CLAWFORGE_DIR}/VERSION" 2>/dev/null || echo "?")
  echo "${COLOR_AMBER}${COLOR_BOLD}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  printf "${COLOR_AMBER}${COLOR_BOLD}║${COLOR_RESET}  ${COLOR_ORANGE}${COLOR_BOLD}ClawForge Dashboard${COLOR_RESET}  ${COLOR_DIM}v${ver}${COLOR_RESET}"
  # Right-align timestamp
  local ts
  ts=$(date +"%H:%M:%S")
  local pad=$((72 - 22 - ${#ver} - ${#ts}))
  printf "%*s" "$pad" ""
  printf "${COLOR_DIM}${ts}${COLOR_RESET}  ${COLOR_AMBER}${COLOR_BOLD}║${COLOR_RESET}\n"
  echo "${COLOR_AMBER}${COLOR_BOLD}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

_render_status_bar() {
  local running=0 spawned=0 done_count=0 failed=0
  running=$(echo "$TASK_DATA" | jq '[.[] | select(.status == "running")] | length' 2>/dev/null || echo 0)
  spawned=$(echo "$TASK_DATA" | jq '[.[] | select(.status == "spawned")] | length' 2>/dev/null || echo 0)
  done_count=$(echo "$TASK_DATA" | jq '[.[] | select(.status == "done")] | length' 2>/dev/null || echo 0)
  failed=$(echo "$TASK_DATA" | jq '[.[] | select(.status == "failed")] | length' 2>/dev/null || echo 0)
  local conflicts
  conflicts=$(_get_conflict_count)

  printf "  ${COLOR_GREEN}●${COLOR_RESET} Running: ${running}  "
  printf "${COLOR_YELLOW}○${COLOR_RESET} Spawned: ${spawned}  "
  printf "${COLOR_CYAN}✓${COLOR_RESET} Done: ${done_count}  "
  printf "${COLOR_RED}✗${COLOR_RESET} Failed: ${failed}"
  if [[ "$conflicts" -gt 0 ]]; then
    printf "  ${COLOR_RED}${COLOR_BOLD}⚠ Conflicts: ${conflicts}${COLOR_RESET}"
  fi
  if [[ -n "$FILTER" ]]; then
    printf "  ${COLOR_DIM}Filter: ${FILTER}${COLOR_RESET}"
  fi
  echo ""
}

_status_color() {
  case "$1" in
    running)    echo "${COLOR_GREEN}" ;;
    spawned)    echo "${COLOR_YELLOW}" ;;
    pr-created) echo "${COLOR_CYAN}" ;;
    ci-passing) echo "${COLOR_GREEN}" ;;
    done)       echo "${COLOR_DIM}" ;;
    failed)     echo "${COLOR_RED}" ;;
    stopped)    echo "${COLOR_RED}" ;;
    *)          echo "" ;;
  esac
}

_render_table() {
  echo ""
  # Table header
  printf "  ${COLOR_DIM}%-5s %-8s %-12s %-12s %-30s %-10s %-8s${COLOR_RESET}\n" \
    "ID" "Mode" "Status" "Branch" "Description" "Cost" "CI"
  printf "  ${COLOR_DIM}%-5s %-8s %-12s %-12s %-30s %-10s %-8s${COLOR_RESET}\n" \
    "─────" "────────" "────────────" "────────────" "──────────────────────────────" "──────────" "────────"

  if [[ "$TASK_COUNT" -eq 0 ]]; then
    echo ""
    echo "  ${COLOR_DIM}No active tasks.${COLOR_RESET}"
    echo "  ${COLOR_DIM}Start one: clawforge sprint \"<task>\"${COLOR_RESET}"
    return
  fi

  local i=0
  while IFS= read -r task_line; do
    local id mode status branch desc cost ci_status
    id=$(echo "$task_line" | jq -r 'if .short_id then "#\(.short_id)" else .id[0:8] end' 2>/dev/null)
    mode=$(echo "$task_line" | jq -r '.mode // "—"' 2>/dev/null)
    status=$(echo "$task_line" | jq -r '.status // "?"' 2>/dev/null)
    branch=$(echo "$task_line" | jq -r '.branch // "" | split("/") | last | .[0:12]' 2>/dev/null)
    desc=$(echo "$task_line" | jq -r '.description // "" | .[0:30]' 2>/dev/null)
    local task_id
    task_id=$(echo "$task_line" | jq -r '.id' 2>/dev/null)
    cost=$(_get_task_cost "$task_id")
    ci_status=$(echo "$task_line" | jq -r 'if .ci_retries and .ci_retries > 0 then "retry/\(.ci_retries)" else "—" end' 2>/dev/null)

    local sc
    sc=$(_status_color "$status")
    if [[ "$i" -eq "$SELECTED" ]]; then
      printf "  ${COLOR_REV}${COLOR_BOLD}%-5s %-8s ${sc}%-12s${COLOR_RESET}${COLOR_REV} %-12s %-30s %-10s %-8s${COLOR_RESET}\n" \
        "$id" "$mode" "$status" "$branch" "$desc" "$cost" "$ci_status"
    else
      printf "  %-5s %-8s ${sc}%-12s${COLOR_RESET} %-12s %-30s %-10s %-8s\n" \
        "$id" "$mode" "$status" "$branch" "$desc" "$cost" "$ci_status"
    fi
    ((i++)) || true
  done < <(echo "$TASK_DATA" | jq -c '.[]' 2>/dev/null)
}

_render_system_info() {
  echo ""
  echo "  ${COLOR_DIM}── System ──────────────────────────────────────────────────────────${COLOR_RESET}"
  local tmux_count
  tmux_count=$(tmux list-sessions 2>/dev/null | grep -c "agent" 2>/dev/null || echo "0")
  local daemon_status="off"
  local pid_file="${CLAWFORGE_DIR}/watch.pid"
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    daemon_status="${COLOR_GREEN}on${COLOR_RESET}"
  fi
  printf "  tmux agents: %s  │  watch daemon: %s  │  tasks: %s\n" \
    "${tmux_count:-0}" "$daemon_status" "$TASK_COUNT"
}

_render_help_overlay() {
  echo ""
  echo "  ${COLOR_AMBER}${COLOR_BOLD}╔═══════════════════════════╗${COLOR_RESET}"
  echo "  ${COLOR_AMBER}${COLOR_BOLD}║     Dashboard Help        ║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}${COLOR_BOLD}╠═══════════════════════════╣${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  j/k     Navigate up/down ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  Enter   Attach to agent  ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  s       Steer agent      ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  x       Stop agent       ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  /       Filter agents    ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  r       Force refresh    ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  ?       Toggle this help ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}║${COLOR_RESET}  q       Quit             ${COLOR_AMBER}║${COLOR_RESET}"
  echo "  ${COLOR_AMBER}${COLOR_BOLD}╚═══════════════════════════╝${COLOR_RESET}"
}

_render_footer() {
  echo ""
  echo "  ${COLOR_DIM}[j/k] navigate  [Enter] attach  [s] steer  [x] stop  [/] filter  [?] help  [q] quit${COLOR_RESET}"
}

# ── Full render ────────────────────────────────────────────────────────
_render() {
  tput cup 0 0 2>/dev/null || true
  tput ed 2>/dev/null || true   # clear to end of screen
  _render_header
  _render_status_bar
  _render_table
  if $SHOW_HELP; then
    _render_help_overlay
  fi
  _render_system_info
  _render_footer
}

# ── Selected task helpers ──────────────────────────────────────────────
_selected_task_id() {
  if [[ "$TASK_COUNT" -eq 0 ]]; then
    echo ""
    return
  fi
  echo "$TASK_DATA" | jq -r ".[$SELECTED].id // empty" 2>/dev/null || echo ""
}

_selected_short_id() {
  if [[ "$TASK_COUNT" -eq 0 ]]; then
    echo ""
    return
  fi
  echo "$TASK_DATA" | jq -r ".[$SELECTED].short_id // empty" 2>/dev/null || echo ""
}

_selected_tmux_session() {
  if [[ "$TASK_COUNT" -eq 0 ]]; then
    echo ""
    return
  fi
  echo "$TASK_DATA" | jq -r ".[$SELECTED].tmuxSession // empty" 2>/dev/null || echo ""
}

# ── Action handlers ────────────────────────────────────────────────────
_action_attach() {
  local session
  session=$(_selected_tmux_session)
  if [[ -n "$session" ]] && tmux has-session -t "$session" 2>/dev/null; then
    # Restore terminal before attaching
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    stty echo 2>/dev/null || true
    tmux attach-session -t "$session"
    # Re-enter alt screen after detach
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    stty -echo 2>/dev/null || true
  fi
}

_action_steer() {
  local sid
  sid=$(_selected_short_id)
  if [[ -z "$sid" ]]; then return; fi

  # Restore terminal for input
  tput cnorm 2>/dev/null || true
  stty echo 2>/dev/null || true
  tput cup $((ROWS - 2)) 0 2>/dev/null || true
  tput el 2>/dev/null || true
  printf "  Steer #${sid}: "
  local msg
  read -r msg
  stty -echo 2>/dev/null || true
  tput civis 2>/dev/null || true

  if [[ -n "$msg" ]]; then
    "${SCRIPT_DIR}/steer.sh" "$sid" "$msg" 2>/dev/null || true
  fi
}

_action_stop() {
  local sid
  sid=$(_selected_short_id)
  if [[ -z "$sid" ]]; then return; fi

  tput cnorm 2>/dev/null || true
  stty echo 2>/dev/null || true
  tput cup $((ROWS - 2)) 0 2>/dev/null || true
  tput el 2>/dev/null || true
  printf "  Stop #${sid}? [y/N]: "
  local confirm
  read -r -n 1 confirm
  stty -echo 2>/dev/null || true
  tput civis 2>/dev/null || true

  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    "${SCRIPT_DIR}/stop.sh" "$sid" --yes 2>/dev/null || true
    _refresh_data
  fi
}

_action_filter() {
  tput cnorm 2>/dev/null || true
  stty echo 2>/dev/null || true
  tput cup $((ROWS - 2)) 0 2>/dev/null || true
  tput el 2>/dev/null || true
  printf "  Filter: "
  local f
  read -r f
  stty -echo 2>/dev/null || true
  tput civis 2>/dev/null || true
  FILTER="$f"
  SELECTED=0
  _refresh_data
}

# ── Static (non-interactive) dashboard ─────────────────────────────────
_static_dashboard() {
  _refresh_data
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                   ClawForge Dashboard                       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "── Active Tasks ──────────────────────────────────────────────"
  if [[ "$TASK_COUNT" -eq 0 ]]; then
    echo "  No active tasks."
  else
    echo "$TASK_DATA" | jq -r '.[] |
      def sid: if .short_id then "#\(.short_id)" else .id end;
      def mode: .mode // "—";
      "  \(sid)  \(mode)  [\(.status // "unknown")]  \(.description // "no description")[0:55]"
    ' 2>/dev/null || echo "  (error reading tasks)"
  fi
  echo ""
  echo "  Tip: Run in a terminal for interactive TUI with vim keybindings"
}

# ── Terminal cleanup ───────────────────────────────────────────────────
_cleanup() {
  tput cnorm 2>/dev/null || true    # show cursor
  tput rmcup 2>/dev/null || true    # exit alt screen
  stty echo 2>/dev/null || true     # restore echo
  echo ""
}

# ── Main ───────────────────────────────────────────────────────────────

# Non-interactive: print static dashboard and exit
if [[ ! -t 1 ]]; then
  _static_dashboard
  exit 0
fi

trap _cleanup EXIT INT TERM

# Run startup animation
if ! $SKIP_ANIM; then
  _forge_animation
fi

# Enter alt screen buffer
tput smcup 2>/dev/null || true
tput civis 2>/dev/null || true   # hide cursor
stty -echo 2>/dev/null || true   # disable echo

# Initial data load
_refresh_data

# Main loop
LAST_REFRESH=$(date +%s)
while true; do
  _render

  # Non-blocking read with timeout for auto-refresh
  if read -t "$REFRESH_INTERVAL" -n 1 key 2>/dev/null; then
    case "$key" in
      q)
        break
        ;;
      j)
        if [[ "$TASK_COUNT" -gt 0 && "$SELECTED" -lt $((TASK_COUNT - 1)) ]]; then
          SELECTED=$((SELECTED + 1))
        fi
        ;;
      k)
        if [[ "$SELECTED" -gt 0 ]]; then
          SELECTED=$((SELECTED - 1))
        fi
        ;;
      "")  # Enter key
        _action_attach
        ;;
      s)
        _action_steer
        ;;
      x)
        _action_stop
        ;;
      /)
        _action_filter
        ;;
      r)
        _refresh_data
        ;;
      "?")
        if $SHOW_HELP; then
          SHOW_HELP=false
        else
          SHOW_HELP=true
        fi
        ;;
    esac
  fi

  # Auto-refresh data
  NOW_TS=$(date +%s)
  if [[ $((NOW_TS - LAST_REFRESH)) -ge "$REFRESH_INTERVAL" ]]; then
    _refresh_data
    LAST_REFRESH=$NOW_TS
  fi
done
