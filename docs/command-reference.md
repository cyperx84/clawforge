# Command Reference

## Management

### status
Show tracked tasks.
```bash
clawforge status
```

### attach
Attach to tmux session for a running task.
```bash
clawforge attach 1
clawforge attach 3.2
```

### steer
Send instruction to running task.
```bash
clawforge steer 1 "Use bcrypt instead of md5"
```

### stop
Stop running task.
```bash
clawforge stop 1 --yes
```

### watch
Health monitor and optional daemon mode.
```bash
clawforge watch --daemon
```

### dashboard
Live Go TUI dashboard.
```bash
clawforge dashboard
clawforge dashboard --no-anim
```

## Observability

### cost
```bash
clawforge cost --summary
clawforge cost <task-id>
clawforge cost --capture <id>
```

### conflicts
```bash
clawforge conflicts
clawforge conflicts --check
clawforge conflicts --resolve
```

### templates
```bash
clawforge templates
clawforge templates show migration
clawforge templates new my-template
```

## Fleet Ops

### memory
```bash
clawforge memory
clawforge memory show
clawforge memory add "Run prisma generate after schema changes"
clawforge memory search prisma
clawforge memory forget --id <id>
clawforge memory clear
```

### init
```bash
clawforge init
clawforge init --claude-md
```

### history
```bash
clawforge history
clawforge history --mode swarm --limit 5
clawforge history --repo api
```

### eval (v0.6.2)
```bash
clawforge eval log --command sprint --mode quick --repo api --status ok --duration-ms 420000
clawforge eval weekly
clawforge eval compare --week-a 2026-09 --week-b 2026-10
clawforge eval paths
```

### doctor (v0.7)
```bash
clawforge doctor                    # Diagnose orphans, stale tasks, disk, branches
clawforge doctor --fix              # Auto-fix issues found
clawforge doctor --json             # Structured output
```

### logs (v0.9)
```bash
clawforge logs 1                    # Last 50 lines from agent tmux pane
clawforge logs 1 --lines 100       # More context
clawforge logs 1 --follow           # Live stream (Ctrl+C to stop)
clawforge logs 1 --save /tmp/out.log  # Dump to file
clawforge logs 1 --raw              # Keep ANSI escape codes
```

### on-complete (v0.9)
```bash
clawforge on-complete 1             # Fire completion hooks for task #1
clawforge on-complete 1 --dry-run   # Preview what would fire
```

### clean (enhanced v0.7)
```bash
clawforge clean --task-id <id>      # Clean specific task
clawforge clean --all-done          # Clean all done tasks
clawforge clean --stale-days 7      # Clean old tasks
clawforge clean --prune-days 14     # Remove archived entries from registry
clawforge clean --all-done --keep-branch  # Skip branch deletion
```

### Workflow flags (v0.7+)
```bash
clawforge sprint "Task" --auto-clean          # Auto-cleanup on finish
clawforge sprint "Task" --timeout 30          # Kill agent after 30 minutes
clawforge swarm "Task" --auto-clean --timeout 60  # Both on swarm
```

### Dashboard keybindings (v0.8+)
```
1/2/3      View: all / running / finished
Tab        Cycle views
n          Nudge selected running agent
p          Toggle output preview pane
j/k        Navigate
Enter      Attach to tmux session
s          Steer agent
x          Stop agent (with confirm)
/          Filter
r          Force refresh
?          Help overlay
q          Quit
```
