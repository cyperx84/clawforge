# Custom Archetypes

Archetypes are the reusable blueprints behind ClawForge agents. They let you define an agent’s starting personality, operating rules, tool context, and heartbeat behavior once, then stamp out consistent agents from that template.

ClawForge ships with five built-in archetypes:

- `generalist`
- `coder`
- `monitor`
- `researcher`
- `communicator`

Built-in archetypes live in `config/archetypes/` inside the project. User-defined templates live in `~/.clawforge/templates/<name>/`.

Each archetype is just a directory of workspace files. That makes them easy to read, version, diff, and share.

## 1. What archetypes are

An archetype is a filesystem template used by `clawforge create` when generating a new agent workspace.

When you create an agent from a template, ClawForge:

- copies the template files into the new agent workspace
- substitutes supported placeholders such as `{{NAME}}` and `{{ROLE}}`
- produces a ready-to-activate agent with a consistent starting identity

Use archetypes when you want:

- repeatable agent setups across a fleet
- specialized roles with opinionated defaults
- a quick way to clone successful agent behavior
- shareable agent patterns across machines or teammates

To see what is available:

```bash
clawforge template list
```

To preview a specific template:

```bash
clawforge template show researcher
```

## 2. Anatomy of a template

A template directory contains the same core files as an agent workspace.

Example layout:

```text
~/.clawforge/templates/my-monitor/
├── SOUL.md
├── AGENTS.md
├── TOOLS.md
└── HEARTBEAT.md
```

Built-in templates follow the same structure under `config/archetypes/`.

### `SOUL.md`

Defines the agent’s personality and behavioral boundaries.

Use it for:

- tone and communication style
- what the agent is for
- what the agent should avoid doing
- default posture, preferences, and emphasis

Good `SOUL.md` content makes agents feel distinct instead of interchangeable.

### `AGENTS.md`

Defines how the agent operates session-to-session.

Use it for:

- session startup instructions
- memory loading rules
- dispatch and escalation logic
- collaboration rules with other agents
- guardrails for proactive behavior

This is where you encode operational habits, not personality.

### `TOOLS.md`

Defines tool access context and environment-specific guidance.

Use it for:

- preferred tools or tool order
- local conventions
- installation notes
- service names, paths, and environment quirks
- safe usage patterns

This file should help the agent use its environment correctly without bloating higher-level prompts.

### `HEARTBEAT.md`

Defines what the agent checks during heartbeat runs.

Use it for:

- proactive checklists
- recurring monitoring logic
- what to report versus what to ignore
- rules for quiet periods or escalation thresholds

Keep it focused. Heartbeats should be useful, not noisy.

## 3. Creating from an existing agent

If you already have a well-tuned agent, the fastest path is to save that workspace as a reusable template.

```bash
clawforge template create my-monitor --from sentinel
```

This copies the source agent’s template-relevant files into your user template directory:

```text
~/.clawforge/templates/my-monitor/
```

Typical workflow:

```bash
# Save an existing agent as a new template
clawforge template create my-monitor --from sentinel

# Inspect the saved template
clawforge template show my-monitor

# Use it to create a new agent
clawforge create watcher-2 --from my-monitor
```

This is useful when:

- a production agent has evolved into a good pattern
- you want a team-standard archetype based on real usage
- you need a variant of a built-in template with local conventions baked in

If needed, edit the generated files in `~/.clawforge/templates/my-monitor/` afterward to generalize names, paths, or behavior.

## 4. Building from scratch

You can also create a template manually by making a new directory under `~/.clawforge/templates/`.

Example:

```bash
mkdir -p ~/.clawforge/templates/site-researcher
```

Then create the four core files:

```text
~/.clawforge/templates/site-researcher/
├── SOUL.md
├── AGENTS.md
├── TOOLS.md
└── HEARTBEAT.md
```

Minimal example:

```markdown
# SOUL.md

You are {{NAME}} {{EMOJI}}.

Role: {{ROLE}}

{{ROLE_DESCRIPTION}}

You are precise, skeptical of weak sources, and optimized for research synthesis.
Do not bluff. Show uncertainty clearly.
```

```markdown
# AGENTS.md

## Session startup

1. Read SOUL.md first.
2. Load recent memory before acting.
3. Prefer finding evidence before asking for clarification.

## Dispatch

- Take research and summarization tasks directly.
- Hand off implementation work to coder-oriented agents when needed.
```

```markdown
# TOOLS.md

## Preferred tools

- Web search first for discovery
- Web fetch for readable page extraction
- Browser only when interactive access is required

## Local notes

- Save source links in references/
- Prefer concise research summaries with citations
```

```markdown
# HEARTBEAT.md

On heartbeat:

- check tracked sources for changes
- look for unread mentions or tasks
- report only high-signal changes
- otherwise reply HEARTBEAT_OK
```

Once the files exist, create an agent from the new template:

```bash
clawforge create scout --from site-researcher
```

### Important rules

- User templates live in `~/.clawforge/templates/<name>/`
- Built-in archetypes live in `config/archetypes/`
- Built-in archetypes are protected
- You cannot overwrite or delete built-in archetypes

To remove a user template:

```bash
clawforge template delete site-researcher
```

## 5. Template variables reference

ClawForge supports placeholder substitution inside template files.

Available placeholders:

- `{{NAME}}` — agent name
- `{{ROLE}}` — short role string
- `{{EMOJI}}` — emoji assigned to the agent
- `{{ROLE_DESCRIPTION}}` — longer description of the role
- `{{NAME | lowercase}}` — lowercase form of the agent name, useful in paths or handles

Example usage:

```markdown
# SOUL.md

You are {{NAME}} {{EMOJI}}.

Your role is {{ROLE}}.

{{ROLE_DESCRIPTION}}
```

Lowercase example:

```markdown
Store scratch files under references/{{NAME | lowercase}}/
```

Tips:

- use `{{NAME}}` in visible identity text
- use `{{NAME | lowercase}}` in filesystem paths or normalized identifiers
- keep placeholders human-readable so the raw template still makes sense in git
- avoid hardcoding agent-specific names if the template is meant to be reused

## 6. Testing your archetype

Before relying on a custom archetype, create a disposable agent from it and inspect the generated workspace.

Recommended workflow:

```bash
# Check template is visible
clawforge template list

# Preview the template contents
clawforge template show site-researcher

# Create a test agent
clawforge create test-scout --from site-researcher

# Inspect the generated agent
clawforge inspect test-scout
```

What to verify:

- placeholders were substituted correctly
- tone in `SOUL.md` matches the intended role
- `AGENTS.md` startup rules are clear and non-conflicting
- `TOOLS.md` contains useful local guidance, not stale machine-specific junk
- `HEARTBEAT.md` is actionable and not spammy

If the template is meant for activation in a real fleet, also validate downstream behavior:

```bash
clawforge activate test-scout
```

Then confirm that the agent appears correctly in the fleet and OpenClaw config.

Practical testing advice:

- start from the closest built-in archetype and tighten from there
- keep first versions small
- test one behavior change at a time
- save proven agents back into templates with `template create --from`

## 7. Sharing archetypes

Because archetypes are plain directories of markdown files, they are easy to share through git, archives, or fleet exports.

Common approaches:

- commit template folders to a repo
- copy template directories between machines
- package agents derived from a template and re-import them elsewhere

Useful commands:

```bash
# Export an agent created from a template
clawforge export scout

# Import it on another machine
clawforge import scout.clawforge
```

For direct template sharing, copy the template directory itself:

```bash
~/.clawforge/templates/site-researcher/
```

On the receiving machine, place it under the same user template path and verify it appears:

```bash
clawforge template list
```

A few recommendations for shareable archetypes:

- avoid machine-specific absolute paths unless necessary
- keep environment assumptions in `TOOLS.md`
- prefer generic role wording over project-specific secrets
- include clear heartbeat behavior so operators know what to expect
- version templates in git if they matter operationally

If you want a stable snapshot of a tuned agent, create the template from that agent first, then distribute the template directory or export the resulting agent archive.
