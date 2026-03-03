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
