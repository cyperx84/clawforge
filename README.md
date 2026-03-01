# 🔨 ClawForge

Agent swarm workflow for OpenClaw — spawn, monitor, review, and manage coding agents (Claude Code, Codex) on git worktrees with tmux sessions.

## Inspired By

This project was inspired by [Elvis's "OpenClaw + Codex/Claude Code Agent Swarm" workflow](https://x.com/elvissun/article/2025920521871716562) — a battle-tested system for managing a fleet of AI coding agents.

## What It Does

ClawForge manages the full lifecycle of coding agent tasks:

1. **Scope** a task with rich context (PRDs, vault notes, code)
2. **Spawn** a coding agent on an isolated git worktree in tmux
3. **Track** everything in a JSON registry
4. **Watch** agent health, auto-respawn failures
5. **Review** PRs with multi-model code review
6. **Notify** humans via Discord
7. **Merge** with CI and review safety checks
8. **Clean** up worktrees, sessions, registry entries
9. **Learn** from results to improve future tasks

## Architecture

```
                          clawforge CLI
                              │
              ┌───────────────┼───────────────┐
              │               │               │
          Shortcuts       Commands         Meta
          ┌─────┐    ┌──────────────┐    ┌──────┐
          │ run  │    │ scope  spawn │    │ help │
          │ dash │    │ status watch │    │ ver  │
          └─────┘    │ review notify│    └──────┘
                     │ merge  clean │
                     │ learn        │
                     └──────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
          bin/*.sh    lib/common.sh   config/defaults.json
              │             │
              │       ┌─────┴─────┐
              │       │ Registry  │
              │       │ (JSON)    │
              │       └───────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
  tmux    git worktree  gh CLI
  sessions  (isolated)  (PRs/CI)
    │
  coding agents
  (claude / codex)
```

## Installation

### As an OpenClaw Skill (recommended)

```bash
git clone https://github.com/cyperx84/clawforge.git ~/.openclaw/workspace/clawforge
mkdir -p ~/.openclaw/skills/clawforge
ln -sf ~/.openclaw/workspace/clawforge/SKILL.md ~/.openclaw/skills/clawforge/SKILL.md
ln -sf ~/.openclaw/workspace/clawforge/bin/clawforge ~/.local/bin/clawforge
```

### Standalone CLI

```bash
git clone https://github.com/cyperx84/clawforge.git
cd clawforge
ln -sf "$(pwd)/bin/clawforge" ~/.local/bin/clawforge
clawforge version
```

### Prerequisites

- `bash` (4+), `jq`, `git`, `tmux`
- `gh` (GitHub CLI, authenticated)
- `claude` and/or `codex` CLI

## Quick Start

```bash
# The one-liner — scope + spawn in one step
clawforge run --repo ~/github/myapp --branch feat/auth --task "Add JWT auth"

# Check what's running
clawforge dashboard

# After the agent creates a PR
clawforge review --repo ~/github/myapp --pr 42
clawforge merge --repo ~/github/myapp --pr 42 --squash
clawforge clean --all-done
clawforge learn --task-id <id> --auto --memory
```

## Commands

| Command | Description | Key Flags |
|---------|-------------|-----------|
| `scope` | Assemble prompt with context | `--task`, `--prd`, `--vault-query`, `--context` |
| `spawn` | Create worktree + launch agent | `--repo`, `--branch`, `--task`, `--agent`, `--model` |
| `status` | Show all tracked tasks | `--status` |
| `watch` | Health-check all agents | `--json`, `--dry-run` |
| `review` | Multi-model code review | `--repo`, `--pr`, `--reviewers` |
| `notify` | Send Discord notification | `--type`, `--task-id`, `--message` |
| `merge` | Merge PR with safety checks | `--repo`, `--pr`, `--auto`, `--squash` |
| `clean` | Clean up completed tasks | `--task-id`, `--all-done`, `--stale-days` |
| `learn` | Record learnings | `--task-id`, `--auto`, `--notes`, `--memory` |
| `run` | Scope + spawn in one step | `--repo`, `--branch`, `--task` |
| `dashboard` | Pretty overview of everything | (none) |

**Global flag:** `--verbose` enables debug logging for any command.

## Configuration

Edit `config/defaults.json`:

```json
{
  "default_agent": "claude",
  "default_model_claude": "claude-sonnet-4-5",
  "default_model_codex": "gpt-5.3-codex",
  "default_effort": "high",
  "max_retries": 3,
  "reviewers": ["claude"],
  "notify": {
    "defaultChannel": "channel:..."
  }
}
```

## Testing

```bash
./tests/run-all-tests.sh
```

## License

MIT
