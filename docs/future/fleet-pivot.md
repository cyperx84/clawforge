# ClawForge v2.0 PRD — The Pivot

**From:** Multi-mode coding workflow CLI
**To:** Forge and manage fleets of OpenClaw agents

## The Thesis

ClawForge = Forge Claws. Build agents, shape their identity, deploy fleets. The name was always about this — we just built the wrong thing first.

The coding swarm stuff (sprint/review/swarm) was a workflow layer for Builder. Useful, but narrow. Fleet forging is the platform layer — everyone running OpenClaw needs it, not just coders.

## What Changes

### Core Identity

```
OLD: "Multi-mode coding workflow CLI — from quick patches to parallel agent orchestration"
NEW: "Forge and manage fleets of OpenClaw agents"
```

### Tagline Options

- "Forge your fleet."
- "Build agents. Shape identity. Deploy fleets."
- "The agent fleet forge for OpenClaw."

---

## Command Structure

### Fleet Commands (primary — top level)

```
clawforge create <id>                    # Interactive agent creation wizard
clawforge create <id> --from <archetype> # From template
clawforge list                           # Fleet overview (the new default view)
clawforge inspect <id>                   # Deep view of agent DNA
clawforge edit <id> --soul|--agents|--tools|--heartbeat|--user|--identity
clawforge bind <id> <channel>            # Wire to Discord/Telegram/etc
clawforge unbind <id>                    # Remove channel binding
clawforge activate <id>                  # Validate + add to config + restart
clawforge deactivate <id>               # Remove from config (keep files)
clawforge destroy <id>                   # Full removal (with confirmation)
clawforge clone <source> <new-id>       # Duplicate an agent
clawforge export <id>                    # Package as shareable archive
clawforge import <path|url>              # Import someone's agent archive
clawforge doctor                         # Fleet + system health check
clawforge migrate                        # Workspace isolation migration
clawforge apply                          # Write pending changes to openclaw.json + restart
```

### Template/Archetype Commands

```
clawforge template list                  # Show available archetypes
clawforge template show <name>           # Preview template content
clawforge template create <name>         # Save existing agent as template
clawforge template delete <name>         # Remove template
```

### clwatch Integration Commands

```
clawforge compat                         # Fleet-wide model/tool compatibility check
clawforge compat <id>                    # Single agent compatibility
clawforge upgrade-check                  # Check if agent models/tools need updates
clawforge recommend <id>                 # Model/config recommendations for agent
```

### Legacy Coding Workflow (preserved under namespace)

```
clawforge coding sprint ...              # Was: clawforge sprint
clawforge coding review ...              # Was: clawforge review
clawforge coding swarm ...               # Was: clawforge swarm
clawforge coding attach|steer|stop ...   # Management commands
```

Bare `clawforge sprint` etc. still works in v2.0 with a deprecation notice pointing to `clawforge coding sprint`. Removed in v3.0.

---

## Feature Details

### 1. `clawforge create <id>`

Interactive agent creation wizard.

```
$ clawforge create scout

🔨 Forging new agent: scout

Name [Scout]: Scout
Role (one line): External monitoring and intelligence gathering
Emoji [🔍]: 🔎

Choose archetype:
  1) generalist    — General purpose, can do anything
  2) coder         — Code-focused, dispatch patterns
  3) monitor       — System/external monitoring
  4) researcher    — Deep research and analysis
  5) communicator  — Multi-channel comms
  6) blank         — Empty workspace, define everything yourself
  > 3

Model:
  1) openai-codex/gpt-5.4     (default)
  2) anthropic/claude-sonnet-4-6
  3) anthropic/claude-opus-4-6
  4) zai/glm-5                (free)
  5) custom
  > 1

Can spawn other agents? [y/N]: n
Which agents can spawn this one?
  [x] main (Claw)
  [ ] builder
  [ ] researcher
  [ ] ops
  > (enter to confirm)

Heartbeat tasks? [y/N]: y
  Describe periodic checks (one per line, blank to finish):
  > Monitor RSS feeds for AI news
  > Check Twitter mentions
  >

📁 Created workspace: ~/.openclaw/agents/scout/
📝 Files: SOUL.md, AGENTS.md, TOOLS.md, USER.md, IDENTITY.md, MEMORY.md, HEARTBEAT.md
⚙️  Config entry added (pending apply)

Run 'clawforge bind scout <channel>' to wire a Discord channel.
Run 'clawforge apply' to activate.
```

**Non-interactive mode:**

```bash
clawforge create scout \
  --name Scout \
  --role "External monitoring" \
  --emoji "🔎" \
  --from monitor \
  --model openai-codex/gpt-5.4 \
  --spawnable-by main
```

**clwatch-aware model selection:** When `clwatch` is installed, the model selection step can show compatibility info:

```
Model:
  1) openai-codex/gpt-5.4     (default) — compat: claude-code ✓, codex ✓
  2) anthropic/claude-sonnet-4-6        — compat: claude-code ✓
  3) zai/glm-5                (free)    — compat: unknown
  > 1
```

### 2. `clawforge list`

```
$ clawforge list

🔨 ClawForge Fleet — 4 agents

 ID          Name        Model              Channel      Status
 ────────────────────────────────────────────────────────────────
 main        Claw        gpt-5.4            #claw        ● active
 builder     Builder     gpt-5.4            #builder     ● active
 researcher  Researcher  gpt-5.4            #researcher  ● active
 ops         Ops         gpt-5.4            #ops         ● active
 scout       Scout       gpt-5.4            —            ○ created
 analyst     Analyst     gpt-5.4            —            ◌ config-only

 ● = active (config + workspace + binding)
 ○ = created (workspace exists, not bound/activated)
 ◌ = config-only (no workspace yet)
```

**With `--verbose`:** Also shows model fallbacks, heartbeat interval, subagent permissions, skill filters.

### 3. `clawforge inspect <id>`

```
$ clawforge inspect builder

🔧 Builder

 Config
 ──────────────────────────────────
 ID:          builder
 Model:       openai-codex/gpt-5.4
 Fallbacks:   claude-sonnet-4-6, claude-opus-4-6
 Workspace:   ~/.openclaw/agents/builder/
 Can spawn:   main
 Spawned by:  main
 Skills:      all (no filter)
 Heartbeat:   empty (no periodic tasks)

 Binding
 ──────────────────────────────────
 Channel:     discord #builder (1476433491452498000)
 Mention:     not required

 Workspace Files
 ──────────────────────────────────
 SOUL.md          3.7 KB  ✓  Coding specialist, direct and practical
 AGENTS.md        3.5 KB  ✓  Boot sequence with dispatch patterns
 TOOLS.md         8.6 KB  ✓  Full coding agent reference
 USER.md          481 B   ✓  Basic user info
 IDENTITY.md      635 B   ⚠  Not filled in
 MEMORY.md        496 B   ✓  Initialized
 HEARTBEAT.md     168 B   ○  Empty

 Memory Files:     5 daily logs
 References:       7 context docs

 clwatch (if installed)
 ──────────────────────────────────
 Model compat:    claude-code ✓, codex ✓
 Deprecations:    none affecting this agent
 Tool versions:   claude-code 2.1.76 (current)
```

### 4. `clawforge bind <id> <channel>`

```bash
# Bind to existing Discord channel by name (looks up ID via openclaw config)
clawforge bind scout "#scout"

# Bind by channel ID
clawforge bind scout 1476857455727345818

# Create Discord channel and bind in one step (if OpenClaw message tool available)
clawforge bind scout --create --category "Agent Channels"
```

Adds binding entry to pending config. `clawforge apply` writes it.

### 5. `clawforge export / import`

Export packages an agent as a `.clawforge` archive (tar.gz):

```bash
clawforge export builder
# → builder.clawforge (archive of workspace files + config fragment)

clawforge export builder --no-memory  # Skip memory files (private)
clawforge export builder --no-user    # Skip USER.md (private)
```

Archive contents:
```
builder.clawforge (tar.gz)
├── manifest.json         # Agent metadata, model, archetype source
├── SOUL.md
├── AGENTS.md
├── TOOLS.md
├── IDENTITY.md
├── HEARTBEAT.md
└── references/           # Optional context docs
```

Import unpacks and offers to create:

```bash
clawforge import builder.clawforge
# → Creates workspace, shows config fragment to add
# → Prompts for ID, model, binding

clawforge import https://github.com/someone/their-agent/releases/download/v1/coder.clawforge
# → Download + import
```

### 6. `clawforge template`

Built-in archetypes ship with ClawForge in `config/archetypes/`:

```
config/archetypes/
  generalist/     SOUL.md, AGENTS.md, TOOLS.md, HEARTBEAT.md
  coder/          SOUL.md, AGENTS.md, TOOLS.md, HEARTBEAT.md
  monitor/        SOUL.md, AGENTS.md, TOOLS.md, HEARTBEAT.md
  researcher/     SOUL.md, AGENTS.md, TOOLS.md, HEARTBEAT.md
  communicator/   SOUL.md, AGENTS.md, TOOLS.md, HEARTBEAT.md
```

Templates use `{{PLACEHOLDER}}` substitution:

```markdown
# SOUL.md — {{NAME}}

## Identity

- **Name:** {{NAME}}
- **Role:** {{ROLE}}
- **Emoji:** {{EMOJI}}

## What I Do

{{ROLE_DESCRIPTION}}
...
```

Users can save their own:

```bash
# Save existing agent as reusable template
clawforge template create my-monitor --from ops
# → Saves to ~/.clawforge/templates/my-monitor/

# List all templates (built-in + user)
clawforge template list
# Built-in: generalist, coder, monitor, researcher, communicator
# User:     my-monitor, my-builder-v2
```

### 7. `clawforge migrate`

One-shot migration for workspace isolation:

```bash
$ clawforge migrate

Current layout (nested):
  ~/.openclaw/workspace/agents/builder/
  ~/.openclaw/workspace/agents/researcher/
  ~/.openclaw/workspace/agents/ops/

Proposed layout (isolated):
  ~/.openclaw/agents/builder/
  ~/.openclaw/agents/researcher/
  ~/.openclaw/agents/ops/

This will:
  1. Copy workspace directories to new locations
  2. Update openclaw.json workspace paths
  3. Keep originals as backup (remove with --cleanup)
  4. Restart gateway

Proceed? [y/N]:
```

### 8. `clawforge doctor` (expanded)

Existing doctor checks system health. Expand with fleet + clwatch awareness:

```
$ clawforge doctor

Fleet Health
────────────────────────────────────
✅ Config valid (openclaw.json parses)
✅ 4 agents configured, 4 workspaces found
⚠️  builder: IDENTITY.md not filled in
⚠️  researcher: IDENTITY.md not filled in
⚠️  ops: IDENTITY.md not filled in
✅ All bindings resolve to valid channel IDs
✅ All models have authenticated providers
⚠️  6 agents in config have no workspace (scout, analyst, sentinel, courier, evaluator, creator)
✅ No orphaned workspaces (all have config entries)
✅ Gateway running (port 18789)

Tool Versions (via clwatch)
────────────────────────────────────
✅ claude-code 2.1.76 (current)
✅ codex-cli 0.114.0 (current)
✅ openclaw 2026.3.13 (current)
⚠️  1 deprecation affecting fleet (run 'clawforge compat' for details)

Coding Workflow Health
────────────────────────────────────
✅ tmux available
✅ git available
✅ claude CLI available
✅ codex CLI available
✅ No orphaned tmux sessions
✅ No dangling worktrees
```

---

## clwatch Integration — Deep Dive

clwatch already ships with data that's directly useful for fleet management:

### What clwatch provides

| Data | File | Use in ClawForge |
|:--|:--|:--|
| Model compatibility | `data/compatibility.json` | Which models work with which coding harnesses |
| Model catalog | `data/models/*.json` | Available models per provider with release dates |
| Deprecations | `data/deprecations.json` | Deprecated models/features with migration paths |
| Recommendations | `data/recommendations.json` | Per-harness optimization tips |
| Release tracking | `data/releases/*.json` | Version history per tool |
| Version diffing | `clwatch diff` | Detect when tools update |

### Integration Points

#### 1. Model Selection (`clawforge create`)

When creating an agent, if clwatch is installed, enrich model selection with compatibility data:

```bash
# ClawForge calls:
clwatch compat <model-id>
# → Returns which harnesses support this model

# Or reads directly:
jq '.harnesses | to_entries[] | select(.value.supported | index("claude-sonnet-4-6"))' \
  "$(clwatch --data-dir)/compatibility.json"
```

**Why it matters:** If a user picks a model for their coder agent, ClawForge can warn if that model isn't compatible with their preferred coding harness.

#### 2. Fleet Compatibility Check (`clawforge compat`)

New command that checks all agents against clwatch data:

```
$ clawforge compat

Fleet Compatibility Report
────────────────────────────────────
 Agent       Model              Harness Compat    Deprecations
 ──────────────────────────────────────────────────────────────
 main        gpt-5.4            codex ✓           none
 builder     gpt-5.4            codex ✓ claude ✓  none
 researcher  gpt-5.4            codex ✓           none
 ops         gpt-5.4            codex ✓           none

All agents compatible. No deprecations found.
```

When there IS a problem:

```
 builder     claude-sonnet-4-5  claude ✓ codex ✗  ⚠ model deprecated 2026-04-01
                                                   → migrate to claude-sonnet-4-6
```

#### 3. Doctor Integration (`clawforge doctor`)

Doctor already runs. When clwatch is installed, add a section:

```bash
# Check if clwatch available
if command -v clwatch &>/dev/null; then
  # Run diff to check for tool updates
  clwatch diff --json | jq ...
  # Check deprecations against fleet models
  clwatch deprecations --json | jq ...
fi
```

Graceful degradation — works without clwatch, richer with it.

#### 4. Upgrade Recommendations (`clawforge upgrade-check`)

```
$ clawforge upgrade-check

⚠️  openclaw 2026.3.13 → 2026.3.14 available
    Run: openclaw update

⚠️  claude-code 2.1.74 → 2.1.76 available
    New: autoMemoryDirectory, modelOverrides
    Run: brew upgrade claude-code

✅ codex-cli 0.114.0 (current)
✅ gemini-cli 0.33.1 (current)

Fleet impact:
  builder — uses claude-code, should upgrade for modelOverrides
  all agents — openclaw update recommended
```

#### 5. Reference Auto-Patch (existing `changelog.sh`)

The existing `clawforge changelog` integration already patches Builder's reference files when tools update. This keeps working as-is, but could expand:

- **Today:** Patches `references/claude-code-features.md` etc. in Builder's workspace
- **v2:** Could also patch `TOOLS.md` in any agent that references tool capabilities
- **Hook:** `clawforge changelog check --auto` after `clawforge activate`

### Integration Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     clwatch                               │
│  changelogs.info → manifest → diff/refresh/models/compat │
│                                                           │
│  Data:                                                    │
│  • compatibility.json  (model ↔ harness matrix)          │
│  • deprecations.json   (sunset schedule)                  │
│  • models/*.json       (provider model catalogs)          │
│  • releases/*.json     (version history)                  │
│  • recommendations.json (optimization tips)               │
└───────────────┬──────────────────────────────────────────┘
                │ clwatch CLI + data files
                ▼
┌──────────────────────────────────────────────────────────┐
│                    ClawForge v2                           │
│                                                           │
│  Fleet Commands:                                          │
│    create → uses clwatch compat for model selection       │
│    inspect → shows clwatch compat + deprecation info      │
│    doctor → runs clwatch diff + deprecation checks        │
│    compat → fleet-wide compatibility report               │
│    upgrade-check → what needs updating                    │
│                                                           │
│  Coding Commands (legacy):                                │
│    changelog check/watch → existing clwatch integration   │
│    sprint/review/swarm → reference file patches           │
└───────────────┬──────────────────────────────────────────┘
                │ reads/writes openclaw.json + workspace files
                ▼
┌──────────────────────────────────────────────────────────┐
│                    OpenClaw Gateway                       │
│  agents.list[] → running agents with models/bindings     │
└──────────────────────────────────────────────────────────┘
```

### How clwatch integration stays optional

Every clwatch touchpoint uses the same pattern:

```bash
_has_clwatch() {
  command -v clwatch &>/dev/null
}

# In any command that benefits from clwatch:
if _has_clwatch; then
  # Rich output with compatibility/deprecation info
  compat_info=$(clwatch compat "$model" --json 2>/dev/null || echo "{}")
  ...
else
  # Basic output, no compatibility info
  ...
fi
```

ClawForge works standalone. clwatch makes it smarter.

---

## File Structure

```
clawforge/
  bin/
    clawforge                    # Updated router (fleet commands primary)
    # Fleet commands (new)
    fleet-create.sh
    fleet-list.sh
    fleet-inspect.sh
    fleet-edit.sh
    fleet-bind.sh
    fleet-activate.sh
    fleet-deactivate.sh
    fleet-destroy.sh
    fleet-clone.sh
    fleet-export.sh
    fleet-import.sh
    fleet-migrate.sh
    fleet-apply.sh
    fleet-compat.sh              # clwatch-powered compatibility check
    fleet-upgrade-check.sh       # clwatch-powered upgrade recommendations
    template.sh
    # Existing coding commands (keep as-is, route under 'coding' namespace)
    sprint.sh
    review-mode.sh
    swarm.sh
    attach.sh
    steer.sh
    stop.sh
    ...
  config/
    archetypes/                  # NEW — built-in agent templates
      generalist/
        SOUL.md
        AGENTS.md
        TOOLS.md
        HEARTBEAT.md
      coder/
        SOUL.md
        AGENTS.md
        TOOLS.md
        HEARTBEAT.md
      monitor/
        SOUL.md
        AGENTS.md
        TOOLS.md
        HEARTBEAT.md
      researcher/
        SOUL.md
        AGENTS.md
        TOOLS.md
        HEARTBEAT.md
      communicator/
        SOUL.md
        AGENTS.md
        TOOLS.md
        HEARTBEAT.md
    defaults.json                # Add fleet section
    prompt-templates/
    routing-defaults.json
  lib/
    common.sh                    # Existing shared functions
    fleet-common.sh              # NEW — fleet-specific shared functions
    clwatch-bridge.sh            # NEW — clwatch integration helpers
    templates/
  docs/
    fleet-management.md          # NEW — core fleet docs
    archetypes.md                # NEW — template system reference
    clwatch-integration.md       # NEW — how clwatch augments fleet ops
    migration-guide.md           # NEW — v1 → v2 migration
    ...existing docs...
```

## Config Additions

`config/defaults.json` gains fleet section:

```json
{
  "fleet": {
    "workspace_root": "~/.openclaw/agents",
    "template_dir": "~/.clawforge/templates",
    "default_model": "openai-codex/gpt-5.4",
    "default_archetype": "generalist",
    "auto_bind": false,
    "user_template": "~/.openclaw/workspace/USER.md",
    "openclaw_config": "~/.openclaw/openclaw.json"
  },
  "clwatch": {
    "auto_check": true,
    "warn_on_deprecations": true,
    "compat_check_on_create": true
  }
}
```

---

## Implementation Plan

### Phase 1: Core Fleet Commands (v2.0-alpha)

**Goal:** Create, list, and inspect agents.

1. `lib/fleet-common.sh` — shared functions:
   - `_read_openclaw_config()` — parse openclaw.json
   - `_write_openclaw_config()` — safe write with backup
   - `_list_agents()` — extract agents.list[]
   - `_get_agent()` — get single agent config by ID
   - `_get_workspace()` — resolve agent workspace path
   - `_get_bindings()` — extract bindings for agent
   - `_validate_agent()` — check workspace files exist
2. `lib/clwatch-bridge.sh` — optional clwatch helpers:
   - `_has_clwatch()` — availability check
   - `_get_model_compat()` — model compatibility lookup
   - `_get_deprecations()` — deprecation check
   - `_get_tool_versions()` — current tool versions
3. `bin/fleet-create.sh` — interactive wizard + `--from` archetype + non-interactive flags
4. `bin/fleet-list.sh` — fleet overview table
5. `bin/fleet-inspect.sh` — deep agent view with clwatch enrichment
6. `bin/fleet-activate.sh` + `bin/fleet-apply.sh` — config writes + gateway restart
7. `config/archetypes/` — 5 built-in templates with {{PLACEHOLDER}} substitution
8. Updated main `bin/clawforge` router — fleet commands as top-level
9. Tests for all new commands

### Phase 2: Management Commands (v2.0-beta)

**Goal:** Full lifecycle management.

1. `bin/fleet-edit.sh` — open workspace files in $EDITOR
2. `bin/fleet-bind.sh` + unbind — channel wiring
3. `bin/fleet-clone.sh` — duplicate agent workspace + config
4. `bin/fleet-deactivate.sh` — remove from config, keep files
5. `bin/fleet-destroy.sh` — full removal with confirmation
6. `bin/fleet-migrate.sh` — workspace isolation migration
7. `bin/fleet-compat.sh` — fleet-wide clwatch compatibility report
8. `bin/fleet-upgrade-check.sh` — clwatch-powered upgrade recommendations
9. Expanded `bin/doctor.sh` — fleet health + clwatch sections
10. Tests

### Phase 3: Sharing & Polish (v2.0)

**Goal:** Export/import agents, template management, docs.

1. `bin/fleet-export.sh` — archive creation with manifest.json
2. `bin/fleet-import.sh` — archive unpacking + wizard
3. `bin/template.sh` — list/show/create/delete user templates
4. Updated `README.md` — fleet-first branding
5. Updated `SKILL.md` — fleet commands for OpenClaw integration
6. New docs: fleet-management.md, archetypes.md, clwatch-integration.md, migration-guide.md
7. Deprecation notices on bare sprint/review/swarm

### Phase 4: Legacy Namespace (v2.1)

**Goal:** Clean separation of coding workflow commands.

1. `clawforge coding sprint|review|swarm` namespace routing
2. Bare sprint/review/swarm print deprecation warning + forward
3. Migration guide doc for v1 users
4. Updated help text throughout

---

## What Doesn't Change

- All existing coding workflow commands keep working (v2.0 = deprecation notice, v3.0 = removed)
- `config/defaults.json` coding fields stay
- `lib/common.sh`, `registry/`, `tests/` — untouched
- Homebrew/npm/uv install paths stay the same
- `clawforge doctor`, `clawforge dashboard`, `clawforge status` — keep working
- clwatch remains a separate tool — ClawForge consumes it, doesn't bundle it

---

## Archetype Details

### generalist

The default. Can do anything, no specialization.

**SOUL.md emphasis:** Resourceful, adaptable, orchestrates other agents
**AGENTS.md emphasis:** Read all context files, broad memory protocol
**TOOLS.md emphasis:** General environment reference
**HEARTBEAT.md:** Empty by default (user customizes)

### coder

Code-focused specialist. Knows about coding agents (Claude Code, Codex, etc).

**SOUL.md emphasis:** Direct, practical, show-don't-tell, code quality
**AGENTS.md emphasis:** Dispatch patterns (headless/interactive/cloud), report results
**TOOLS.md emphasis:** Coding agent reference, terminal stack, dev environment
**HEARTBEAT.md:** Empty (coding agents don't need periodic checks typically)

### monitor

System/external monitoring specialist.

**SOUL.md emphasis:** Alert-focused, check-before-act, log everything
**AGENTS.md emphasis:** Monitoring checklist, alert format, escalation protocol
**TOOLS.md emphasis:** System commands, service health checks, monitoring tools
**HEARTBEAT.md:** Pre-populated with health check structure (disk, services, network)

### researcher

Deep research and analysis.

**SOUL.md emphasis:** Thorough, cite sources, synthesize don't summarize, flag uncertainty
**AGENTS.md emphasis:** Research methodology, output formats, handoff protocol
**TOOLS.md emphasis:** Web search, document analysis, vault access
**HEARTBEAT.md:** Empty (research is on-demand)

### communicator

Multi-channel communications.

**SOUL.md emphasis:** Clear messaging, channel-aware formatting, tone matching
**AGENTS.md emphasis:** Message routing, channel preferences, notification protocol
**TOOLS.md emphasis:** Messaging tool configs, channel IDs, formatting rules per platform
**HEARTBEAT.md:** Could include periodic notification checks

---

## Success Criteria

- [ ] `clawforge create test-agent --from generalist` produces working agent in <30 seconds
- [ ] `clawforge list` shows accurate fleet state with status indicators
- [ ] `clawforge inspect <id>` shows complete agent DNA + optional clwatch enrichment
- [ ] `clawforge activate <id>` writes valid config + restarts gateway
- [ ] `clawforge export/import` round-trips an agent successfully
- [ ] `clawforge compat` shows fleet-wide model/tool compatibility (when clwatch installed)
- [ ] `clawforge doctor` covers fleet health + coding health + optional clwatch checks
- [ ] Existing sprint/review/swarm commands work unbroken
- [ ] ClawForge works fully without clwatch (graceful degradation)
- [ ] clwatch enrichment appears when clwatch IS installed

---

## Open Questions

1. **Discord channel auto-creation:** Should `clawforge bind --create` call the Discord API directly, or shell out to OpenClaw's message tool? OpenClaw's tool is more portable (handles auth), but requires a running gateway.

2. **Template sharing ecosystem:** ClawHub exists for skills. Should archetypes live there too? Or separate registry? Could be as simple as GitHub repos with a `manifest.json`.

3. **Multi-gateway fleet:** Managing agents across multiple machines (M4 + M1 + Omarchy). Future scope — v2 targets single gateway. v3 could add `clawforge fleet sync` across Tailscale mesh.

4. **Config manipulation:** Currently using jq to manipulate JSON. OpenClaw has `config.patch` API. Should ClawForge use that when running on same machine as gateway? Probably yes for `apply/activate`, but jq for offline prep.

5. **Archetype versioning:** As OpenClaw evolves, archetype templates may need updates. Should archetypes have version numbers? Probably — just a `version` field in the template manifest.

6. **Agent-to-agent topology visualization:** `clawforge list --graph` or `clawforge topology` showing spawning relationships and channel mappings. Nice-to-have for v2.1.

---

*Version: 2.0 PRD (refined)*
*Author: Claw + CyperX*
*Date: 2026-03-14*
