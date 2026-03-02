# ClawForge v0.5 PRD — Observability + Intelligence

## Overview
Build 6 new features on top of the existing v0.4 codebase. Theme: make workflows smarter and more visible.

## Repo
~/.openclaw/workspace/clawforge

## Existing Architecture
- Pure bash CLI (~4200 lines across 15 scripts in bin/ + lib/common.sh)
- 210 tests in tests/
- Modes: sprint, review, swarm + management: steer, attach, stop
- Registry at ~/.clawforge/registry/
- Homebrew installable (cyperx84/tap/clawforge)

## Feature 1: Live TUI Dashboard (`clawforge dashboard`)

### Requirements
- Real-time terminal UI using `gum` (charmbracelet) or pure bash+tput (prefer gum if available, fallback to tput)
- Show all active clawforge agents in a table:
  - Agent ID (short), Mode, Branch, Status, Last Commit (time+msg), Test Result, Token Spend
- Auto-refresh every 2 seconds
- **Vim keybindings:**
  - j/k: navigate agent list
  - Enter: attach to selected agent's tmux session
  - s: steer selected agent (prompts for message)
  - x: stop selected agent
  - q: quit dashboard
  - /: filter agents
  - r: force refresh
  - ?: show help overlay
- **ASCII startup animation:**
  - Show the ClawForge ASCII art logo
  - Animate it forging/hammering effect (frames cycling through)
  - 1-2 second animation then transition to dashboard
  - Use tput for colors (amber/orange forge theme)
- Data source: read from registry/*.json + tmux list-sessions + git worktree status
- Implement as bin/dashboard.sh

### Implementation Notes
- Use bash `read -t 0.5 -n 1` for non-blocking key input
- tput for cursor positioning, colors, clearing
- Parse registry JSON with jq
- Refresh loop with trap for clean exit (restore terminal)
- If gum is available, use gum table for pretty output; otherwise tput grid

## Feature 2: Cost Tracking

### Requirements
- New module: bin/cost.sh
- Capture token usage per run:
  - After sprint/swarm agent completes, scrape Claude Code `/cost` output from tmux pane
  - Parse: input tokens, output tokens, cache hits, total cost
  - Store in registry/costs.jsonl: {taskId, agentId, model, inputTokens, outputTokens, cacheHits, totalCost, timestamp}
- Aggregate in swarm mode: sum all agent costs
- Budget cap flag: `--budget <dollars>` on sprint/swarm
  - Monitor cost during run, kill agent if budget exceeded
  - Warn at 80% of budget
- `clawforge cost [task-id]` — show cost breakdown
- `clawforge cost --summary` — all-time cost summary grouped by mode
- Integrate cost display into dashboard (rightmost column)
- Add cost to learn.sh post-run summary

## Feature 3: CI Feedback Loop

### Requirements
- Enhance watch --daemon mode
- When PR CI fails:
  1. Fetch failure logs: `gh run view <id> --log-failed`
  2. Extract relevant error lines
  3. Auto-steer the agent: "CI failed with: <errors>. Fix and push."
  4. Track retry count per PR
  5. Max retries (default 3, configurable via --max-ci-retries)
  6. If max retries exceeded, notify and stop
- New flag on sprint/swarm: `--ci-loop` to enable auto-fix behavior
- CI status shown in dashboard

## Feature 4: Swarm Conflict Resolution

### Requirements
- During swarm, monitor for overlapping file changes across agents
- Detection: after each agent commits, check `git diff --name-only` across all active worktrees
- If overlap detected:
  1. Log conflict in registry
  2. Show warning in dashboard (highlight conflicting agents)
  3. When both agents complete, spawn a coordinator agent to merge
  4. Coordinator uses: git merge-base + 3-way diff + Claude Code to resolve
- `clawforge conflicts` — show current/recent conflicts
- Conflict count shown in dashboard

## Feature 5: Task Templates

### Requirements
- Template directory: ~/.clawforge/templates/
- Ship with built-in defaults in lib/templates/:
  - migration.json: {maxAgents: 4, mode: "swarm", autoMerge: true, ciLoop: true}
  - refactor.json: {mode: "sprint", autoMerge: false, ciLoop: true}
  - test-coverage.json: {mode: "swarm", maxAgents: 3, autoMerge: true}
  - bugfix.json: {mode: "sprint", quick: true, autoMerge: true}
  - security-audit.json: {mode: "review", depth: "deep"}
- Usage: `clawforge sprint --template refactor "Refactor auth module"`
- Template overrides default flags but CLI flags override template
- `clawforge templates` — list available templates
- `clawforge templates new <name>` — create custom template interactively
- Templates are JSON files with fields matching CLI flags

## Feature 6: OpenClaw Integration

### Requirements
- `--json` flag on all commands for structured JSON output
- JSON output includes: taskId, status, branch, pr_url, cost, duration, test_results
- `--notify` flag: on completion, run `openclaw system event --text "ClawForge: <summary>" --mode now`
- `--webhook <url>` flag: POST completion payload to URL
- Update SKILL.md to document new v0.5 commands
- Ensure all new commands work when called from OpenClaw cron/sessions

## Testing Requirements
- Add tests for each new feature
- Target: maintain 200+ test count
- Test dashboard key handling (mock input)
- Test cost parsing
- Test template loading/merging
- Test conflict detection logic
- Test CI feedback loop logic
- Test JSON output format

## Version
- Bump to 0.5.0
- Update README with new features
- Update CHANGELOG.md

## Style
- Match existing code style (shellcheck clean, set -euo pipefail)
- Keep common functions in lib/common.sh
- Colors via lib/common.sh log_* functions
- jq for JSON manipulation
