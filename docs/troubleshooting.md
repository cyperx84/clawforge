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

## Diagnosing issues with `clawforge doctor` (v0.7+)

Run `clawforge doctor` to check for:
- Orphaned tmux sessions
- Dangling worktrees from completed tasks
- Stale registry entries (running > 7 days)
- Registry integrity (valid JSON, no duplicate IDs)
- Merged branches not cleaned up
- Low disk space

Use `clawforge doctor --fix` to auto-remediate.

## Swarm spawn failures

If swarm agents are failing to spawn:
1. Check disk space (`clawforge doctor`)
2. Check if the coding agent CLI is available (`which claude` / `which codex`)
3. Check tmux session limits
4. Look at spawn failure count in `clawforge status` output
5. The decomposition step has a configurable timeout (`decompose_timeout_minutes` in config, default 2 min) — if the model hangs, swarm falls back to generic task splitting

## Slow builds from swarm

Common causes:
- Too many agents for available RAM (`--max-agents` caps this)
- Decomposition call timing out (check model availability)
- Worktrees accumulating on disk (`clawforge clean --stale-days 3`)
