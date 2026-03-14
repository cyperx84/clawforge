# Fleet Management

ClawForge manages fleets of OpenClaw agents using a two-layer architecture.

## Architecture

### Layer 1: Agent Registry
- Global fleet configuration at `~/.openclaw/fleet.json`
- Lists all agents with their status, bindings, and configuration
- Single source of truth for what agents exist and their state

### Layer 2: Agent Workspaces
- Each agent has an isolated workspace at `~/.openclaw/agents/<name>/`
- Contains identity (SOUL.md, IDENTITY.md), memory, tools, and agent-specific files
- Workspace isolation prevents agent conflicts and enables clean export/import

## Creating Agents

Use the interactive creation wizard:

```bash
clawforge create
```

The wizard walks you through:
1. **Archetype selection** — Choose a template (generalist, coder, monitor, researcher, communicator)
2. **Name and identity** — Set agent name, role, emoji
3. **Model selection** — Pick default model (with clwatch integration for compatibility)
4. **Channel binding** — Optionally wire to a Discord channel
5. **Activation** — Add to OpenClaw config and restart

### Non-interactive Creation

```bash
clawforge create --from coder --name builder --role "Coding specialist" --emoji 🔧
```

## Managing Agents

### List Fleet

```bash
clawforge list
```

Shows all agents with status indicators:
- `●` active and running
- `○` deactivated
- `✗` error state

### Inspect Agent

```bash
clawforge inspect builder
```

Deep view of agent DNA:
- Configuration (model, role, archetype)
- Workspace contents
- Channel bindings
- Recent activity

### Edit Agent

```bash
clawforge edit builder
```

Opens agent workspace files in `$EDITOR` for direct modification.

### Clone Agent

```bash
clawforge clone builder builder-v2
```

Duplicates an agent with all its configuration and workspace files.

### Bind/Unbind Channels

```bash
clawforge bind builder #general
clawforge unbind builder
```

Wire agents to Discord channels for communication.

### Activate/Deactivate

```bash
clawforge activate builder
clawforge deactivate builder
```

Add or remove agents from OpenClaw's active configuration. Deactivated agents still exist but won't respond to messages.

### Destroy Agent

```bash
clawforge destroy builder
```

Full removal with safety guards:
- Requires `--yes` flag to confirm
- Warns if agent is still active
- Removes workspace, config entries, and bindings

## Workspace Isolation

### Migration

If you have agents created with an older version of ClawForge, migrate them to isolated workspaces:

```bash
clawforge migrate builder
```

This moves agent files from shared directories to `~/.openclaw/agents/<name>/`.

## Export/Import

### Export Agent

```bash
clawforge export builder
```

Creates a `.clawforge` archive containing:
- Agent configuration
- Workspace files
- Memory and logs
- Identity files

### Import Agent

```bash
clawforge import builder.clawforge
```

Restores an agent from an archive. Useful for:
- Sharing agents between machines
- Backing up agent configurations
- Deploying specialized agents

## Fleet Overview

```bash
clawforge status
```

Shows all agents across the fleet with their current state, bindings, and recent activity.

## Best Practices

1. **Use archetypes** — Start from templates rather than creating from scratch
2. **One role per agent** — Specialized agents outperform generalists
3. **Bind to channels** — Agents need communication channels to be useful
4. **Export regularly** — Back up specialized agent configurations
5. **Deactivate, don't destroy** — Keep inactive agents around for later reactivation
