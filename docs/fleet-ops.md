# Fleet Operations (v0.6)

## Multi-repo swarm
Run one swarm task across multiple repos.

```bash
clawforge swarm --repos ~/api,~/web,~/shared "Upgrade auth library"
# or
clawforge swarm --repos-file repos.txt "Add health endpoint"
```

## Model routing
Route models by phase.

```bash
clawforge sprint --routing auto "Refactor auth module"
clawforge swarm --routing cheap "Mechanical migration"
```

Default routing config file:
- `config/routing-defaults.json`

User-level overrides can be set at:
- `~/.clawforge/routing.json`

## Memory system
Per-repo JSONL memory at:
- `~/.clawforge/memory/<repo-name>.jsonl`

Memories are injected into agent prompts (top 20 recent entries).

## Init + History
- `init` seeds first memories from project structure
- `history` reads completed task history
