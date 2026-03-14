# Getting Started

## Install

### Homebrew (recommended for macOS)
```bash
brew tap cyperx84/tap
brew install clawforge
```

### npm
```bash
npm install -g @cyperx/clawforge
```

### bun
```bash
bun install -g @cyperx/clawforge
```

### uv (Python)
```bash
uv tool install clawforge
```

### pip
```bash
pip install clawforge
```

### Source
```bash
git clone https://github.com/cyperx84/clawforge.git
cd clawforge
./install.sh
```

Options:
```bash
./install.sh --prefix ~/.local     # Custom prefix
./install.sh --openclaw            # Install as OpenClaw skill
./install.sh --uninstall           # Remove
```

## Upgrade

| Method | Command |
|--------|---------|
| Homebrew | `brew upgrade clawforge` |
| npm | `npm update -g @cyperx/clawforge` |
| bun | `bun update -g @cyperx/clawforge` |
| uv | `uv tool upgrade clawforge` |
| pip | `pip install --upgrade clawforge` |
| Source | `git pull && ./install.sh` |

## Prerequisites
- bash, jq, git, tmux
- gh CLI (authenticated via `gh auth login`)
- OpenClaw (for fleet management)
- At least one AI agent: `claude` and/or `codex` (for coding workflows)

## Verify
```bash
clawforge version    # Should show current version (e.g., v1.7.0)
clawforge help       # Full command list
clawforge doctor     # Check system health
```

## Coding Workflow Quick Start

Orchestrate coding agents (Claude Code, Codex) with sprint/review/swarm modes:

```bash
# Navigate to any git repo
cd ~/my-project

# Sprint — single agent, full dev cycle
clawforge sprint "Add JWT authentication"
clawforge sprint "Fix typo" --quick    # Auto-merge, skip review

# Review — quality gate on existing PR
clawforge review --pr 42

# Swarm — parallel multi-agent
clawforge swarm "Migrate tests to vitest" --max-agents 4

# Monitor
clawforge status
clawforge dashboard

# Manage running agents
clawforge attach 1           # Attach to agent's tmux session
clawforge steer 1 "Use bcrypt"  # Course-correct
clawforge stop 1 --yes       # Kill agent
```

## Fleet Management Quick Start

Create and manage OpenClaw agent fleets:

```bash
# Create an agent from a template
clawforge create --from coder --name builder --role "Coding specialist" --emoji 🔧

# Inspect agent config
clawforge inspect builder

# Bind to a Discord channel
clawforge bind builder "#builder"

# Activate (adds to OpenClaw config)
clawforge activate builder

# View fleet
clawforge list
```

## Changelog Tracking (clwatch Integration)

Track AI tool changelogs and auto-patch reference files:

```bash
# Install clwatch first
brew install cyperx84/tap/clwatch

# Check for updates
clawforge changelog check

# Auto-patch without prompting
clawforge changelog check --auto

# Show current versions
clawforge changelog status
```

## OpenClaw Integration

ClawForge works as an OpenClaw skill:
```bash
./install.sh --openclaw
```

This creates the skill at `~/.openclaw/skills/clawforge/` and adds `clawforge` to your PATH.

## Learn More

- [Workflow Modes](./workflow-modes.md) — sprint, review, swarm
- [Fleet Management](./fleet-management.md) — Agent fleet workflow
- [Archetypes](./archetypes.md) — Agent templates
- [Command Reference](./command-reference.md) — All commands
