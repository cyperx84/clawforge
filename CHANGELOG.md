# Changelog

## v1.2.0 — Power Features

### User Config (`clawforge config`)
- Persistent user config at `~/.clawforge/config.json`
- `config show|get|set|unset|init|path`
- User config overrides project defaults
- Configurable defaults for agent, model, timeout, auto-clean, routing, review models

### Multi-Model Review (`clawforge multi-review`)
- Run PRs through multiple AI models in parallel
- Auto-generates comparison report with severity counts
- Configurable model list via `review_models` config
- Supports `--diff-only`, `--output`, `--json`

### AI Summary (`clawforge summary`)
- LLM-generated summary of what an agent accomplished
- Gathers git diff + tmux output as context
- Multiple output formats: markdown, text, JSON
- Save to file with `--save`

### Real Cost Parsing (`clawforge parse-cost`)
- Scrapes Claude Code and Codex output for actual token/cost data
- Supports patterns from both agent CLIs
- `--update` writes to costs.jsonl registry
- `parse-cost all` processes all running agents at once

## v1.1.0 — Practical Commands

- `resume` — restart failed tasks from existing worktree
- `diff` — show changes without attaching
- `pr` — create PR from task branch
- Watch daemon fires on-complete hooks automatically

## v1.0.0 — Milestone Release

ClawForge is feature-complete for single-user agent orchestration.

### Workflow Modes (v0.4)
- `sprint` — single agent, full dev cycle (quick/standard modes)
- `review` — quality gate on existing PRs (+ `--fix`)
- `swarm` — parallel multi-agent orchestration with task decomposition
- Management: `steer`, `attach`, `stop`, `watch --daemon`, `status`

### Observability (v0.5)
- Go TUI dashboard with vim keybindings + ASCII forge animation
- Cost tracking (`cost --summary`)
- Conflict detection (`conflicts --check`)
- Workflow templates (`templates list`)
- CI feedback loop (`--ci-loop`, `--max-ci-retries`)
- Budget caps (`--budget`)
- JSON output + webhook notifications

### Fleet Ops (v0.6)
- Multi-repo swarm (`--repos`, `--repos-file`)
- Model routing strategies (`--routing auto|cheap|quality`)
- Per-repo agent memory (`memory add|show|search|forget`)
- Repo initialization (`init --claude-md`)
- Task history (`history --mode sprint --limit 10`)

### Evaluation (v0.6.2)
- `eval weekly` summaries
- `eval log` for recording outcomes
- `eval compare` for week-over-week analysis

### Reliability (v0.7)
- `doctor` — diagnose orphans, stale tasks, disk, branches (+ `--fix`)
- Signal trap cleanup (SIGINT/SIGTERM)
- Agent watchdog timeout (`--timeout <minutes>`)
- Registry file locking for concurrent writes
- Auto-clean on completion (`--auto-clean`)
- Registry pruning (`clean --prune-days`)
- Merged branch cleanup
- Disk space checks before spawning

### TUI Views (v0.8)
- View modes: all / running / finished (`1`/`2`/`3` + `Tab`)
- Agent nudge (`n`)
- Swarm decomposition timeout guard
- Spawn failure accounting

### Observability v2 (v0.9)
- `logs <id>` — capture agent output from tmux (--follow, --save, --raw)
- `on-complete` — fire webhooks, notifications, auto-clean on task finish
- TUI preview pane (`p` key) — live tmux output for selected agent

## Architecture
- Shell modules in `bin/` with shared `lib/common.sh`
- JSON/JSONL registry state in `registry/`
- Go TUI (Bubble Tea v2 + Lipgloss v2) in `tui/`
- 28 test suites covering all commands
