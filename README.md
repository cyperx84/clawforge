# ClawForge

```text
   ________                ______
  / ____/ /___ __      __ / ____/___  _________ ____
 / /   / / __ `/ | /| / // /_  / __ \/ ___/ __ `/ _ \
/ /___/ / /_/ /| |/ |/ // __/ / /_/ / /  / /_/ /  __/
\____/_/\__,_/ |__/|__//_/    \____/_/   \__, /\___/
                                         /____/
```

**Multi-mode coding workflow CLI** — from quick patches to parallel agent orchestration with Claude Code and Codex.

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

| Method | Command | Best For |
|--------|---------|----------|
| Homebrew | `brew install cyperx84/tap/clawforge` | macOS users (recommended) |
| npm | `npm install -g @cyperx84/clawforge` | Node.js users |
| uv | `uv tool install clawforge` | Python users |
| bun | `bun install -g @cyperx84/clawforge` | Bun users |
| Source | See below | Development |

### Homebrew (recommended for macOS)

```bash
brew tap cyperx84/tap
brew install cyperx84/tap/clawforge
```

Upgrade later:

```bash
brew update
brew upgrade clawforge
```

### npm / bun

```bash
# npm
npm install -g @cyperx84/clawforge

# bun
bun install -g @cyperx84/clawforge
```

Upgrade later:

```bash
npm update -g @cyperx84/clawforge
# or
bun update -g @cyperx84/clawforge
```

### uv (Python)

```bash
uv tool install clawforge
```

Upgrade later:

```bash
uv tool upgrade clawforge
```

### Source install

```bash
git clone https://github.com/cyperx84/clawforge.git
cd clawforge
./install.sh --openclaw
```

That command will:
- symlink `clawforge` into `~/.local/bin`
- wire up `SKILL.md` for OpenClaw
- create missing directories if needed

### Install modes

#### 1) OpenClaw skill mode

```bash
./install.sh --openclaw
```

#### 2) Standalone CLI mode

```bash
./install.sh --standalone
```

#### 3) Custom bin path

```bash
./install.sh --openclaw --bin-dir ~/.bin
```

### Manual install (if you prefer explicit symlinks)

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/clawforge" ~/.local/bin/clawforge

# Optional OpenClaw skill wiring
mkdir -p ~/.openclaw/skills/clawforge/scripts
ln -sf "$(pwd)/SKILL.md" ~/.openclaw/skills/clawforge/SKILL.md
ln -sf "$(pwd)/bin/clawforge" ~/.openclaw/skills/clawforge/scripts/clawforge
```

### Verify install

```bash
clawforge version
clawforge help
```

### Prerequisites

- `bash` (4+), `jq`, `git`, `tmux`
- `gh` (GitHub CLI, authenticated)
- `claude` and/or `codex` CLI


## Documentation

Full docs live in [`docs/`](./docs/README.md):

- [Getting Started](./docs/getting-started.md)
- [Workflow Modes](./docs/workflow-modes.md)
- [Command Reference](./docs/command-reference.md)
- [Scenario Playbooks](./docs/scenarios.md)
- [Dashboard (Go TUI)](./docs/dashboard.md)
- [Architecture](./docs/architecture.md)
- [Fleet Ops](./docs/fleet-ops.md)
- [Evaluation Loop](./docs/evaluation.md)
- [Configuration](./docs/configuration.md)
- [Troubleshooting](./docs/troubleshooting.md)
- [FAQ](./docs/faq.md)
- [Changelog](./CHANGELOG.md)

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

### Fleet Ops (v0.6)

| Command | Description | Key Flags |
|---------|-------------|-----------|
| `memory` | Per-repo agent memory | `show`, `add`, `search`, `forget`, `clear` |
| `init` | Scan project, generate initial memories | `--claude-md` |
| `history` | Show completed task history | `--repo`, `--mode`, `--limit`, `--all` |

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
- **Agent memory** — Per-repo knowledge base injected into agent prompts (max 20 entries)
- **Project init** — Auto-detect language, framework, test runner and seed memories

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

## Changelog Integration (v1.7+)

Track tool changes via clwatch and auto-patch reference files when tool capabilities change. Works standalone without clwatch — ClawForge works standalone. When clwatch is installed.

**Install clwatch:**

```bash
brew install cyperx84/tap/clwatch
```

**Run manually:**
```bash
clawforge changelog check
clawforge changelog status
clawforge changelog ack <tool> <version>  # Mark as reviewed
```

## Changelog

| Tool | clwatch | Version |
|-------|---------------|-------------------|
| claude-code | 2.1.76 | ✓ | ✓ (verified) | **codex-cli** | 0.114.0 | ✓ | ✓ (verified) |
gemini-cli    0.33.1   ✓ | ✓ (verified)
opencode       1.2.26    ✓ | ✓(verified)
openclaw    2026.3.12  ✓ | ✓(verified)

```

**Changelog workflow:**
- **Check:** one-shot check for tool updates ( `clawforge changelog check --auto`
- **watch:** Daemon mode with `--interval 6h` (default)
- **status:** Show known vs current versions for all tools
- **ack:** Mark a tool version as reviewed
- **Run it manually when needed:**
```bash
clawforge changelog check
clawforge changelog status
clawforge changelog ack <tool> <version>
# mark as reviewed
```

## Related
- [Clwatch CLI](https://github.com/cyperx84/clwatch) — consume these payloads
- [changelogs.dev/workflows](https://changelogs.dev/workflows) — workflow guides for multi-tool dev patterns

