# Workflow Modes

## sprint
Single-agent full dev cycle.

```bash
clawforge sprint "Add JWT authentication middleware"
clawforge sprint "Fix typo" --quick
clawforge sprint --routing auto "Refactor auth service"
```

Key flags:
- `--quick`
- `--branch <name>`
- `--agent <claude|codex>`
- `--model <model>`
- `--routing <auto|cheap|quality>`
- `--template <name>`
- `--ci-loop`
- `--max-ci-retries <N>`
- `--budget <dollars>`
- `--json`, `--notify`, `--webhook`

## review
Quality gate against an existing PR.

```bash
clawforge review --pr 42
clawforge review --pr 42 --fix
```

## swarm
Parallel multi-agent orchestration.

```bash
clawforge swarm "Migrate tests to vitest"
clawforge swarm --max-agents 4 "Add i18n"
clawforge swarm --repos ~/api,~/web,~/shared "Upgrade auth v2 to v3"
```

Key flags:
- `--repos <paths>`
- `--repos-file <file>`
- `--routing <auto|cheap|quality>`
- `--max-agents <N>`
- `--template <name>`
- `--ci-loop`, `--max-ci-retries`
- `--budget`, `--json`, `--notify`, `--webhook`

## Reliability flags (v0.7+)

All workflow modes support:

| Flag | Description |
|------|-------------|
| `--auto-clean` | Automatically clean worktree + tmux session when task completes |
| `--timeout <min>` | Kill agent after N minutes (watchdog) |

These work on both `sprint` and `swarm`.

## Completion hooks (v0.9)

When a task finishes, `on-complete` can fire:
1. OpenClaw event notification (if `--notify` was set)
2. Webhook POST (if `--webhook` was set)
3. Auto-clean (if `--auto-clean` was set)

Use `clawforge on-complete <id>` manually or let `watch --daemon` trigger it.
