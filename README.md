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

ClawForge v2.1 is a fleet-focused agent manager. Build agents, shape their identity, wire them to channels, deploy fleets — and monitor fleet health.

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
clawforge status
```

---

## Fleet Management

Core fleet commands for creating, configuring, and deploying agents.

| Command | Description |
|---------|-------------|
| `clawforge create <id>` | Interactive agent creation wizard |
| `clawforge create <id> --from <archetype>` | Create from template (non-interactive) |
| `clawforge list` | Fleet overview — all agents with status |
| `clawforge inspect <id>` | Deep view: config, workspace, bindings |
| `clawforge edit <id>` | Edit agent workspace files in $EDITOR |
| `clawforge bind <id> <channel>` | Wire agent to Discord/Telegram/etc |
| `clawforge unbind <id>` | Remove channel binding |
| `clawforge clone <source> <new-id>` | Duplicate an agent |
| `clawforge activate <id>` | Add to config + restart gateway |
| `clawforge deactivate <id>` | Remove from config (keep files) |
| `clawforge destroy <id>` | Full removal (requires `--yes`) |
| `clawforge export <id>` | Package as shareable `.clawforge` archive |
| `clawforge import <path\|url>` | Import from archive |
| `clawforge apply` | Alias for activate |

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

## Fleet Observability

Monitor fleet health, costs, and agent activity.

| Command | Description |
|---------|-------------|
| `clawforge status` | Fleet-aware status dashboard |
| `clawforge status <id>` | Status for a single agent |
| `clawforge cost` | Aggregate token/cost tracking across fleet |
| `clawforge cost <id>` | Costs for a single agent |
| `clawforge cost --today` | Today's costs only |
| `clawforge logs <id>` | View agent conversation logs |
| `clawforge logs <id> --follow` | Stream logs (tail -f style) |
| `clawforge logs <id> --tail 100` | Last 100 lines |

### `clawforge status` — Fleet Dashboard

```
🔨 ClawForge Fleet — 4 agents

 ID          Name        Model              Channel      Status    Memory  Activity
 ───────────────────────────────────────────────────────────────────────────────────
 main        Claw        gpt-5.4            #claw        ● active   42      active
 builder     Builder     gpt-5.4            #builder     ● active   156     active
 researcher  Researcher  gpt-5.4            #researcher  ● active   89      —
 scout       Scout       gpt-5.4            —            ○ created  0       —

 ● = active  ○ = created  ◌ = config-only
```

### `clawforge cost` — Cost Aggregation

```
🔨 ClawForge Fleet Costs (all)

 ID          Name        Input Tokens  Output Tokens  Cost
 ─────────────────────────────────────────────────────────────
 main        Claw        145000        82500          $2.34
 builder     Builder     98000         45200          $1.21
 researcher  Researcher  201000        156800         $4.12
 scout       Scout       12000         8500           $0.28

 TOTAL                    456000        293000         $7.95
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

ClawForge works fully without clwatch. Install it to add compatibility checking, deprecation warnings, and auto-patching.

```bash
brew install cyperx84/tap/clwatch
```

---

## System Health

Diagnose and maintain fleet infrastructure.

```bash
# Full system + fleet health check
clawforge doctor

# Output includes:
# - Agent workspace status (workspace files, memory, heartbeat)
# - Gateway connectivity
# - OpenClaw config validation
# - Tool versions (if clwatch installed)
# - Orphaned workspaces/stale symlinks
```

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
mkdir -p ~/.claude/skills/clawforge
ln -sf "$(pwd)/SKILL.md" ~/.claude/skills/clawforge/SKILL.md
```

---

## Configuration

ClawForge uses two main configuration files:

- **`~/.openclaw/openclaw.json`** — Agent list, models, bindings (managed by ClawForge)
- **`~/.clawforge/config.json`** — User preferences, defaults, and customization

Inspect/edit config:

```bash
clawforge config show        # Display current config
clawforge config edit        # Edit in $EDITOR
clawforge config set <key> <value>
```

---

## Documentation

- **`docs/command-reference.md`** — Detailed command documentation
- **`docs/README.md`** — Architecture and design decisions
- **`CHANGELOG.md`** — Release notes and version history

---

## Support

For bugs, feature requests, or questions:

- GitHub: [cyperx84/clawforge](https://github.com/cyperx84/clawforge)
- Issues: [github.com/cyperx84/clawforge/issues](https://github.com/cyperx84/clawforge/issues)

---

## License

MIT
