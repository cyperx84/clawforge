# Archetypes

Archetypes are templates for creating new agents. They define the starting configuration, identity, and behavioral emphasis for specialized agents.

## Built-in Templates

### Generalist

```bash
clawforge create --from generalist
```

**Emphasis:** Broad capabilities, flexible problem-solving

**Use for:**
- General assistance and Q&A
- Tasks that don't fit other archetypes
- Agents that need to handle varied requests

**Configuration:**
- Balanced model selection
- Minimal behavioral constraints
- Broad tool access

### Coder

```bash
clawforge create --from coder
```

**Emphasis:** Code generation, debugging, implementation

**Use for:**
- Feature implementation
- Bug fixes
- Code review and refactoring
- Technical tasks

**Configuration:**
- Code-focused prompts
- Development tool emphasis
- Technical communication style

### Monitor

```bash
clawforge create --from monitor
```

**Emphasis:** Observation, alerting, status tracking

**Use for:**
- System monitoring
- Event watching
- Status updates
- Alert management

**Configuration:**
- Passive observation mode
- Notification emphasis
- Minimal intervention

### Researcher

```bash
clawforge create --from researcher
```

**Emphasis:** Information gathering, synthesis, reporting

**Use for:**
- Research tasks
- Documentation
- Analysis and summarization
- Knowledge management

**Configuration:**
- Research-oriented prompts
- Information synthesis emphasis
- Detailed output format

### Communicator

```bash
clawforge create --from communicator
```

**Emphasis:** Clear communication, coordination, messaging

**Use for:**
- Channel coordination
- Announcements
- User interaction
- Translation and explanation

**Configuration:**
- Communication-focused prompts
- Clarity emphasis
- Friendly tone

## Creating Custom Templates

### Template Location

Templates live in `~/.clawforge/templates/` or the bundled `config/archetypes/` directory.

### Template Structure

```
my-template/
├── template.json      # Template metadata
├── SOUL.md           # Agent identity (with placeholders)
├── IDENTITY.md       # Optional identity template
└── prompts/          # Optional prompt templates
    └── default.md
```

### template.json

```json
{
  "name": "my-template",
  "description": "Custom template for X",
  "emphasis": "Brief description of specialization",
  "placeholders": ["name", "role", "emoji"]
}
```

### Placeholder Substitution

Templates support `{{PLACEHOLDER}}` syntax:

```markdown
# SOUL.md - {{NAME}}

You are {{NAME}} {{EMOJI}} — {{ROLE}}.

Your emphasis is on [specific behavior].
```

**Available placeholders:**
- `{{NAME}}` — Agent name
- `{{ROLE}}` — Role description
- `{{EMOJI}}` — Agent emoji
- `{{MODEL}}` — Default model
- `{{CHANNEL}}` — Bound channel

### Creating a Template

```bash
clawforge template create my-template
```

This creates a new template directory with starter files.

### Deleting a Template

```bash
clawforge template delete my-template
```

Removes the template (built-in templates cannot be deleted).

## Template Management

### List Templates

```bash
clawforge template list
```

Shows all available templates (built-in and custom).

### Show Template Details

```bash
clawforge template show coder
```

Displays template configuration and file contents.

## Best Practices

1. **Start from built-in templates** — They're battle-tested
2. **One template per specialization** — Don't over-generalize
3. **Use descriptive names** — `api-monitor` is better than `monitor-v2`
4. **Document custom templates** — Include clear descriptions
5. **Test before deploying** — Create a test agent from your template first
