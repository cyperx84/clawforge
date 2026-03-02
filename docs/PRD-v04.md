---
id: clawforge-v04-workflow-modes
title: "ClawForge v0.4 — Workflow Modes PRD"
created: 2026-03-02 15:20
modified: 2026-03-02 15:20
tags:
  - prd
  - clawforge
  - agent-swarm
topics:
  - coding-agents
  - developer-tools
refs:
  - "[[ideas/agent-army]]"
  - "[[00-projects]]"
aliases:
  - clawforge-v04
  - clawforge-modes
---

# ClawForge v0.4 — Workflow Modes

## Summary

Evolve ClawForge from a single-mode agent swarm tool into a multi-mode coding workflow CLI. One tool, four workflows, smart defaults — from quick patches to parallel agent orchestration.

**Repo:** https://github.com/cyperx84/clawforge
**Current version:** v0.3.0 (9 modules, 118 tests, shell-based)
**Target:** v0.4.0

## Problem

v0.3 treats every task the same — full scope → spawn → watch → review → merge pipeline. A one-line typo fix shouldn't need multi-model review. A PR quality check shouldn't spawn an agent. The tool needs workflow modes that match task complexity.

## Design Principles

1. **One command to start** — smart defaults handle the rest
2. **Repo from cwd** — no `--repo` needed if you're already there
3. **Auto-everything** — branch names, agent selection, model choice
4. **Explicit monitoring** — no hidden background processes, but easy to enable
5. **Escalation built in** — any mode can suggest upgrading to the next level
6. **Human can always attach** — tmux sessions for every agent, always

## Command Surface

### Core Modes (3 commands)

#### `clawforge sprint [repo] "<task>" [flags]`

The workhorse. Single agent, full dev cycle.

```bash
clawforge sprint "Add JWT authentication middleware"
clawforge sprint ~/github/api "Fix null pointer in UserService" --quick
clawforge sprint "Add rate limiter" --branch feat/rate-limit --agent codex
```

**Flow:**
```
scope → spawn (1 agent) → [watch] → /simplify → PR → review → notify → clean → learn
```

**Flags:**
- `--quick` — Patch mode. Auto-branch, auto-merge, skip review, targeted tests only
- `--branch <name>` — Override auto-generated branch name
- `--agent <claude|codex>` — Override agent selection
- `--model <model>` — Override model
- `--auto-merge` — Merge automatically if CI + review pass
- `--dry-run` — Preview what would happen

**Auto-branch naming:**
- Normal: `sprint/<slug-from-task>` (e.g., `sprint/add-jwt-auth`)
- Quick: `quick/<slug>` (e.g., `quick/fix-null-pointer`)

#### `clawforge review [repo] --pr <num> [flags]`

Quality gate on an existing PR. No agent spawned — analysis only.

```bash
clawforge review --pr 42
clawforge review ~/github/api --pr 42 --fix
clawforge review --pr 42 --reviewers claude,gemini,codex
```

**Flow:**
```
fetch PR diff → multi-model review → /simplify check (suggestions only) → post comments → notify
```

**Flags:**
- `--fix` — Escalate: spawn agent to fix issues found (branches from PR HEAD, pushes to same PR)
- `--reviewers <list>` — Override default reviewers (default: `claude,gemini`)
- `--dry-run` — Show review without posting comments

#### `clawforge swarm [repo] "<task>" [flags]`

Parallel multi-agent orchestration. Decomposes task, spawns N agents, coordinates.

```bash
clawforge swarm "Migrate all tests from jest to vitest"
clawforge swarm "Add i18n to all user-facing strings" --max-agents 4
```

**Flow:**
```
scope (decompose into sub-tasks) → spawn (N agents) → watch (all) → conflict detection → review (each) → merge (coordinated order) → clean → learn
```

**Flags:**
- `--max-agents <N>` — Cap parallel agents (default: 3, warns on >3 re: RAM)
- `--agent <claude|codex>` — Force specific agent for all sub-tasks
- `--auto-merge` — Merge each PR automatically after CI + review
- `--dry-run` — Show decomposition plan without spawning

### Management Commands (7 commands)

#### `clawforge status`

Show all tracked tasks with short sequential IDs.

```
$ clawforge status
  #1  sprint  running   myapp  "Add JWT auth"         3m ago
  #2  sprint  pr-ready  myapp  "Fix null pointer"     12m ago
  #3  swarm   running   myapp  "Migrate to vitest"    8m ago (3 agents)
```

#### `clawforge attach <id>`

Shortcut for `tmux attach -t <session>`. For swarm tasks, shows picker for which agent session.

#### `clawforge stop <id>`

Kill the agent, optionally clean the worktree. Prompts for confirmation unless `--yes`.

#### `clawforge steer <id> "<message>"`

Send a course correction to a running agent via tmux. Checks task state first — if task is done, suggests `review` instead.

```bash
clawforge steer 1 "Use bcrypt instead of md5 for password hashing"
clawforge steer 3.2 "Skip the legacy migration files"  # Agent 2 in swarm task 3
```

#### `clawforge watch [--daemon]`

Monitor all active tasks. Detects dead sessions, checks CI, reports status.

- Default: one-shot check, prints results
- `--daemon` — Background process, monitors continuously, sends notifications on events
- `--json` — Machine-readable output (for cron/OpenClaw integration)

**Hybrid approach:** Modes don't auto-start the daemon. On first `sprint`/`swarm`, ClawForge prints a tip:
```
💡 Tip: Run `clawforge watch --daemon` in another pane for auto-monitoring
```

#### `clawforge clean [--stale-days N] [--all-done]`

Bulk cleanup of completed tasks. Removes worktrees, tmux sessions, registry entries.

#### `clawforge dashboard`

Pretty-print overview: active tasks, status summary, recent learnings, system health (RAM, disk).

### Power User Access

Direct module commands remain available but hidden from main `--help`. Accessible via `clawforge help --all`:

```
clawforge scope, spawn, track, notify, merge, learn
```

## Smart Behaviors

### CI Failure Auto-Feedback Loop

When watch detects a CI failure on a task's PR:

1. Fetch CI log via `gh run view`
2. Extract relevant error output
3. Auto-steer the agent with CI context: "CI failed: [error]. Fix and push."
4. Agent fixes, pushes, CI re-runs
5. Up to N retries (configurable, default: 2)

```
sprint → PR → CI fails → auto-steer with log → fix → push → CI passes → notify
```

### Worktree Health Recovery

Before respawning a failed agent:

1. Check worktree for dirty state (uncommitted files, failed merges)
2. If dirty: stash changes, log what was stashed
3. If broken merge: reset to last clean commit
4. Adjust prompt with failure context (Ralph Loop)
5. Respawn with clean state + learned context

### Conflict Detection (Swarm Mode)

- Track file-level scope per agent when possible
- `status` warns when multiple tasks modify overlapping files
- Coordinator agent resolves conflicts before merge
- Merge order determined by dependency analysis

### Escalation Paths

- `sprint --quick` → "This looks bigger than a patch. Run as full sprint?" → `sprint`
- `sprint` → "This could benefit from parallel agents. Try swarm?" → `swarm`
- `review --fix` → Spawns sprint-like agent on the PR branch

### RAM Warning (Swarm)

When spawning >3 agents:
```
⚠️  5 agents will use ~8GB RAM (estimated). Continue? [Y/n]
```
Skip with `--yes`.

## Configuration

`~/.openclaw/workspace/clawforge/config/defaults.json`:

```json
{
  "default_agent": "claude",
  "default_model_claude": "claude-sonnet-4-5",
  "default_model_codex": "gpt-5.3-codex",
  "default_effort": "high",
  "max_retries": 3,
  "ci_retry_limit": 2,
  "reviewers": ["claude", "gemini"],
  "auto_simplify": true,
  "ram_warn_threshold": 3,
  "notify": {
    "defaultChannel": "channel:..."
  }
}
```

## Non-Goals (v0.4)

- URL-based repos (auto-clone) — local repos only, helpful error for URLs
- GUI/TUI dashboard — CLI only
- Non-git projects — git required
- Shared node_modules optimization — warn about RAM, don't try to fix it yet

## Success Criteria

- All existing 118 tests still pass
- New tests for: mode routing, steer, auto-branch naming, CI feedback loop, short IDs
- `sprint` happy path works end-to-end on a real repo
- `--quick` flag produces a merged PR with zero human intervention
- `steer` successfully course-corrects a running agent
- `watch --daemon` runs stable for 1+ hours
