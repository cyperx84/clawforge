# API Reference

ClawForge is a CLI-first tool, but it is also scriptable. Most automation flows use one or both of these interfaces:

- command execution with `--json` for machine-readable output
- shell scripting against the internal library files in `lib/`

This document covers the stable surfaces that matter when integrating ClawForge into scripts, wrappers, CI jobs, or higher-level tooling.

## 1. Command-line interface (`--json` output)

Many ClawForge commands support `--json` so scripts can parse structured output instead of scraping human-readable text.

Commands with `--json` support:

- `clawforge list --json`
- `clawforge inspect <id> --json`
- `clawforge compat --json`
- `clawforge upgrade-check --json`
- `clawforge export <id> --json`
- `clawforge import <archive> --json`
- `clawforge template list --json`
- `clawforge activate <id> --json`
- `clawforge bind <id> <target> --json`
- `clawforge clone <source> <dest> --json`
- `clawforge deactivate <id> --json`
- `clawforge create ... --json`

Use `--json` whenever ClawForge is being called by:

- CI jobs
- shell scripts
- wrappers in Python, Node, or Go
- agent tooling that needs predictable parsing

### Typical patterns

List all agents:

```bash
clawforge list --json
```

Inspect one agent:

```bash
clawforge inspect builder --json
```

Create an agent and capture the result:

```bash
clawforge create reviewer --from researcher --json
```

Bind an agent programmatically:

```bash
clawforge bind reviewer "#reviews" --json
```

### Parsing with `jq`

Example: get all active agent IDs.

```bash
clawforge list --json | jq -r '.agents[] | select(.active == true) | .id'
```

Example: read a workspace path from `inspect` output.

```bash
clawforge inspect builder --json | jq -r '.workspace'
```

### Notes on output stability

For automation:

- prefer `--json` over text output
- treat human-readable output as operator-facing, not API-stable
- validate expected keys before acting on them
- fail closed if a required field is missing

## 2. Configuration file formats

ClawForge reads from a few key on-disk configuration locations.

### `~/.openclaw/openclaw.json`

This is the main OpenClaw runtime config. ClawForge integrates with it by reading and updating the `agents` array.

Relevant agent fields include:

- `id`
- `model`
- `bindings`
- active status

Typical automation use cases:

- discover which agents are currently active
- correlate ClawForge agent workspaces with OpenClaw runtime entries
- inspect channel or transport bindings

### `config/defaults.json`

This is the project-level defaults file used by ClawForge for fleet defaults.

It includes settings such as:

- `fleet.workspace_root`
- `fleet.default_model`
- `fleet.default_archetype`
- clwatch-related defaults

Example shape:

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

### `~/.clawforge/templates/`

User templates are stored as directories under this path.

Each template contains workspace-style files such as:

- `SOUL.md`
- `AGENTS.md`
- `TOOLS.md`
- `HEARTBEAT.md`

Automation use cases:

- seed templates across machines
- audit which custom archetypes are installed
- sync templates from git

### `config/archetypes/`

This contains the built-in templates bundled with ClawForge.

Use it for:

- enumerating built-in archetypes
- comparing user templates against canonical defaults
- reading baseline files for archetype-aware tooling

Built-ins are protected and should be treated as read-only from normal workflows.

### Export archive format

ClawForge exports agents as `.clawforge` archives.

A valid archive includes a `manifest.json` describing the packaged content.

Automation use cases:

- backup and restore agents
- move agents between hosts
- build repeatable provisioning flows

## 3. Shell library

For bash-based integrations, ClawForge exposes internal helpers in `lib/`. The main entry point for fleet-oriented scripting is:

```bash
source lib/fleet-common.sh
```

This gives scripts direct access to the same helper functions used by the CLI.

### `lib/fleet-common.sh`

Core functions include:

- `_list_agents`
- `_get_agent`
- `_get_workspace`
- `_get_bindings`
- `_validate_agent`
- `_read_openclaw_config`
- `_write_openclaw_config`
- `_substitute_placeholders`
- `_resolve_model_display`
- `_agent_exists_in_config`

These functions are useful when you need to:

- query fleet state without invoking multiple subprocesses
- validate IDs before mutating config
- read and write OpenClaw config safely from shell
- apply the same placeholder substitution logic used by template creation

### `lib/common.sh`

Provides shared logging and dependency helpers.

Logging functions:

- `log_info`
- `log_error`
- `log_warn`
- `log_debug`

Use these in shell integrations to match ClawForge’s own logging style.

This library also contains common dependency-checking helpers used by command implementations.

### `lib/clwatch-bridge.sh`

Provides clwatch integration helpers.

Key functions:

- `_has_clwatch`
- `_get_model_compat`
- `_get_deprecations`
- `_get_tool_versions`

These functions are useful for scripts that need:

- model compatibility checks before provisioning agents
- deprecation warnings during CI or release checks
- local tool version snapshots for support or diagnostics

### Scripting guidance

If you source the shell libraries directly:

- run from the project root or ensure relative paths still resolve
- assume helper names are shell-level functions, not a formal semver API
- pin ClawForge versions in CI if your scripts depend on internal helpers
- prefer CLI `--json` for external integrations and library sourcing for local bash workflows

## 4. Exit codes and error handling

ClawForge uses simple process exit codes:

- `0` — success
- `1` — error

In scripts, always check the command exit status before trusting stdout.

Example:

```bash
if ! clawforge inspect builder --json > /tmp/builder.json; then
  echo "inspect failed" >&2
  exit 1
fi
```

Recommended shell practices:

```bash
set -euo pipefail
```

And for JSON parsing:

- verify the command succeeded first
- then validate the returned JSON with `jq -e`
- handle missing keys explicitly

Example:

```bash
json="$(clawforge list --json)"

echo "$json" | jq -e '.agents' > /dev/null
```

For commands that mutate state:

- validate the target agent exists before acting
- check whether a binding or activation is already present
- treat non-zero exits as authoritative failure, even if partial output was printed

## 5. Integration examples

### Example: list all active agent workspaces

```bash
#!/usr/bin/env bash
set -euo pipefail

clawforge list --json \
  | jq -r '.agents[] | select(.active == true) | .id' \
  | while read -r agent_id; do
      clawforge inspect "$agent_id" --json | jq -r '.workspace'
    done
```

### Example: create and activate an agent if it does not exist

```bash
#!/usr/bin/env bash
set -euo pipefail

agent_id="reviewer"

action_needed="$({ clawforge inspect "$agent_id" --json >/dev/null 2>&1 && echo no; } || echo yes)"

if [[ "$action_needed" == "yes" ]]; then
  clawforge create "$agent_id" --from researcher --json > /tmp/create.json
  clawforge activate "$agent_id" --json > /tmp/activate.json
fi
```

### Example: source fleet helpers directly

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /path/to/clawforge
source lib/common.sh
source lib/fleet-common.sh

if _agent_exists_in_config "builder"; then
  log_info "builder is already active"
else
  log_warn "builder is not active"
fi
```

### Example: gate creation on clwatch compatibility

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /path/to/clawforge
source lib/common.sh
source lib/clwatch-bridge.sh

if _has_clwatch; then
  _get_model_compat "openai-codex/gpt-5.4"
else
  log_warn "clwatch not installed; skipping compatibility check"
fi
```

### Example: enumerate installed templates

```bash
#!/usr/bin/env bash
set -euo pipefail

clawforge template list --json | jq -r '.templates[].name'
```

For most integrations, the best default is:

- use `clawforge ... --json` as the primary interface
- use `jq` for selection and validation
- source `lib/fleet-common.sh` only when you need local shell-level access to internals
