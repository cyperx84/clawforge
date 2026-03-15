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
- bash, jq, git
- OpenClaw (for fleet management)

## Verify
```bash
clawforge version    # Should show current version (e.g., v2.1.0)
clawforge help       # Full command list
clawforge doctor     # Check system health
```

## Quick Start

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
clawforge status
```

## Fleet Observability

```bash
# Fleet-wide status
clawforge status

# Cost tracking
clawforge cost
clawforge cost --today

# View agent logs
clawforge logs builder
clawforge logs builder --follow
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

- [Fleet Management](./fleet-management.md) — Agent fleet workflow
- [Archetypes](./archetypes.md) — Agent templates
- [Custom Archetypes](./custom-archetypes.md) — Create your own
- [Command Reference](./command-reference.md) — All commands
