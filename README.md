# ClawForge

Multi-mode coding workflow CLI — from quick patches to parallel agent orchestration with Claude Code and Codex.

## Inspired By

This project was inspired by [Elvis's "OpenClaw + Codex/Claude Code Agent Swarm" workflow](https://x.com/elvissun/article/2025920521871716562) — a battle-tested system for managing a fleet of AI coding agents.

## What It Does

ClawForge manages coding agents running in tmux sessions on isolated git worktrees. Three workflow modes match task complexity:

| Mode | Use Case | Agents |
|------|----------|--------|
| **Sprint** | Single task, full dev cycle | 1 |
| **Review** | Quality gate on existing PR | 0 (analysis only) |
| **Swarm** | Parallel orchestration | N (decomposed) |

Plus management commands: `steer`, `attach`, `stop`, `watch --daemon`, `status`, `dashboard`.

## Architecture

```
                        clawforge CLI
                            │
            ┌───────────────┼───────────────┐
            │               │               │
       Workflow Modes   Management       Direct Access
       ┌───────────┐   ┌──────────┐    ┌──────────────┐
       │ sprint    │   │ status   │    │ scope  spawn │
       │ review    │   │ attach   │    │ notify merge │
       │ swarm     │   │ steer    │    │ clean  learn │
       └─────┬─────┘   │ stop    │    └──────────────┘
             │         │ watch    │
             │         │ dashboard│
             │         └────┬─────┘
             │              │
             └──────┬───────┘
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

### Sprint — the workhorse

```bash
# Single agent, full dev cycle (auto-detects repo from cwd)
clawforge sprint "Add JWT authentication middleware"

# Quick patch mode — auto-merge, skip review
clawforge sprint "Fix typo in readme" --quick

# With explicit options
clawforge sprint ~/github/api "Fix null pointer" --branch fix/null-ptr --agent codex
```

### Review — quality gate

```bash
clawforge review --pr 42
clawforge review --pr 42 --fix               # Spawn agent to fix issues
clawforge review --pr 42 --reviewers claude,gemini,codex
```

### Swarm — parallel agents

```bash
clawforge swarm "Migrate all tests from jest to vitest"
clawforge swarm "Add i18n to all strings" --max-agents 4
```

### Monitor & Manage

```bash
clawforge status                   # Short IDs: #1, #2, #3
clawforge attach 1                 # Attach to agent tmux session
clawforge steer 1 "Use bcrypt"    # Course-correct running agent
clawforge steer 3.2 "Skip legacy" # Steer sub-agent 2 of swarm task 3
clawforge stop 1 --yes            # Stop agent
clawforge watch --daemon           # Background monitoring + CI feedback
clawforge dashboard                # Full overview + system health
```

## Commands

### Workflow Modes

| Command | Description | Key Flags |
|---------|-------------|-----------|
| `sprint` | Single agent, full dev cycle | `--quick`, `--branch`, `--agent`, `--auto-merge`, `--dry-run` |
| `review` | Quality gate on existing PR | `--pr`, `--fix`, `--reviewers`, `--dry-run` |
| `swarm` | Parallel multi-agent orchestration | `--max-agents`, `--agent`, `--auto-merge`, `--dry-run` |

### Management

| Command | Description | Key Flags |
|---------|-------------|-----------|
| `status` | Show tracked tasks with short IDs | `--status` |
| `attach` | Attach to agent tmux session | (task ID) |
| `steer` | Course-correct running agent | (task ID, message) |
| `stop` | Stop a running agent | `--yes`, `--clean` |
| `watch` | Monitor agent health | `--daemon`, `--stop`, `--json`, `--interval` |
| `dashboard` | Overview + system health | (none) |
| `clean` | Clean up completed tasks | `--all-done`, `--stale-days`, `--dry-run` |
| `learn` | Record learnings | `--auto`, `--notes`, `--memory` |

### Direct Module Access (via `clawforge help --all`)

| Command | Description |
|---------|-------------|
| `scope` | Assemble prompt with context |
| `spawn` | Create worktree + launch agent |
| `notify` | Send Discord notification |
| `merge` | Merge PR with safety checks |
| `run` | Scope + spawn in one step (legacy) |

**Global flag:** `--verbose` enables debug logging for any command.

## Smart Behaviors

- **Auto-repo detection** — No `--repo` needed if you're in a git repo
- **Auto-branch naming** — `sprint/<slug>`, `quick/<slug>`, `swarm/<slug>` with collision detection
- **Short task IDs** — `#1`, `3.2` instead of full slugs
- **CI feedback loop** — Watch detects CI failure, auto-steers agent with error context (up to 2 retries)
- **Escalation suggestions** — Quick mode detects complex tasks, suggests full sprint
- **Conflict detection** — Dashboard warns when swarm agents touch overlapping files
- **RAM warnings** — Prompts when spawning >3 agents

## Configuration

Edit `config/defaults.json`:

```json
{
  "default_agent": "claude",
  "default_model_claude": "claude-sonnet-4-5",
  "default_model_codex": "gpt-5.3-codex",
  "ci_retry_limit": 2,
  "ram_warn_threshold": 3,
  "reviewers": ["claude", "gemini"],
  "auto_simplify": true,
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
