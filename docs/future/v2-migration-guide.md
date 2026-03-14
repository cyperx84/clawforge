# Migration Guide: v1 → v2

ClawForge v2.0 introduces fleet management while maintaining full backward compatibility with v1 coding workflows.

## What's New in v2.0

### Fleet Commands

New commands for managing OpenClaw agent fleets:

| Command | Description |
|---------|-------------|
| `create` | Interactive agent creation wizard |
| `list` | Fleet overview with status |
| `inspect` | Deep view of agent configuration |
| `edit` | Open agent workspace files |
| `bind`/`unbind` | Wire agents to Discord channels |
| `clone` | Duplicate an agent |
| `activate`/`deactivate` | Agent lifecycle management |
| `destroy` | Full agent removal |
| `migrate` | Workspace isolation migration |
| `export`/`import` | Share agents as archives |
| `template` | Manage agent archetypes |
| `compat` | Fleet compatibility check |
| `upgrade-check` | Tool upgrade recommendations |

### Archetypes

5 built-in templates for specialized agents:
- **generalist** — Broad capabilities
- **coder** — Code generation and debugging
- **monitor** — Observation and alerting
- **researcher** — Information gathering
- **communicator** — Clear communication

### clwatch Integration

Optional enrichment for model compatibility tracking and deprecation monitoring.

## Command Mapping

All v1 commands still work. Some are now under the `coding` namespace:

| v1 Command | v2 Equivalent | Notes |
|------------|---------------|-------|
| `clawforge sprint` | `clawforge sprint` or `clawforge coding sprint` | Both work, direct shows deprecation notice |
| `clawforge review` | `clawforge review` or `clawforge coding review` | Both work |
| `clawforge swarm` | `clawforge swarm` or `clawforge coding swarm` | Both work |

### Deprecation Notices

Running `sprint`, `review`, or `swarm` directly shows a brief deprecation notice:

```
ℹ sprint is a legacy coding command. Use 'clawforge coding sprint' for explicit routing.
```

The command still executes. This is informational only.

## Breaking Changes

**None.** All v1 commands, configurations, and workflows continue to work unchanged.

## New Concepts

### Two-Layer Architecture

v2 introduces a two-layer architecture for agent management:

1. **Fleet Registry** (`~/.openclaw/fleet.json`) — Global fleet state
2. **Agent Workspaces** (`~/.openclaw/agents/<name>/`) — Isolated agent files

### Workspace Isolation

Each agent has its own workspace containing:
- `SOUL.md` — Agent identity and behavior
- `IDENTITY.md` — Name, emoji, persona
- `memory/` — Agent-specific memory
- `tools/` — Agent-specific tool configurations

This replaces the shared configuration model from v1.

## Migration Steps

### 1. Update ClawForge

```bash
brew upgrade clawforge
# or
npm update -g @cyperx84/clawforge
```

### 2. Verify Installation

```bash
clawforge version
# Should show v2.0.0
```

### 3. Migrate Existing Agents (Optional)

If you have manually created agents:

```bash
clawforge migrate <agent-name>
```

This moves agent files to isolated workspaces.

### 4. Explore Fleet Commands

```bash
clawforge list
clawforge create --from coder --name my-builder
clawforge inspect my-builder
```

## Compatibility

### What Stays the Same

- All v1 coding workflow commands
- Configuration file format
- Registry structure
- Dashboard and TUI
- Web interface
- All flags and options

### What's Enhanced

- `doctor` now includes Fleet Health and Tool Versions sections
- `create` command now has fleet-focused wizard
- Configuration supports fleet-wide settings

## Getting Help

```bash
clawforge help
clawforge <command> --help
```

For fleet-specific help:
```bash
clawforge create --help
clawforge template list
```
