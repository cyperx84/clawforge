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
