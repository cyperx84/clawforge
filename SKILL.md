---
name: clawforge
description: "Forge and manage fleets of OpenClaw agents. Use when: (1) creating/listing/inspecting agents (create, list, inspect), (2) managing agent lifecycle (bind, activate, deactivate, destroy, deploy), (3) sharing agents (export, import), (4) fleet observability (status, cost, logs, health), (5) fleet sync and drift detection, (6) comparing agents (diff). NOT for: editing individual agent files (use read/edit tools directly)."
metadata:
  {
    "openclaw":
      {
        "emoji": "🔨",
        "requires": { "bins": ["clawforge"] },
      },
  }
---

# ClawForge v3.1 — Fleet Forge for OpenClaw

## Overview

ClawForge is a single Go binary for managing fleets of OpenClaw agents. No dependencies required.

Install: `brew install cyperx84/tap/clawforge`

## Fleet Commands

```bash
# Create agent from archetype
clawforge create <id> --from coder --name "Name" --role "Role" --emoji 🔧

# One-shot: create + bind + activate + gateway restart
clawforge deploy <id> --from coder --name "Name" --role "Role" --channel <discord-channel-id>

# List all agents
clawforge list
clawforge list --json

# Deep inspect
clawforge inspect <id>
clawforge inspect <id> --json

# Edit workspace files in $EDITOR
clawforge edit <id> --soul
clawforge edit <id> --agents
clawforge edit <id> --tools

# Duplicate an agent
clawforge clone <src> <dst>

# Remove agent
clawforge destroy <id>

# Activate/deactivate in OpenClaw config
clawforge activate <id>
clawforge deactivate <id>

# Bind to Discord channel
clawforge bind <id> <channel-id>
clawforge unbind <id>

# Export/import agents
clawforge export <id>
clawforge import <file.clawforge>
```

## Observability

```bash
# Fleet status dashboard
clawforge status
clawforge status <id>
clawforge status --json

# Live agent health (sessions, heartbeat, errors)
clawforge health
clawforge health <id>
clawforge health --json

# Cost tracking
clawforge cost
clawforge cost --today
clawforge cost --week

# View logs
clawforge logs <id>
clawforge logs <id> --tail 50
clawforge logs <id> --follow
```

## Fleet Maintenance

```bash
# Detect drift between disk agents and openclaw.json
clawforge sync
clawforge sync --fix        # Auto-add disk agents to config
clawforge sync --json

# Compare two agents
clawforge diff <id1> <id2>
clawforge diff <id1> <id2> --files   # Include workspace file diffs

# System health check
clawforge doctor

# Remote fleet management (SSH)
clawforge remote add prod user@host
clawforge remote list
clawforge remote status prod
```

## Templates

```bash
clawforge template list
clawforge template show coder
clawforge template create my-template --from builder
clawforge template delete my-template
```

Built-in archetypes: `generalist`, `coder`, `monitor`, `researcher`, `communicator`

## Config

```bash
clawforge config                    # Show all config
clawforge config key value          # Set a value
```

Config file: `~/.clawforge/config.json`

## MCP Server (for Claude Code / AI clients)

ClawForge exposes an MCP server so AI coding agents can manage fleets as tools.

### Configure in Claude Code

Add to `~/.claude/mcp_servers.json`:
```json
{
  "clawforge": {
    "command": "clawforge",
    "args": ["mcp"],
    "description": "Fleet management for OpenClaw agents"
  }
}
```

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `fleet_list` | List all agents |
| `fleet_status` | Fleet health dashboard |
| `fleet_deploy` | Create + bind + activate an agent |
| `fleet_inspect` | Deep inspect a single agent |
| `fleet_health` | Live health metrics |
| `fleet_sync` | Detect/fix config drift |
| `fleet_logs` | View agent logs |
| `fleet_diff` | Compare two agents |

### Example MCP usage (from Claude Code)

```
Use the clawforge MCP to deploy a new researcher agent:
- id: science-scout
- from: researcher
- name: Science Scout
- role: Track scientific papers and breakthroughs
- emoji: 🔬
```

## OpenClaw Paths

| Path | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Main config (agents list + bindings) |
| `~/.openclaw/agents/<id>/` | Agent workspace directories |
| `~/.clawforge/config.json` | ClawForge user config |
| `~/.clawforge/remotes.json` | Remote instance config |

## Key Constraints

- `deploy`/`create` never write `role` or `emoji` to `openclaw.json` (causes validation errors)
- Role/emoji live in workspace SOUL.md only
- `destroy` removes from config AND deletes workspace directory
- `sync --fix` adds disk agents to config but does NOT restart gateway (run `openclaw gateway restart` manually)
