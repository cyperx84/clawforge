# ClawForge TUI — Go + Bubble Tea Rewrite

## Goal
Replace the bash dashboard.sh with a flicker-free Go TUI using Bubble Tea v2 + Lipgloss v2 + Bubbles.

## Architecture
- Single Go binary: `clawforge-dashboard`
- Lives in `tui/` directory within the clawforge repo
- Reads data from clawforge registry (JSON files) + tmux + git

## Data Sources
- `registry/active-tasks.json` — task list with id, mode, status, branch, description
- `registry/costs.jsonl` — per-task cost data (inputTokens, outputTokens, totalCost)
- `registry/conflicts.jsonl` — conflict records
- `tmux list-sessions -F "#{session_name} #{session_activity}"` — live session status
- `git -C <worktree> log --oneline -1` — last commit per agent

## File Structure
```
tui/
├── main.go           # Entry point, tea.NewProgram
├── model.go          # Model struct, Init, Update, View
├── animation.go      # Forge startup animation frames + logic
├── dashboard.go      # Main dashboard view rendering
├── agent.go          # Agent data structures + loading from registry
├── keybindings.go    # Key handling + help overlay
├── styles.go         # Lipgloss styles (amber/orange forge theme)
├── steer.go          # Steer input modal
├── filter.go         # Filter input handling
└── go.mod
```

## Phase 1: Animation (animation.go + styles.go)
- 8-10 frames of ASCII forge art with hammering/sparks effect
- Amber/orange color scheme via Lipgloss (colors: #FF8C00, #FF6600, #FFA500, #CC5500)
- Frame cycle: 120ms per frame, ~1.5 seconds total
- Transition: fade last frame → dashboard view
- tea.Tick for frame timing
- --no-anim flag skips directly to dashboard

## Phase 2: Dashboard View (dashboard.go + agent.go)
- Header: "ClawForge Dashboard" with forge emoji + version
- Agent table columns:
  | ID | Mode | Status | Branch | Task (truncated) | Cost | CI | Conflicts |
- Selected row highlighted with reverse video + amber accent
- Status indicators: 🟢 running, 🟡 idle, 🔴 failed, ⚪ done
- Cost column: "$X.XX" or "-" if no cost data
- CI column: ✅/❌/⏳/- 
- Conflicts column: count or "-"
- Footer status bar: "4 agents | 2 running | $3.42 total | ↑↓ navigate | ? help"
- Auto-refresh: tea.Tick every 2 seconds triggers data reload
- Only re-renders changed cells (Bubble Tea handles this automatically)

## Phase 3: Vim Keybindings (keybindings.go)
- j/k or ↑/↓: navigate agent list
- Enter: attach to selected agent's tmux session (tea.ExecProcess)
- s: open steer input modal
- x: stop selected agent (confirm with y/n)
- q or Ctrl+C: quit
- /: open filter input
- r: force refresh
- ?: toggle help overlay
- g: go to top
- G: go to bottom
- Esc: close any modal/overlay

## Phase 4: Steer Modal (steer.go)
- When 's' pressed: show text input at bottom
- Prompt: "Steer agent #X: "
- Enter submits: runs `clawforge steer <id> "<message>"`
- Esc cancels
- Use Bubbles textinput component

## Phase 5: Filter (filter.go)
- When '/' pressed: show filter input at top
- Filters agent list by any column match (fuzzy)
- Esc clears filter
- Live filtering as you type

## Phase 6: Help Overlay (keybindings.go)
- Semi-transparent overlay listing all keybindings
- Dismiss with ? or Esc
- Styled with Lipgloss border + padding

## Performance Requirements
- Zero flicker (Bubble Tea cell-based diff handles this)
- Startup to dashboard: < 500ms (excluding animation)
- Data refresh: < 100ms (shell out to tmux/git in background)
- Smooth animation: consistent 120ms frame timing
- Handle terminal resize gracefully (tea.WindowSizeMsg)

## Build
- `go build -o bin/clawforge-dashboard ./tui/`
- Update `bin/clawforge` to prefer Go binary when available
- Keep dashboard.sh as fallback

## Styling (Lipgloss)
- Primary: #FF8C00 (dark orange / amber)
- Secondary: #FFA500 (orange)
- Accent: #FF6600 (red-orange)
- Muted: #CC5500 (brown-orange)
- Background: terminal default (transparent)
- Selected row: reverse + amber foreground
- Header: bold + amber
- Status bar: dim + muted
- Borders: rounded, amber
