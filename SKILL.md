---
name: clawforge
description: "Forge and manage fleets of OpenClaw agents. Use when: (1) creating/listing/inspecting agents (create, list, inspect), (2) managing agent lifecycle (bind, activate, deactivate, destroy), (3) sharing agents (export, import), (4) managing templates (template list/show/create), (5) fleet observability (status, cost, logs). NOT for: simple one-liner fixes (just edit), reading code (use read tool)."
metadata:
  {
    "openclaw":
      {
        "emoji": "🔨",
        "requires": { "bins": ["clawforge", "jq"] },
      },
  }
---

# ClawForge v2.1 — Fleet Forge for OpenClaw

## Overview

ClawForge forges and manages fleets of OpenClaw agents. Create, configure, bind, and monitor your agent fleet.

## Fleet Commands

### Create & Inspect

```bash
# Interactive agent creation wizard
clawforge create scout

# From a template/archetype (non-interactive)
clawforge create scout --from monitor --name Scout --role "External monitoring" --emoji "🔎"

# List all agents with status
clawforge list

# Deep view of an agent's config, workspace, and bindings
clawforge inspect builder

# Edit workspace files
clawforge edit builder --soul
clawforge edit builder --agents
clawforge edit builder --tools
clawforge edit builder --heartbeat
```

### Bind & Activate

```bash
# Wire to Discord channel by name
clawforge bind scout "#scout"

# Wire by channel ID
clawforge bind scout 1476857455727345818

# Remove binding
clawforge unbind scout

# Add to OpenClaw config + restart gateway
clawforge activate scout

# Deactivate (remove from config, keep workspace files)
clawforge deactivate scout

# Full removal (with confirmation)
clawforge destroy scout --yes
```

### Clone & Export/Import

```bash
# Duplicate an agent
clawforge clone builder builder-v2

# Package as shareable archive
clawforge export builder                        # builder.clawforge in cwd
clawforge export builder --no-user             # skip USER.md (private)
clawforge export builder --with-memory         # include memory files
clawforge export builder --output ~/share/builder.clawforge

# Import from file or URL
clawforge import builder.clawforge
clawforge import https://example.com/agents/coder.clawforge
clawforge import coder.clawforge --id my-coder --model anthropic/claude-sonnet-4-6
```

### Templates

```bash
# List all templates (built-in archetypes + user templates)
clawforge template list

# Preview template content
clawforge template show coder

# Save an existing agent as a reusable template
clawforge template create my-monitor --from ops

# Delete a user template (built-ins protected)
clawforge template delete my-monitor
```

Built-in archetypes: `generalist`, `coder`, `monitor`, `researcher`, `communicator`

### Health & Diagnostics

```bash
# Fleet + system health check
clawforge doctor

# Fleet-wide model/tool compatibility (requires clwatch)
clawforge compat

# Tool update check + fleet impact (requires clwatch)
clawforge upgrade-check
```

## clwatch Integration

When clwatch is installed, ClawForge gains compatibility checking, deprecation warnings, and auto-patching:

```bash
# One-shot check for tool updates, auto-patch reference files
clawforge changelog check --auto

# Daemon mode — polls every 6h
clawforge changelog watch

# Fleet-wide compatibility report
clawforge compat

# Check for tool updates with fleet impact
clawforge upgrade-check
```

All clwatch features degrade gracefully — ClawForge works without it.

## Fleet Observability

```bash
# Fleet-wide status dashboard
clawforge status

# Single agent status
clawforge status builder

# Cost tracking
clawforge cost
clawforge cost builder --today

# View agent logs
clawforge logs builder
clawforge logs builder --follow
clawforge logs builder --tail 100
```

## Configuration

`config/defaults.json`:

```json
{
  "fleet": {
    "workspace_root": "~/.openclaw/agents",
    "template_dir": "~/.clawforge/templates",
    "default_model": "openai-codex/gpt-5.4",
    "default_archetype": "generalist"
  },
  "clwatch": {
    "auto_check": true,
    "warn_on_deprecations": true,
    "compat_check_on_create": true
  }
}
```
