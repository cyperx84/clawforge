# Troubleshooting

## `clawforge` command not found
- Ensure install path is on `$PATH` (`~/.local/bin` for source installs)
- Run `clawforge version`

## No agents detected
- Install/configure `claude` and/or `codex`
- Verify with `which claude` / `which codex`

## tmux attach fails
- Check session exists: `tmux list-sessions`
- Task may have already completed/stopped

## Dashboard won’t open
- Try `clawforge dashboard --no-anim`
- Ensure terminal supports alt-screen

## History empty
- History entries are written when tasks are cleaned/archived
- Run `clawforge clean --all-done` then check `clawforge history`

## Eval summary says no entries
- First log a run with `clawforge eval log ...`
- Check `clawforge eval paths`
