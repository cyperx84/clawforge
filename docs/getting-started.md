# Getting Started

## Install

### Homebrew (recommended)
```bash
brew tap cyperx84/tap
brew install cyperx84/tap/clawforge
```

### Source
```bash
git clone https://github.com/cyperx84/clawforge.git
cd clawforge
./install.sh --openclaw
```

## Prerequisites
- bash, jq, git, tmux
- gh (authenticated)
- claude and/or codex CLI

## Verify
```bash
clawforge version
clawforge help
```

## First Run
```bash
# from inside any git repo
clawforge sprint "Fix auth bug"
clawforge status
clawforge dashboard
```
