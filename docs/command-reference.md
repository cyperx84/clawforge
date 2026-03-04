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

### config (v1.2)
```bash
clawforge config show                          # Show all config
clawforge config get default_agent             # Get single value
clawforge config set default_agent claude      # Set value
clawforge config set auto_clean true           # Enable auto-clean by default
clawforge config set default_timeout 30        # 30-min timeout by default
clawforge config set review_models "claude-sonnet-4-5,gpt-5.2-codex,claude-opus-4"
clawforge config unset default_timeout         # Remove a key
clawforge config init                          # Create default config
clawforge config path                          # Show config file location
```

### multi-review (v1.2)
```bash
clawforge multi-review --pr 42                                    # Review with default models
clawforge multi-review --pr 42 --models "sonnet,opus,codex"       # Custom model list
clawforge multi-review --pr 42 --output /tmp/reviews              # Save reviews
clawforge multi-review --pr 42 --diff-only                        # Show disagreements only
clawforge multi-review --pr 42 --json                             # JSON output
clawforge multi-review --pr 42 --dry-run                          # Preview
```

### summary (v1.2)
```bash
clawforge summary 1                           # Markdown summary of what agent did
clawforge summary 1 --format json             # JSON output
clawforge summary 1 --format text             # Plain text
clawforge summary 1 --include-diff            # Include diff stats
clawforge summary 1 --save /tmp/summary.md    # Save to file
clawforge summary 1 --model claude-opus-4     # Use specific model
```

### parse-cost (v1.2)
```bash
clawforge parse-cost 1                        # Parse cost from agent output
clawforge parse-cost all                      # Parse all running agents
clawforge parse-cost all --update             # Parse + write to costs.jsonl
clawforge parse-cost 1 --json                 # JSON output
clawforge parse-cost 1 --lines 500            # Scan more output lines
```

### profile (v1.3)
```bash
clawforge profile list                                           # List all profiles
clawforge profile create fast --agent claude --model haiku --timeout 5  # Create profile
clawforge profile show fast                                      # Show profile details
clawforge profile use fast                                       # Print spawn flags
clawforge profile delete fast                                    # Delete profile
clawforge sprint --repo . --task "fix" $(clawforge profile use fast)    # Use in sprint
```

### replay (v1.3)
```bash
clawforge replay 1                           # Replay task #1
clawforge replay 1 --model claude-opus-4     # Replay with different model
clawforge replay 1 --dry-run                 # Preview
```

### export (v1.3)
```bash
clawforge export                             # Full markdown report
clawforge export --format json               # JSON dump
clawforge export --status done --save report.md  # Filtered + saved
clawforge export --since 2026-03-01          # Date range
```

### completions (v1.3)
```bash
clawforge completions bash                   # Install bash completions
clawforge completions zsh                    # Install zsh completions
clawforge completions fish                   # Install fish completions
```

### Task Dependencies (v1.3)
```bash
clawforge sprint --repo . --task "run tests" --after 1   # Run after task #1 completes
```
