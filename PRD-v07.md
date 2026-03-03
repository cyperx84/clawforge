# ClawForge v0.7 PRD — Reliability

Keep it atomic. Each feature is a surgical fix.

## Repo: ~/.openclaw/workspace/clawforge
## Branch: feat/v07-reliability

## Feature 1: Auto-clean on completion (--auto-clean flag)

Add --auto-clean flag to sprint.sh and swarm.sh.
When set, after a task completes (status=done), automatically run clean logic:
- Kill tmux session
- Remove worktree
- Archive in registry
- Append to completed-tasks.jsonl
Implementation: at the end of sprint/swarm flow, if --auto-clean is set and status is done, call clean.sh --task-id <id>.
Also add config default: auto_clean (bool) in config/defaults.json.

## Feature 2: Signal trap cleanup

Add trap handlers in sprint.sh and swarm.sh for SIGINT SIGTERM EXIT.
On trap:
- Mark task as "cancelled" in registry
- Kill spawned tmux session if running
- Remove worktree if --auto-clean was set
- Print "Interrupted. Task <id> cancelled."
Use a cleanup function. Set trap before spawning agent. Unset after clean completion.

## Feature 3: Agent watchdog timeout (--timeout flag)

Add --timeout <minutes> flag to sprint.sh and swarm.sh.
Implementation:
- After spawning agent, start a background timer: sleep $((timeout*60)) && clawforge stop <id> --yes
- Store timer PID, kill it if task completes before timeout
- On timeout: mark task as "timeout" in registry, kill tmux, log warning
- Default: no timeout (backwards compatible)

## Feature 4: Registry file locking

Add flock-based locking around all registry writes in lib/common.sh.
Create a lock file at registry/.lock.
Wrap registry_add, registry_update, registry_remove with:
  (flock -w 5 200 || { log_error "Registry lock timeout"; return 1; }) 200>"$LOCK_FILE"
This prevents concurrent swarm agents from corrupting active-tasks.json.

## Feature 5: clawforge doctor

New file: bin/doctor.sh
Checks and optionally fixes:
1. Orphaned tmux sessions (sessions matching clawforge patterns not in registry)
2. Dangling worktrees (worktree dirs referenced in registry but task is done/archived)
3. Stale registry entries (tasks older than 7 days still marked running)
4. Disk usage (warn if < 5GB free)
5. Registry integrity (valid JSON, no duplicate IDs)
6. Merged branches not cleaned up

Output format:
- Each check: OK or WARN or ERROR with description
- --fix flag: auto-fix what it can (kill orphan sessions, remove dangling worktrees, archive stale tasks, delete merged branches)
- --json flag for structured output

## Feature 6: Registry pruning

Add --prune-days <n> to clean.sh.
Removes archived tasks from active-tasks.json that are older than N days.
Also add auto-prune in config/defaults.json: prune_after_days (default: 30).
Sprint/swarm can call this at startup to keep registry lean.

## Feature 7: Branch cleanup

Modify clean.sh: after removing worktree, also delete the git branch if it was merged.
Check: git branch --merged main | grep <branch_name>
If merged, delete: git branch -d <branch_name>
If not merged, leave it (safety).
Add --keep-branch flag to skip branch deletion.

## Feature 8: Disk space check

Add disk_check() to lib/common.sh.
Before spawning agents in sprint.sh and swarm.sh:
- Check available disk: df -k . | awk 'NR==2{print $4}'
- Warn if < 5GB free
- Error and abort if < 1GB free (unless --force)
- Configurable thresholds in config/defaults.json: disk_warn_gb, disk_error_gb

## Feature 9: --timeout flag on CLI

Add --timeout <minutes> flag to sprint.sh and swarm.sh help text and parsing.
Wire to Feature 3 watchdog implementation.

## Testing
- Create tests/test-reliability.sh covering:
  - auto-clean flag parsing
  - signal trap behavior (spawn + interrupt)
  - timeout flag parsing
  - flock presence in common.sh
  - doctor command output
  - registry pruning
  - branch cleanup logic
  - disk check function
- Add to run-all-tests.sh

## Version
- Bump VERSION to 0.7.0
- Update README briefly
- Update docs/troubleshooting.md with doctor command
