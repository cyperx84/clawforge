# Architecture

ClawForge orchestrates coding agents through shell modules, registry state, and tmux sessions.

## High-Level Diagram

```text
User/CI
  │
  ▼
clawforge (bin/clawforge router)
  │
  ├─ Workflow modes: sprint / review / swarm
  ├─ Fleet ops: memory / init / history
  ├─ Observability: dashboard / cost / conflicts / eval
  ▼
Module scripts (bin/*.sh)
  │
  ├─ registry/active-tasks.json
  ├─ registry/completed-tasks.jsonl
  ├─ registry/costs.jsonl
  ├─ registry/conflicts.jsonl
  ▼
External systems
  ├─ tmux sessions
  ├─ git worktrees
  ├─ gh CLI (PR/CI)
  └─ coding agents (claude/codex)
```

## Runtime data flow

1. Command invoked (`sprint`, `swarm`, etc.)
2. Task recorded to active registry
3. Agent spawned in tmux + worktree
4. Monitoring/CI/cost/conflict updates written to registry files
5. Clean/archive moves run into completed history
6. Eval loop records outcomes in `evals/run-log.jsonl`

## Go Dashboard internals

- Bubble Tea v2 + Lipgloss v2
- Alternate screen + diff rendering (no full screen clear loops)
- Reads registry + tmux session state
- Keybindings: `j/k`, `Enter`, `s`, `x`, `/`, `?`, `q`

## Design principles

- Atomic shell modules with clear responsibilities
- JSON/JSONL append-friendly state
- Human override always available (`steer`, `stop`, `attach`)
- Practical over clever: minimal moving parts first
