---
name: clawforge
description: "Multi-mode coding workflow CLI — from quick patches to parallel agent orchestration. Use when: (1) spawning coding agents on tasks (sprint, swarm), (2) reviewing PRs with multi-model review, (3) managing agent lifecycle (steer, attach, stop), (4) monitoring agent health/progress. NOT for: simple one-liner fixes (just edit), reading code (use read tool), or non-git projects."
metadata:
  {
    "openclaw":
      {
        "emoji": "🤖",
        "requires": { "bins": ["clawforge", "jq", "git", "tmux"] },
      },
  }
---

# ClawForge v1.4 — Multi-Mode Coding Workflow + Fleet Ops

## Overview

ClawForge manages coding agents (Claude Code, Codex) running in tmux sessions on isolated git worktrees. Three workflow modes match task complexity:

- **Sprint** — Single agent, full dev cycle (the workhorse)
- **Review** — Quality gate on an existing PR (analysis only)
- **Swarm** — Parallel multi-agent orchestration

Plus management commands: `steer`, `attach`, `stop`, `watch --daemon`, `status`, `dashboard`, observability commands `cost`, `conflicts`, `templates`, and fleet ops commands `memory`, `init`, `history`.

## Quick Start


### New in v0.5

```bash
clawforge dashboard                 # TUI with vim keybindings + ASCII animation
clawforge cost --summary            # token/cost rollup
clawforge conflicts                 # overlap/conflict tracking
clawforge templates                 # built-in/custom workflow templates
clawforge sprint --template bugfix "Fix auth race" --budget 3.00 --ci-loop
clawforge swarm --json --notify --webhook https://example.com/hook "Migrate tests"
```

### New in v1.4

```bash
clawforge web                     # Launch web dashboard (http://localhost:9876)
clawforge web --port 8080 --open  # Custom port + auto-open browser
```

### New in v1.3

```bash
clawforge profile create fast --agent claude --model haiku --timeout 5  # Reusable presets
clawforge sprint --repo . --task "tests" --after 1                      # Task chaining
clawforge replay 1                                                      # Re-run task
clawforge export --format json --save report.json                       # Export history
clawforge completions zsh                                               # Tab completions
clawforge config set discord_webhook https://discord.com/api/webhooks/... # Notifications
```

### New in v1.2

```bash
clawforge config set default_agent claude    # Persistent user config
clawforge config set auto_clean true         # No more flags every time
clawforge multi-review --pr 42               # Multi-model PR review
clawforge summary 1                          # AI summary of agent work
clawforge parse-cost all --update            # Real cost tracking from output
```

### New in v1.1

```bash
clawforge resume 1                           # Restart failed task
clawforge diff 1                             # See changes without attaching
clawforge pr 1                               # Create PR from task
```

### New in v0.9

```bash
clawforge logs 1                    # Capture agent output from tmux
clawforge logs 1 --follow           # Live stream agent output
clawforge on-complete 1             # Fire webhooks + notify on task finish
clawforge dashboard                 # p = toggle live preview pane
```

### New in v0.8

```bash
clawforge dashboard                 # Views: 1=all, 2=running, 3=finished, Tab=cycle
                                    # n=nudge running agent
clawforge doctor                    # Diagnose orphans, stale tasks, disk, branches
clawforge doctor --fix              # Auto-fix issues
clawforge sprint --auto-clean --timeout 30 "Task"   # Auto-cleanup + watchdog
clawforge clean --prune-days 14     # Remove old archived tasks from registry
clawforge clean --all-done          # Clean + delete merged branches automatically
```

### New in v0.7

```bash
clawforge doctor                    # Health check: orphans, stale tasks, disk space
clawforge doctor --fix              # Auto-remediate issues
clawforge sprint "Task" --auto-clean --timeout 30  # Cleanup + watchdog
clawforge clean --prune-days 14     # Prune old archived entries
```

### New in v0.6

```bash
clawforge swarm --repos ~/api,~/web "Upgrade auth library"
clawforge sprint --routing auto "Refactor auth service"
clawforge memory add "Run prisma generate after schema changes"
clawforge memory search prisma
clawforge init --claude-md
clawforge history --mode swarm --limit 5
```

### Sprint (single agent)

```bash
clawforge sprint "Add JWT authentication middleware"
clawforge sprint ~/github/api "Fix null pointer in UserService" --quick
clawforge sprint "Add rate limiter" --branch feat/rate-limit --agent codex
```

### Review (quality gate)

```bash
clawforge review --pr 42
clawforge review --pr 42 --fix    # Spawn agent to fix issues
```

### Swarm (parallel agents)

```bash
clawforge swarm "Migrate all tests from jest to vitest"
clawforge swarm "Add i18n to all user-facing strings" --max-agents 4
clawforge swarm --repos ~/api,~/web,~/shared "Upgrade auth v2 to v3"
```

### Monitor & Manage

```bash
clawforge status                   # Short IDs, mode, status
clawforge attach 1                 # Attach to agent tmux session
clawforge steer 1 "Use bcrypt"    # Course-correct running agent
clawforge stop 1 --yes            # Stop agent
clawforge watch --daemon           # Background monitoring
clawforge dashboard                # Full overview + system health
```

## Workflow Modes

### `clawforge sprint [repo] "<task>" [flags]`

The workhorse. Single agent, full dev cycle.

**Flow:** scope → spawn (1 agent) → [watch] → review → PR → merge → clean → learn

**Flags:**
- `--quick` — Patch mode: auto-branch, auto-merge, skip review
- `--branch <name>` — Override auto-generated branch name
- `--agent <claude|codex>` — Override agent selection
- `--model <model>` — Override model
- `--routing <auto|cheap|quality>` — Phase-based model routing
- `--auto-merge` — Merge automatically if CI + review pass
- `--dry-run` — Preview what would happen

**Auto-branch naming:** `sprint/<slug>` or `quick/<slug>` (with collision detection)

### `clawforge review [repo] --pr <num> [flags]`

Quality gate on an existing PR. No agent spawned — analysis only.

**Flow:** fetch PR diff → multi-model review → post comments → notify

**Flags:**
- `--pr <num>` — PR number (required)
- `--fix` — Escalate: spawn agent to fix issues found
- `--reviewers <list>` — Override default reviewers (default: claude,gemini)
- `--dry-run` — Show review without posting comments

### `clawforge swarm [repo] "<task>" [flags]`

Parallel multi-agent orchestration. Decomposes task, spawns N agents.

**Flow:** scope (decompose) → spawn (N agents) → watch → review (each) → merge → clean → learn

**Flags:**
- `--max-agents <N>` — Cap parallel agents (default: 3, warns on >3 re: RAM)
- `--agent <name>` — Force specific agent for all sub-tasks
- `--repos <paths>` — Multi-repo swarm (comma-separated paths)
- `--repos-file <file>` — Multi-repo swarm from file
- `--routing <auto|cheap|quality>` — Phase-based model routing
- `--auto-merge` — Merge each PR automatically after CI + review
- `--dry-run` — Show decomposition plan without spawning

**Short IDs:** parent=#3, sub-agents=#3.1, #3.2, #3.3

## Management Commands

### `clawforge status`

Show all tracked tasks with short sequential IDs, mode, and status.

### `clawforge steer <id> "<message>"`

Send course correction to a running agent via tmux. Checks state first — if done, suggests review instead.

```bash
clawforge steer 1 "Use bcrypt instead of md5"
clawforge steer 3.2 "Skip legacy migration files"
```

### `clawforge attach <id>`

Attach to agent's tmux session. For swarm tasks, shows picker.

### `clawforge stop <id> [--yes] [--clean]`

Kill agent, mark as stopped. Prompts for confirmation unless `--yes`. `--clean` removes worktree.

### `clawforge watch [--daemon]`

Monitor all active tasks. Detects dead sessions, checks CI, auto-steers on CI failure.

- Default: one-shot check
- `--daemon` — Background loop (default: 5 min interval)
- `--stop` — Stop the daemon
- `--json` — Machine-readable output

**CI auto-feedback loop:** When CI fails, watch automatically steers the agent with error context (up to 2 retries).

### `clawforge dashboard`

Overview: active tasks (with short IDs + modes), status summary, mode breakdown, system health (RAM estimate, disk usage), conflict warnings.

## Direct Module Access

For power users, direct module commands remain available via `clawforge help --all`:

```bash
clawforge scope --task "..." --prd docs/spec.md
clawforge spawn --repo ~/github/app --branch feat/x --task "..."
clawforge notify --type task-done --task-id abc123
clawforge merge --repo ~/github/app --pr 42 --squash
clawforge clean --all-done
clawforge learn --task-id abc123 --auto --memory
```

## Smart Behaviors

### Auto-Everything
- **Repo from cwd** — No `--repo` needed if you're already in a git repo
- **Auto-branch naming** — `sprint/<slug>`, `quick/<slug>`, `swarm/<slug>` with collision detection
- **Agent auto-detection** — Prefers Claude, falls back to Codex

### Escalation Paths
- `sprint --quick` → Detects complex task → "Consider full sprint"
- `sprint` → Multiple file domains → "Try swarm?"
- `review --fix` → Spawns agent on PR branch

### CI Feedback Loop
- Watch detects CI failure → fetches error log → auto-steers agent → agent fixes + pushes → up to 2 retries

### Conflict Detection (Swarm)
- Tracks files modified by each agent
- Dashboard warns when agents touch overlapping files

## Configuration

`config/defaults.json`:

```json
{
  "default_agent": "claude",
  "default_model_claude": "claude-sonnet-4-5",
  "default_model_codex": "gpt-5.3-codex",
  "ci_retry_limit": 2,
  "ram_warn_threshold": 3,
  "reviewers": ["claude", "gemini"],
  "auto_simplify": true
}
```

## Tips

- **Use `--dry-run` first** when trying new workflows or unfamiliar repos
- **Sprint is the default** — use it for most tasks
- **Quick for patches** — `--quick` auto-merges with no review
- **Swarm for big refactors** — decomposes and parallelizes
- **Steer is your course correction** — send messages to running agents
- **Watch daemon for hands-off** — monitors continuously in background
- **Dashboard shows everything** — tasks, health, RAM, conflicts
- **Short IDs everywhere** — `#1`, `3.2` instead of full slugs
