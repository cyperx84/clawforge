---
id: clawforge-v04-implementation
title: "ClawForge v0.4 — Implementation Plan"
created: 2026-03-02 15:20
modified: 2026-03-02 15:20
tags:
  - build-log
  - clawforge
  - agent-swarm
topics:
  - coding-agents
  - developer-tools
refs:
  - "[[prds/clawforge-v04-workflow-modes]]"
  - "[[ideas/agent-army]]"
aliases:
  - clawforge-v04-build
---

# ClawForge v0.4 — Implementation Plan

PRD: [[prds/clawforge-v04-workflow-modes]]

## Architecture

The existing 9 modules stay intact. We add a **mode layer** on top that composes them differently.

```
CLI entry (bin/clawforge)
  ├── Mode router (NEW)
  │   ├── sprint.sh   → scope + spawn + watch-hooks + review + clean + learn
  │   ├── review.sh   → review + notify (+ optional spawn for --fix)
  │   └── swarm.sh    → scope(decompose) + spawn(N) + watch + review(N) + merge(N) + clean + learn
  ├── Management commands (NEW)
  │   ├── steer.sh    → tmux send-keys with state checking
  │   ├── attach.sh   → tmux attach wrapper
  │   └── stop.sh     → kill + clean
  ├── Enhanced existing
  │   ├── status (short IDs, mode column)
  │   ├── watch (--daemon mode)
  │   ├── dashboard (RAM/disk info)
  │   └── clean (unchanged)
  └── Direct module access (hidden from main help)
      └── scope, spawn, track, notify, merge, learn
```

## Phases

### Phase 1: Foundation (non-breaking changes)

**Goal:** Enhance existing modules to support modes without changing current behavior.

1. **Short task IDs** — `lib/common.sh`
   - Add sequential short ID generator (#1, #2, #3...)
   - Map short IDs ↔ full UUIDs in registry
   - `resolve_task_id()` function accepts either format

2. **Auto-repo detection** — `lib/common.sh`
   - `detect_repo()` walks up from cwd to find .git
   - All commands use this as fallback when --repo omitted

3. **Auto-branch naming** — `lib/common.sh`
   - `slugify_task()` converts task description to branch slug
   - Prefix by mode: `sprint/`, `quick/`, `swarm/`
   - Collision detection (append -2, -3 if branch exists)

4. **Registry enhancements** — `lib/common.sh` + registry schema
   - Add `mode` field (sprint|review|swarm)
   - Add `short_id` field
   - Add `files_touched` array (for conflict detection)
   - Add `ci_retries` counter

5. **Tests:** Update existing tests, add tests for new utility functions

### Phase 2: Mode Layer

**Goal:** Implement the three mode commands.

6. **`bin/sprint.sh`** — The workhorse mode
   - Parse args: `[repo] "<task>" [--quick] [--branch] [--agent] [--model] [--auto-merge] [--dry-run]`
   - Auto-detect repo, auto-generate branch
   - Call `scope-task.sh` (minimal for --quick, full otherwise)
   - Call `spawn-agent.sh` with resolved settings
   - Register task with mode=sprint
   - Print watch tip on first run
   - `--quick` sets: skip_review=true, auto_merge=true, tests=targeted

7. **`bin/review-mode.sh`** — Quality gate mode (distinct from existing review-pr.sh)
   - Parse args: `[repo] --pr <num> [--fix] [--reviewers] [--dry-run]`
   - Call existing `review-pr.sh` for the actual review
   - `--fix`: create worktree from PR branch HEAD, spawn agent, push to same branch
   - Register as mode=review in registry

8. **`bin/swarm.sh`** — Parallel orchestration mode
   - Parse args: `[repo] "<task>" [--max-agents] [--agent] [--auto-merge] [--dry-run]`
   - Scope phase: use Claude to decompose task into sub-tasks
   - RAM warning if agents > threshold
   - Spawn N agents, each with own worktree
   - Register parent task + sub-tasks in registry
   - Short IDs: parent=#3, sub-agents=#3.1, #3.2, #3.3

9. **CLI router update** — `bin/clawforge`
   - Add `sprint`, `review`, `swarm` as top-level subcommands
   - Keep `run` as alias for `sprint`
   - Update help text (modes prominent, modules in `--all`)

10. **Tests:** Mode-specific tests, end-to-end flow tests

### Phase 3: Management Commands

**Goal:** steer, attach, stop + enhanced watch.

11. **`bin/steer.sh`**
    - Resolve short ID → task
    - Check task state (running? done? failed?)
    - If done: suggest review instead
    - If running: `tmux send-keys -t <session> "<message>" Enter`
    - For swarm sub-agents: `steer 3.2` targets agent 2 of task 3
    - Log steer events in registry

12. **`bin/attach.sh`**
    - Resolve short ID → tmux session name
    - For swarm: show picker (fzf if available, numbered list otherwise)
    - `tmux attach -t <session>`

13. **`bin/stop.sh`**
    - Resolve short ID → task
    - Confirm unless `--yes`
    - Kill tmux session
    - Mark task as stopped in registry
    - Optionally clean worktree (`--clean`, default: keep)

14. **`watch --daemon` enhancement** — `bin/check-agents.sh`
    - New `--daemon` flag: loop with configurable interval (default: 5 min)
    - PID file at `~/.openclaw/workspace/clawforge/watch.pid`
    - `watch --stop` kills the daemon
    - Sends notifications via `notify.sh` on state changes

15. **CI auto-feedback loop** — `bin/check-agents.sh`
    - When CI failure detected on a task's PR:
      - `gh run view --log-failed` to get error
      - Auto-call steer with CI context
      - Increment `ci_retries` in registry
      - Stop after `ci_retry_limit`

16. **Tests:** steer with various states, attach routing, daemon lifecycle

### Phase 4: Polish

17. **Dashboard enhancements**
    - Show RAM usage per agent (rough estimate)
    - Show disk usage of worktrees
    - Mode breakdown in summary

18. **Escalation suggestions**
    - sprint --quick detects large diff → suggests full sprint
    - sprint detects multiple files across domains → suggests swarm
    - review --fix auto-escalation

19. **Conflict detection** (swarm)
    - Track files modified by each agent via git diff
    - Warn in status when overlap detected
    - Log conflicts for coordinator

20. **SKILL.md update** — Rewrite to reflect v0.4 command surface
21. **README.md update** — New examples, mode documentation
22. **VERSION bump** → 0.4.0

## Implementation Order

```
Phase 1 (foundation)  →  Phase 2 (modes)  →  Phase 3 (management)  →  Phase 4 (polish)
   ~2 hours               ~3 hours              ~2 hours                ~1 hour
```

Total estimate: ~8 hours of coding agent time.

**Priority if time-constrained:** Phase 1 + Phase 2 (sprint only) = minimum viable v0.4. Swarm mode and CI feedback loop can follow as v0.4.1.

## Files Changed

### New files
- `bin/sprint.sh` — Sprint mode
- `bin/review-mode.sh` — Review mode  
- `bin/swarm.sh` — Swarm mode
- `bin/steer.sh` — Course correction
- `bin/attach.sh` — tmux attach wrapper
- `bin/stop.sh` — Task termination
- `tests/test-sprint.sh` — Sprint tests
- `tests/test-steer.sh` — Steer tests
- `tests/test-modes.sh` — Mode routing tests

### Modified files
- `bin/clawforge` — Add mode routing, update help
- `lib/common.sh` — Short IDs, auto-repo, auto-branch, registry schema
- `bin/check-agents.sh` — Daemon mode, CI feedback loop
- `config/defaults.json` — New config fields
- `SKILL.md` — Rewrite for v0.4
- `README.md` — New docs
- `VERSION` — 0.4.0

## Risks

- **Swarm decomposition quality** depends on Claude's ability to break tasks into good sub-tasks. May need prompt engineering iteration.
- **CI feedback loop** could create infinite retry loops if the fix introduces new failures. Cap at 2 retries + different error detection.
- **tmux send-keys reliability** — long messages may get truncated. Use temp file + `tmux load-buffer` for steer messages >200 chars.

## Status

- [ ] Phase 1: Foundation
- [ ] Phase 2: Mode Layer
- [ ] Phase 3: Management Commands
- [ ] Phase 4: Polish
