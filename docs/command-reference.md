# Command Reference

ClawForge v2.1 commands for fleet management and observability.

---

## Fleet Management

### create
Interactive agent creation wizard.

```bash
clawforge create
clawforge create --from coder --name builder --role "Coding specialist" --emoji 🔧
clawforge create --from generalist --name myagent --channel "#general"
```

**Flags:**
- `--from` — Archetype template (generalist, coder, monitor, researcher, communicator)
- `--name` — Agent name
- `--role` — Role description
- `--emoji` — Agent emoji
- `--model` — Default model override
- `--channel` — Discord channel to bind
- `--dry-run` — Preview without creating

---

### list
Fleet overview with status indicators.

```bash
clawforge list              # All agents
clawforge list --verbose    # Include fallbacks, heartbeat, subagent perms
clawforge list --json       # Machine-readable output
```

---

### inspect
Deep view of agent DNA — config, workspace, and bindings.

```bash
clawforge inspect builder
clawforge inspect builder --json
```

---

### edit
Open agent workspace files in `$EDITOR`.

```bash
clawforge edit builder              # Interactive menu
clawforge edit builder soul         # Edit SOUL.md specifically
clawforge edit builder agents
clawforge edit builder tools
clawforge edit builder identity
clawforge edit builder heartbeat
```

---

### bind
Wire agent to a Discord channel.

```bash
clawforge bind builder "#builder"
clawforge bind builder 1234567890
```

---

### unbind
Remove channel binding from an agent.

```bash
clawforge unbind builder
```

---

### clone
Duplicate an agent with all its configuration.

```bash
clawforge clone builder builder-v2
```

---

### activate
Add agent to OpenClaw config and restart gateway.

```bash
clawforge activate builder
clawforge activate builder --no-restart
```

---

### deactivate
Remove agent from active config (agent files still exist).

```bash
clawforge deactivate builder
```

---

### destroy
Full agent removal with safety guards.

```bash
clawforge destroy builder --yes
clawforge destroy builder --yes --keep-workspace
```

---

### apply
Alias for `activate`.

```bash
clawforge apply builder
```

---

## Export & Import

### export (agent)
Package an agent as a `.clawforge` archive for sharing.

```bash
clawforge export builder                              # Create builder.clawforge
clawforge export builder --output ~/backups/builder.clawforge
clawforge export builder --with-memory                # Include memory files
clawforge export builder --no-user                    # Exclude USER.md
```

---

### import
Import an agent from a `.clawforge` archive.

```bash
clawforge import builder.clawforge
clawforge import builder.clawforge --name builder-copy
clawforge import https://example.com/releases/coder.clawforge  # From URL
```

---

## Archetype Management

### template
Manage agent archetypes (templates).

```bash
clawforge template list                 # List all templates
clawforge template show coder           # Preview archetype
clawforge template create my-template   # Save current agent as template
clawforge template delete my-template   # Remove user template
```

User templates live in `~/.clawforge/templates/`.
Built-in archetypes live in `config/archetypes/` in the install directory.

---

## Fleet Observability

### status
Fleet-aware status dashboard showing agent health and activity.

```bash
clawforge status                   # All agents
clawforge status builder           # Single agent
clawforge status --json            # Machine-readable output
```

**Output columns:**
- ID — Agent identifier
- Name — Agent name
- Model — Primary model
- Channel — Discord/Telegram binding
- Status — ● active, ○ created, ◌ config-only
- Memory — Lines in workspace memory/
- Activity — Last activity indicator

---

### cost
Aggregate token/cost tracking across fleet.

```bash
clawforge cost                      # Fleet-wide summary
clawforge cost builder              # Single agent
clawforge cost --today              # Today's costs only
clawforge cost --week               # This week's costs
clawforge cost --json               # Machine-readable output
```

**Output columns:**
- ID — Agent identifier
- Name — Agent name
- Input Tokens — Tokens consumed as input
- Output Tokens — Tokens generated as output
- Cost — Total cost in USD

---

### logs
View agent conversation logs.

```bash
clawforge logs builder              # Last 50 lines
clawforge logs builder --tail 100   # Last 100 lines
clawforge logs builder --follow     # Stream logs (tail -f style, Ctrl+C to stop)
clawforge logs builder --json       # Machine-readable output
```

Reads from:
- OpenClaw session logs if available
- Agent workspace logs
- Agent transcript files

---

## System Health

### doctor
Diagnose fleet and system health.

```bash
clawforge doctor                    # Full diagnostics
clawforge doctor --fix              # Auto-fix detected issues
clawforge doctor --json             # Structured output
```

**Checks:**
- Agent workspace integrity (required files present)
- Config validity (JSON parsing)
- Gateway connectivity
- Tool versions (if clwatch installed)
- Orphaned workspaces and stale symlinks
- Memory/storage usage

---

## Tool Integration

### compat
Fleet-wide model/tool compatibility check (requires clwatch).

```bash
clawforge compat                    # Check all agents
clawforge compat --json             # Machine-readable output
```

**Requires:** `clwatch` installed and running

---

### upgrade-check
Tool update recommendations and fleet impact (requires clwatch).

```bash
clawforge upgrade-check             # Check for updates
clawforge upgrade-check --json      # Machine-readable output
```

**Requires:** `clwatch` installed and running

---

### changelog
Track and auto-patch reference files from tool changelogs.

```bash
clawforge changelog check           # Check for updated changelogs
clawforge changelog check --auto    # Auto-patch agent references
clawforge changelog watch           # Daemon: poll every 6 hours
```

---

## Configuration

### config
Manage ClawForge user configuration.

```bash
clawforge config show               # Display current config
clawforge config get key            # Get single value
clawforge config set key value      # Set value
clawforge config unset key          # Remove key
clawforge config init               # Create default config
clawforge config path               # Show config file location
clawforge config edit               # Edit in $EDITOR
```

Config file: `~/.clawforge/config.json`

---

## Shell Integration

### completions
Install shell tab completions.

```bash
clawforge completions bash          # Install bash completions
clawforge completions zsh           # Install zsh completions
clawforge completions fish          # Install fish completions
```

---

## Meta

### help
Show help and usage.

```bash
clawforge help                      # General help
clawforge help <command>            # Help for specific command
clawforge --help
```

---

### version
Show ClawForge version.

```bash
clawforge version
clawforge --version
clawforge -v
```

---

## Global Flags

- `--verbose` — Enable debug logging on any command

```bash
clawforge list --verbose
clawforge status --verbose
```

---

## Exit Status

- `0` — Success
- `1` — General error (missing required flag, invalid input, etc.)
- `2` — Command-specific error (agent not found, config invalid, etc.)

---

## Environment Variables

- `CLAWFORGE_DEBUG` — Enable debug logging (set by `--verbose` flag)
- `OPENCLAW_CONFIG` — Path to openclaw.json (default: `~/.openclaw/openclaw.json`)
- `OPENCLAW_AGENTS_DIR` — Path to agents directory (default: `~/.openclaw/agents`)
- `OPENCLAW_WORKSPACE` — Legacy workspace directory (default: `~/.openclaw/workspace`)
- `CLAWFORGE_HOME` — User configuration directory (default: `~/.clawforge`)
