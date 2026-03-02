# ClawForge Installation via uv/pip

This document describes how to install and use ClawForge as a Python package using `uv` (or standard `pip`).

## What is uv?

[uv](https://github.com/astral-sh/uv) is an extremely fast Python package installer and resolver, written in Rust. It's a drop-in replacement for `pip` and `pip-tools` with significantly better performance.

## Prerequisites

- **Python 3.8+**: Required for the Python wrapper
- **Bash**: ClawForge's core implementation is in bash (execution happens via bash scripts)
- **tmux**: Required for agent session management
- **jq**: Required for JSON processing in bash
- **Claude CLI** or **Codex CLI**: The AI agent that ClawForge orchestrates

### Installing Prerequisites

```bash
# macOS (Homebrew)
brew install tmux jq

# Ubuntu/Debian
sudo apt-get install tmux jq

# Install Claude CLI (example)
# Follow instructions from Anthropic
```

## Installation

### Option 1: Install with uv (Recommended)

```bash
# Install uv if you haven't already
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install ClawForge from source
uv pip install git+https://github.com/cyperx84/clawforge.git

# Or install from a local clone
git clone https://github.com/cyperx84/clawforge.git
cd clawforge
uv pip install .

# For development (editable install)
uv pip install -e .
```

### Option 2: Install with pip

```bash
# Install from source
pip install git+https://github.com/cyperx84/clawforge.git

# Or from local clone
git clone https://github.com/cyperx84/clawforge.git
cd clawforge
pip install .
```

### Option 3: Install with uv tool

For isolated installation without affecting your Python environment:

```bash
# Install as a standalone tool
uv tool install git+https://github.com/cyperx84/clawforge.git

# The 'clawforge' command will be available globally
clawforge version
```

## Verification

After installation, verify that ClawForge is accessible:

```bash
# Check version
clawforge version

# Show help
clawforge help

# Check that all components are found
clawforge dashboard
```

## Usage

Once installed, the `clawforge` command is available system-wide:

```bash
# Start a sprint workflow
clawforge sprint "Add JWT authentication middleware"

# Quick fix mode
clawforge sprint "Fix typo in readme" --quick

# Review a PR
clawforge review --pr 42

# Multi-agent swarm
clawforge swarm "Migrate all tests from jest to vitest"

# Check status
clawforge status

# Full dashboard
clawforge dashboard
```

## How It Works

The Python package (`clawforge_py`) is a lightweight wrapper that:

1. Locates the ClawForge bash scripts bundled within the package
2. Executes `bin/clawforge` with all arguments passed through
3. Preserves exit codes, signals, and stdio

The actual functionality is implemented in bash scripts under `bin/` and `lib/`, with the Python wrapper providing convenient package management and installation.

## Updating

```bash
# With uv
uv pip install --upgrade git+https://github.com/cyperx84/clawforge.git

# With pip
pip install --upgrade git+https://github.com/cyperx84/clawforge.git

# With uv tool
uv tool upgrade clawforge
```

## Uninstalling

```bash
# With uv or pip
uv pip uninstall clawforge
# or
pip uninstall clawforge

# With uv tool
uv tool uninstall clawforge
```

## Development Setup

For contributors working on ClawForge:

```bash
# Clone the repository
git clone https://github.com/cyperx84/clawforge.git
cd clawforge

# Install in editable mode with dev dependencies
uv pip install -e ".[dev]"

# Run tests
pytest tests/

# Test the wrapper locally
python -m clawforge_py version
python -m clawforge_py help
```

## Troubleshooting

### "ClawForge bash script not found"

This error means the package was installed without the bash scripts. Ensure:
- You're installing from source (not a partial package)
- The `bin/`, `lib/`, and `config/` directories are present

### "command not found: clawforge"

The installation succeeded but the script isn't in your PATH:
- Check `python -m clawforge_py version` works (it should)
- Ensure your Python scripts directory is in PATH
- Try `uv tool install` instead for isolated global installation

### Permission Issues

If you get permission errors during installation:
```bash
# Use --user flag
pip install --user .

# Or use uv (handles user installs automatically)
uv pip install .
```

## Comparison: uv vs Bash Installation

| Feature | uv/pip Install | Bash Install |
|---------|---------------|--------------|
| Python required | Yes (3.8+) | No |
| Installation method | `uv pip install` | `./install.sh` |
| Global command | `clawforge` | `clawforge` |
| Update mechanism | `uv pip install --upgrade` | `git pull` |
| Uninstall | `uv pip uninstall clawforge` | Manual removal |
| Package management | Yes (via PyPI/git) | No |
| Isolated environments | Yes (venvs, tools) | No |

Both methods provide the same functionality — the Python wrapper simply calls the bash scripts.

## Why Both Distribution Methods?

ClawForge supports both bash-based installation (via `install.sh`) and Python package installation (via uv/pip) to accommodate different workflows:

- **Bash installation**: Direct, minimal dependencies, traditional Unix tool installation
- **Python installation**: Leverages existing Python tooling, easier version management, better isolation

Choose the method that best fits your workflow!
