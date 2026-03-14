# Configuration

ClawForge reads configuration from project defaults, user overrides, OpenClaw runtime config, and per-agent workspaces. This document covers the files that define fleet behavior and where each one fits.

## 1. Configuration file locations

Core paths used by ClawForge:

- `config/defaults.json` — bundled fleet defaults
- `config/routing-defaults.json` — bundled routing strategy defaults
- `~/.clawforge/routing.json` — user routing override
- `~/.openclaw/openclaw.json` — main OpenClaw runtime config
- `~/.clawforge/templates/` — user archetypes/templates
- `config/archetypes/` — built-in archetypes
- `registry/active-tasks.json` — currently tracked tasks
- `registry/completed-tasks.jsonl` — append-only completed task history
- `registry/costs.jsonl` — append-only cost log

Agent workspaces are created under the fleet workspace root, which defaults to:

```text
~/.openclaw/agents/
```

A typical agent workspace path looks like:

```text
~/.openclaw/agents/<name>/
```

## 2. Fleet configuration (`defaults.json`)

The main ClawForge defaults file is `config/defaults.json`.

Default structure:

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

### `fleet`

Fleet-level defaults for agent creation and layout.

- `workspace_root`
  - Base directory where agent workspaces are created
  - New agents are typically written under `~/.openclaw/agents/<name>/`

- `template_dir`
  - Path to user-defined templates
  - ClawForge reads custom archetypes from `~/.clawforge/templates`

- `default_model`
  - Model assigned when a command does not specify `--model`
  - Useful for setting a fleet-wide baseline

- `default_archetype`
  - Template used when a command does not specify `--from`
  - Usually set to `generalist`

### `clwatch`

Controls how ClawForge uses clwatch integration.

- `auto_check`
  - Automatically check relevant model/tool data when supported

- `warn_on_deprecations`
  - Surface warnings when selected tooling or models are deprecated

- `compat_check_on_create`
  - Run compatibility checks during agent creation flows

In practice, `defaults.json` acts as the bundled opinionated baseline. If you are packaging or scripting ClawForge for multiple machines, this is the file that defines the default fleet posture.

## 3. OpenClaw config integration (`agents` array)

ClawForge does not operate in isolation. Activation and deactivation integrate with OpenClaw’s main runtime config:

```text
~/.openclaw/openclaw.json
```

This file contains the `agents` array used by OpenClaw at runtime.

Relevant fields include:

- `id`
- `model`
- `bindings`
- active status

Conceptually:

- `clawforge create` creates the workspace and local agent definition
- `clawforge activate` adds the agent into OpenClaw config
- `clawforge deactivate` removes or disables that runtime registration while preserving the workspace

Typical lifecycle:

```bash
clawforge create builder --from coder
clawforge bind builder "#builder"
clawforge activate builder
```

When debugging fleet state, it is useful to distinguish between:

- workspace existence on disk
- presence in `~/.openclaw/openclaw.json`
- whether bindings are configured
- whether the agent is currently active

If an agent exists on disk but is missing from the OpenClaw config, it has been created but not activated.

## 4. Agent workspace structure

Each agent gets its own workspace directory, typically at:

```text
~/.openclaw/agents/<name>/
```

Expected contents:

- `SOUL.md`
- `AGENTS.md`
- `TOOLS.md`
- `IDENTITY.md`
- `HEARTBEAT.md`
- `memory/`
- `references/`

Example layout:

```text
~/.openclaw/agents/builder/
├── SOUL.md
├── AGENTS.md
├── TOOLS.md
├── IDENTITY.md
├── HEARTBEAT.md
├── memory/
└── references/
```

### File roles

- `SOUL.md`
  - personality, communication style, and high-level behavioral boundaries

- `AGENTS.md`
  - session startup rules, memory policy, and dispatch behavior

- `TOOLS.md`
  - tool usage guidance and environment-specific notes

- `IDENTITY.md`
  - explicit agent identity metadata such as name or vibe

- `HEARTBEAT.md`
  - proactive heartbeat behavior and recurring checks

- `memory/`
  - per-agent rolling context and notes

- `references/`
  - durable support material, source files, or local artifacts the agent may use

### Relationship to templates

Built-in archetypes live in:

```text
config/archetypes/
```

User templates live in:

```text
~/.clawforge/templates/
```

A template uses the same style of files, and ClawForge copies them into the workspace during creation.

## 5. Routing configuration

Routing controls how ClawForge chooses between model strategies such as cost-sensitive or quality-oriented execution.

Relevant files:

- `config/routing-defaults.json` — project defaults
- `~/.clawforge/routing.json` — user override

The bundled routing defaults define the standard strategies:

- `auto`
- `cheap`
- `quality`

How to think about them:

- `auto`
  - balanced selection based on the built-in policy

- `cheap`
  - prefer lower-cost execution paths where possible

- `quality`
  - prefer higher-quality execution paths even if cost is higher

The user override file at `~/.clawforge/routing.json` is the place to customize routing behavior without editing project-shipped defaults.

Operational rule of thumb:

- change `config/routing-defaults.json` when changing the packaged baseline
- change `~/.clawforge/routing.json` when customizing behavior for a specific machine or operator
- pass explicit CLI flags when you need one-off overrides

If a command accepts `--model`, that explicit value should be treated as stronger than default routing behavior.

## 6. Registry and memory files

ClawForge stores operational state in `registry/` files.

### Registry files

- `registry/active-tasks.json`
  - current in-progress task state
  - useful for status views, attach flows, and resumable operations

- `registry/completed-tasks.jsonl`
  - append-only history of completed tasks
  - useful for auditing or analytics pipelines

- `registry/costs.jsonl`
  - append-only usage or cost tracking log
  - useful for summaries, billing analysis, and optimization work

Because the `.jsonl` files are append-only logs, they are well suited for:

- shell pipelines
- incremental analysis
- offline cost reporting
- post-run observability tooling

### Agent memory

Within each workspace, the `memory/` directory stores agent-specific context and continuity files.

This is separate from fleet-wide registry state:

- registry files describe operational history across tasks
- workspace memory files describe local context for an individual agent

### Templates and durable reuse

User templates in `~/.clawforge/templates/` sit between defaults and workspaces:

- defaults define global fleet behavior
- templates define reusable agent shapes
- workspaces hold concrete agent instances
- OpenClaw config determines runtime activation

That split is useful when troubleshooting. A problem can come from different layers:

- wrong default model in `config/defaults.json`
- wrong routing override in `~/.clawforge/routing.json`
- wrong template content in `~/.clawforge/templates/`
- wrong runtime registration in `~/.openclaw/openclaw.json`
- wrong local instructions inside an individual agent workspace

If you keep those layers distinct, ClawForge configuration stays predictable and easy to debug.
