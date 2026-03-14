# ClawForge

```text
   ________                ______
  / ____/ /___ __      __ / ____/___  _________ ____
 / /   / / __ `/ | /| / // /_  / __ \/ ___/ __ `/ _ \
/ /___/ / /_/ /| |/ |/ // __/ / /_/ / /  / /_/ /  __/
\____/_/\__,_/ |__/|__//_/    \____/_/   \__, /\___/
                                         /____/
```

**Forge and manage fleets of OpenClaw agents.**

Build agents, shape their identity, wire them to channels, deploy fleets — then run coding workflows or anything else.

## Inspired By

This project was inspired by [Elvis's "OpenClaw + Codex/Claude Code Agent Swarm" workflow](https://x.com/elvissun/article/2025920521871716562) — a battle-tested system for managing a fleet of AI coding agents.

---

## Quick Start

```bash
# 1. Create an agent from a template
clawforge create scout --from monitor --name Scout --role "External monitoring"

# 2. Bind it to a Discord channel
clawforge bind scout "#scout"

# 3. Activate — adds to config and restarts gateway
clawforge activate scout

# Check your fleet
clawforge list
```

---

## Fleet Commands

The primary interface. Everything starts here.

| Command | Description |
|---------|-------------|
| `clawforge create <id>` | Interactive agent creation wizard |
| `clawforge create <id> --from <archetype>` | Create from template (non-interactive) |
| `clawforge list` | Fleet overview — all agents with status |
| `clawforge inspect <id>` | Deep view: config, workspace, bindings |
| `clawforge edit <id> --soul\|--agents\|--tools\|--heartbeat` | Edit workspace files |
| `clawforge bind <id> <channel>` | Wire agent to Discord/Telegram/etc |
| `clawforge unbind <id>` | Remove channel binding |
| `clawforge clone <source> <new-id>` | Duplicate an agent |
| `clawforge activate <id>` | Add to config + restart gateway |
| `clawforge deactivate <id>` | Remove from config (keep files) |
| `clawforge destroy <id>` | Full removal (requires `--yes`) |
| `clawforge export <id>` | Package as shareable `.clawforge` archive |
| `clawforge import <path\|url>` | Import from archive |
| `clawforge migrate` | Workspace isolation migration |
| `clawforge apply` | Alias for activate |
| `clawforge doctor` | Fleet + system health check |
| `clawforge compat` | Fleet-wide model/tool compatibility (via clwatch) |
| `clawforge upgrade-check` | Tool update recommendations (via clwatch) |

### `clawforge list` — Fleet Overview

```
🔨 ClawForge Fleet — 4 agents

 ID          Name        Model              Channel      Status
 ────────────────────────────────────────────────────────────────
 main        Claw        gpt-5.4            #claw        ● active
 builder     Builder     gpt-5.4            #builder     ● active
 researcher  Researcher  gpt-5.4            #researcher  ● active
 scout       Scout       gpt-5.4            —            ○ created

 ● = active   ○ = created (not yet bound/activated)   ◌ = config-only
```

### `clawforge inspect <id>` — Agent DNA

```
🔧 Builder

 Config
 ──────────────────────────────────
 ID:          builder
 Model:       openai-codex/gpt-5.4
 Workspace:   ~/.openclaw/agents/builder/
 Channel:     discord #builder

 Workspace Files
 ──────────────────────────────────
 SOUL.md          3.7 KB  ✓  Coding specialist, direct and practical
 AGENTS.md        3.5 KB  ✓  Boot sequence with dispatch patterns
 HEARTBEAT.md     168 B   ○  Empty
```

---

## Templates & Archetypes

ClawForge ships five built-in archetypes. Use them as starting points:

| Archetype | Best For |
|-----------|----------|
| `generalist` | All-purpose, can orchestrate other agents |
| `coder` | Code-focused, knows Claude Code / Codex dispatch patterns |
| `monitor` | System/external monitoring with periodic health checks |
| `researcher` | Deep research, synthesis, source citation |
| `communicator` | Multi-channel messaging, notification routing |

```bash
# Create from built-in archetype
clawforge create ops --from generalist

# Preview an archetype
clawforge template show coder

# Save an existing agent as a reusable template
clawforge template create my-coder-v2 --from builder

# List all templates (built-in + yours)
clawforge template list

# Delete a user template
clawforge template delete my-coder-v2
```

User templates live at `~/.clawforge/templates/`.  
Built-in archetypes live at `config/archetypes/` in the ClawForge install dir.

---

## Export & Import (Agent Sharing)

Share agents with your team or across machines.

```bash
# Package an agent (skips memory and USER.md by default)
clawforge export builder
# → builder.clawforge in current directory

# Include memory files
clawforge export builder --with-memory

# Skip USER.md (private info)
clawforge export builder --no-user

# Custom output path
clawforge export builder --output ~/share/builder-v2.clawforge

# Import from file
clawforge import builder.clawforge

# Import from URL
clawforge import https://example.com/releases/coder.clawforge

# Non-interactive import
clawforge import coder.clawforge --id my-coder --model anthropic/claude-sonnet-4-6
```

### What's in an archive

```
builder.clawforge (tar.gz)
├── manifest.json   # agent id, name, model, archetype, dates, clawforge version
├── SOUL.md
├── AGENTS.md
├── TOOLS.md
├── IDENTITY.md
├── HEARTBEAT.md
└── references/     # optional context docs
```

Import creates workspace at `~/.openclaw/agents/<id>/`, prompts for ID and model, then shows next steps.

---

## clwatch Integration

When [clwatch](https://github.com/cyperx84/clwatch) is installed, ClawForge gets richer:

```bash
# Fleet-wide model/tool compatibility check
clawforge compat

# Check for tool updates + fleet impact
clawforge upgrade-check

# Expanded doctor with tool version info
clawforge doctor

# Auto-patch agent reference files when tools update
clawforge changelog check --auto
clawforge changelog watch             # daemon: polls every 6h
```

```
Fleet Compatibility Report
────────────────────────────────────
 Agent       Model        Harness Compat    Deprecations
 main        gpt-5.4      codex ✓           none
 builder     gpt-5.4      codex ✓ claude ✓  none
```

ClawForge works fully without clwatch. Install it to add compatibility checking, deprecation warnings, and auto-patching.

```bash
brew install cyperx84/tap/clwatch
```

---

## Coding Workflows

ClawForge provides three primary coding workflow modes for orchestrating AI agents.

```bash
# Sprint — single agent, full dev cycle
clawforge sprint "Add JWT authentication"
clawforge sprint "Fix typo" --quick    # Auto-merge, skip review

# Review — quality gate on existing PR
clawforge review --pr 42

# Swarm — parallel multi-agent orchestration
clawforge swarm "Migrate tests to vitest" --max-agents 4
```

### Quick reference

| Command | Description | Key Flags |
|---------|-------------|-----------|
| `sprint` | Single agent, full dev cycle | `--quick`, `--branch`, `--agent`, `--auto-merge` |
| `review` | Quality gate on PR (analysis only) | `--pr`, `--fix`, `--reviewers` |
| `swarm` | Parallel multi-agent orchestration | `--max-agents`, `--repos`, `--auto-merge` |
| `steer` | Course-correct a running agent | (task ID, message) |
| `attach` | Attach to agent's tmux session | (task ID) |
| `stop` | Stop a running agent | `--yes`, `--clean` |

Full docs: [`docs/workflow-modes.md`](./docs/workflow-modes.md)

---

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
brew update && brew upgrade clawforge
```

### npm / bun

```bash
npm install -g @cyperx84/clawforge
# or
bun install -g @cyperx84/clawforge
```

### uv (Python)

```bash
uv tool install clawforge
uv tool upgrade clawforge   # upgrade
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

### Manual install

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/clawforge" ~/.local/bin/clawforge

# Optional OpenClaw skill wiring
mkdir -p ~/.openclaw/skills/clawforge/scripts
ln -sf "$(pwd)/SKILL.md" ~/.openclaw/skills/clawforge/SKILL.md
ln -sf "$(pwd)/bin/clawforge" ~/.openclaw/skills/clawforge/scripts/clawforge
```

### Prerequisites

- `bash` 4+, `jq`, `git`, `tmux`
- `gh` (GitHub CLI, authenticated) — for coding workflow commands
- `claude` and/or `codex` CLI — for coding workflow commands

---

## Configuration

`config/defaults.json`:

```json
{
  "fleet": {
    "workspace_root": "~/.openclaw/agents",
    "template_dir": "~/.clawforge/templates",
    "default_model": "openai-codex/gpt-5.4",
    "default_archetype": "generalist"
  },
  "clwatch": {
    "auto_check": true,
    "warn_on_deprecations": true,
    "compat_check_on_create": true
  },
  "default_agent": "claude",
  "default_model_claude": "claude-sonnet-4-5",
  "default_model_codex": "gpt-5.3-codex",
  "ci_retry_limit": 2
}
```

---

## Documentation

Full docs in [`docs/`](./docs/README.md):

- [Fleet Management](./docs/fleet-management.md)
- [Archetypes Reference](./docs/archetypes.md)
- [clwatch Integration](./docs/clwatch-integration.md)
- [Coding Workflows](./docs/workflow-modes.md)
- [Migration Guide](./docs/migration-guide.md)
- [Command Reference](./docs/command-reference.md)
- [Dashboard (Go TUI)](./docs/dashboard.md)
- [Architecture](./docs/architecture.md)
- [Configuration](./docs/configuration.md)
- [Troubleshooting](./docs/troubleshooting.md)
- [Changelog](./CHANGELOG.md)

---

## Testing

```bash
./tests/run-all-tests.sh

# Phase 3 specific
./tests/test-fleet-phase3.sh
```
