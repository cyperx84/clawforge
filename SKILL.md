---
name: clawforge
description: "Agent swarm workflow — spawn, monitor, review, and manage coding agents (Claude Code, Codex) on git worktrees with tmux sessions. Use when: (1) spawning coding agents on tasks, (2) monitoring agent health/progress, (3) reviewing PRs with multi-model review, (4) managing the full lifecycle of agent-driven development. NOT for: simple one-liner fixes (just edit), reading code (use read tool), or non-git projects."
metadata:
  {
    "openclaw":
      {
        "emoji": "🤖",
        "requires": { "bins": ["clawforge", "jq", "git", "tmux"] },
      },
  }
---

# ClawForge — Agent Swarm Workflow

## Overview

ClawForge manages coding agents (Claude Code, Codex) running in tmux sessions on isolated git worktrees. It handles the full lifecycle:

1. **Scope** — Assemble a rich prompt from task description + context
2. **Spawn** — Create a git worktree, launch a coding agent in tmux
3. **Track** — Register the task in a JSON registry
4. **Watch** — Health-check agents, auto-respawn failures
5. **Review** — Multi-model code review on the resulting PR
6. **Notify** — Send Discord notifications at key milestones
7. **Merge** — Safety-checked PR merge with CI/review gates
8. **Clean** — Remove worktrees, tmux sessions, registry entries
9. **Learn** — Capture patterns and learnings for future tasks

## Quick Start

### The One-Liner (most common)

```bash
clawforge run --repo ~/github/myapp --branch feat/auth --task "Add JWT authentication middleware"
```

This scopes the task and spawns an agent in one step.

### Monitor Progress

```bash
clawforge status          # List all tasks
clawforge watch           # Health-check all agents
clawforge dashboard       # Pretty overview of everything
```

### After the Agent Finishes

```bash
clawforge review --repo ~/github/myapp --pr 42
clawforge merge --repo ~/github/myapp --pr 42 --squash
clawforge clean --task-id <id>
clawforge learn --task-id <id> --auto --memory
```

## Commands

### `clawforge scope`

Assemble a comprehensive prompt from task description and context.

```bash
clawforge scope --task "Add rate limiting" --prd docs/rate-limit-prd.md --context src/middleware/
clawforge scope --task "Fix auth bug" --vault-query "authentication" --output json
```

**Flags:** `--task`, `--vault-query`, `--prd`, `--context`, `--template`, `--output`, `--dry-run`

### `clawforge spawn`

Create a git worktree and launch a coding agent in a tmux session.

```bash
clawforge spawn --repo ~/github/myapp --branch feat/rate-limit --task "Implement rate limiting"
clawforge spawn --repo ~/github/myapp --branch fix/auth --task "Fix auth" --agent codex --model gpt-5.3-codex
```

**Flags:** `--repo`, `--branch`, `--task`, `--agent`, `--model`, `--effort`, `--dry-run`

### `clawforge status`

Show all tracked tasks from the registry.

```bash
clawforge status                # All tasks
clawforge status --status running   # Filter by status
```

### `clawforge watch`

Health-check all active agents. Detects dead tmux sessions, checks for PRs, verifies CI status.

```bash
clawforge watch              # Check everything
clawforge watch --json       # Machine-readable output
clawforge watch --dry-run    # Check without auto-respawning
```

### `clawforge review`

Multi-model code review on a PR.

```bash
clawforge review --repo ~/github/myapp --pr 42
clawforge review --repo ~/github/myapp --pr 42 --reviewers claude,gemini
```

**Flags:** `--repo`, `--pr`, `--reviewers`, `--dry-run`

### `clawforge notify`

Send Discord notifications.

```bash
clawforge notify --type task-started --task-id abc123
clawforge notify --type pr-ready --task-id abc123 --pr 42
clawforge notify --message "Custom notification text"
```

**Types:** `task-started`, `pr-ready`, `task-failed`, `task-done`

### `clawforge merge`

Merge a PR with safety checks (CI passing, reviews approved).

```bash
clawforge merge --repo ~/github/myapp --pr 42 --squash
clawforge merge --repo ~/github/myapp --pr 42 --auto --task-id abc123
```

**Flags:** `--repo`, `--pr`, `--auto`, `--squash`, `--task-id`, `--dry-run`

### `clawforge clean`

Clean up completed tasks (worktrees, tmux sessions, registry).

```bash
clawforge clean --task-id abc123
clawforge clean --all-done          # Clean all done tasks
clawforge clean --stale-days 7      # Clean tasks older than 7 days
clawforge clean --dry-run           # Preview what would be cleaned
```

### `clawforge learn`

Capture learnings from completed tasks.

```bash
clawforge learn --task-id abc123 --auto --memory
clawforge learn --task-id abc123 --notes "Retry logic was fragile" --tags "error-handling,retry"
clawforge learn --summary           # View all learnings
```

### `clawforge run` (shortcut)

Scope + spawn in one step.

```bash
clawforge run --repo ~/github/myapp --branch feat/search --task "Add full-text search"
```

### `clawforge dashboard`

Pretty-print overview: active tasks, status summary, recent learnings, environment info.

```bash
clawforge dashboard
```

## Workflow

The standard workflow for an AI agent using clawforge:

```
1. scope   →  Gather context, build prompt
2. spawn   →  Create worktree, launch agent
3. watch   →  Monitor until PR is created
4. review  →  Multi-model code review
5. merge   →  Merge with safety checks
6. notify  →  Tell the human it's done
7. clean   →  Remove worktree + tmux session
8. learn   →  Record what worked/didn't
```

For simple tasks, use `clawforge run` which combines steps 1-2.

For monitoring, either run `clawforge watch` manually or set up a cron:

```bash
# Check every 5 minutes
*/5 * * * * ~/.local/bin/clawforge watch --json >> /tmp/clawforge-watch.log 2>&1
```

## Examples

### Fix a bug

```bash
clawforge run --repo ~/github/api --branch fix/null-check --task "Fix null pointer in UserService.getProfile when user has no avatar"
# Wait for agent to finish...
clawforge watch
clawforge review --repo ~/github/api --pr 55
clawforge merge --repo ~/github/api --pr 55 --squash
clawforge clean --all-done
```

### Parallel feature work

```bash
# Spawn multiple agents on different features
clawforge run --repo ~/github/app --branch feat/search --task "Implement search API"
clawforge run --repo ~/github/app --branch feat/notifications --task "Add push notifications"
clawforge run --repo ~/github/app --branch feat/dark-mode --task "Add dark mode toggle"

# Monitor all at once
clawforge dashboard
```

### Dry-run everything first

```bash
clawforge scope --task "Refactor auth" --dry-run
clawforge spawn --repo ~/github/app --branch refactor/auth --task "Refactor auth" --dry-run
clawforge watch --dry-run
```

## Configuration

Edit `~/.openclaw/workspace/clawforge/config/defaults.json`:

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

**Key settings:**
- `default_agent` — Which coding agent to use (`claude` or `codex`)
- `default_model_*` — Model for each agent
- `max_retries` — Auto-respawn limit for failed agents
- `reviewers` — Default models for PR review

## Tips

- **Always `--dry-run` first** when trying a new workflow or unfamiliar repo
- **Use `clawforge run`** for simple tasks — it handles scope + spawn together
- **Pick the right agent:** Claude Code for complex reasoning, Codex for fast iteration
- **Watch for stuck agents:** `clawforge watch` detects dead tmux sessions
- **Clean regularly:** `clawforge clean --stale-days 7` prevents worktree buildup
- **Record learnings:** `clawforge learn --auto --memory` feeds insights back into Builder's memory
- **Dashboard is your friend:** `clawforge dashboard` shows everything at a glance
- The registry at `registry/active-tasks.json` tracks all task state — you can query it directly with `jq` if needed
