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

## View modes (v0.8)

Switch between filtered views:

| Key | View | Shows |
|-----|------|-------|
| `1` | All | Every agent in registry |
| `2` | Running | Only `running` / `spawned` agents |
| `3` | Finished | Only `done` / `failed` / `cancelled` / `timeout` / `archived` |
| `Tab` | Cycle | Rotates through all → running → finished |

The active view is shown in the header and status bar.

## Nudge (v0.8)

Press `n` on a running agent to send a quick progress nudge ("share current progress, blockers, and ETA"). This uses `clawforge steer` under the hood — useful for checking on stuck agents without typing a custom steer message.
