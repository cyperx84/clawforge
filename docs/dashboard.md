# Dashboard (Go TUI)

`clawforge dashboard` opens a flicker-free Bubble Tea dashboard.

## Keybindings
- `j` / `k`: move selection
- `Enter`: attach to selected tmux session
- `s`: steer selected agent
- `x`: stop selected agent
- `/`: filter
- `r`: refresh
- `?`: help overlay
- `q`: quit

## Columns
- ID
- Mode
- Status
- Repo
- Model
- Branch
- Task
- Cost
- CI
- Conflicts

## Notes
- Uses alt screen and diff rendering (no full-screen blinking)
- Supports startup animation (`--no-anim` disables)
