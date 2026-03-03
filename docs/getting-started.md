# Getting Started

## Install

### Homebrew (recommended for macOS)
```bash
brew tap cyperx84/tap
brew install clawforge
```

### npm
```bash
npm install -g @cyperx84/clawforge
```

### bun
```bash
bun install -g @cyperx84/clawforge
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
| npm | `npm update -g @cyperx84/clawforge` |
| bun | `bun update -g @cyperx84/clawforge` |
| uv | `uv tool upgrade clawforge` |
| pip | `pip install --upgrade clawforge` |
| Source | `git pull && ./install.sh` |

## Prerequisites
- bash, jq, git, tmux
- gh CLI (authenticated via `gh auth login`)
- At least one coding agent: `claude` and/or `codex`

## Verify
```bash
clawforge version    # Should show v1.1.0
clawforge help       # Full command list
clawforge doctor     # Check system health
```

## First Run
```bash
# Navigate to any git repo
cd ~/my-project

# Quick task
clawforge sprint "Fix auth bug" --quick

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
