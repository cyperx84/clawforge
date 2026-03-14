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
clawforge version    # Should show v2.0.0
clawforge help       # Full command list
clawforge doctor     # Check system health
```

## Fleet Quick Start

The fleet-first workflow: create an agent, inspect it, bind it to a channel, activate it.

```bash
# 1. Create an agent from a template
clawforge create --from coder --name builder --role "Coding specialist" --emoji 🔧

# 2. Inspect to verify
clawforge inspect builder

# 3. Bind to a Discord channel
clawforge bind builder "#builder"

# 4. Activate (adds to OpenClaw config)
clawforge activate builder

# 5. View fleet
clawforge list
```

## Coding Workflow Quick Start

For the legacy coding workflow (sprint/swarm/review):

```bash
# Navigate to any git repo
cd ~/my-project

# Quick task
clawforge coding sprint "Fix auth bug"

# Monitor
clawforge status
clawforge dashboard

# See what changed
clawforge diff 1
clawforge logs 1
```

## OpenClaw Integration

ClawForge works as an OpenClaw skill:
```bash
./install.sh --openclaw
```

This creates the skill at `~/.openclaw/skills/clawforge/` and adds `clawforge` to your PATH.

## Learn More

- [Fleet Management](./fleet-management.md) — Full fleet workflow
- [Archetypes](./archetypes.md) — Agent templates
- [Command Reference](./command-reference.md) — All commands
