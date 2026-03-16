# PRD: ClawForge Go CLI + TUI

## Goal
Rewrite ClawForge as a single Go binary with bubbletea TUI. Replace 23 bash scripts with a clean, compiled CLI.

## Stack
- **CLI**: Cobra (github.com/spf13/cobra)
- **TUI**: Bubble Tea + Lipgloss + Bubbles (github.com/charmbracelet/bubbletea)
- **JSON**: encoding/json (stdlib)
- **Cross-compile**: goreleaser

## Data Model

### OpenClaw Config (`~/.openclaw/openclaw.json`)
```json
{
  "agents": {
    "list": [
      {
        "id": "builder",
        "model": "openai-codex/gpt-5.4",
        "workspace": "~/.openclaw/agents/builder"
      }
    ]
  },
  "bindings": [
    { "agentId": "builder", "discord": { "channelId": "1476433491452498000" } }
  ]
}
```

### Agent Workspace (`~/.openclaw/agents/<id>/`)
- `SOUL.md`, `AGENTS.md`, `TOOLS.md`, `USER.md`, `IDENTITY.md`, `MEMORY.md`, `HEARTBEAT.md`
- `memory/` — daily logs
- `references/` — reference files

### User Config (`~/.clawforge/config.json`)
```json
{
  "fleet": {
    "default_model": "openai-codex/gpt-5.4",
    "default_archetype": "generalist"
  }
}
```

## Commands

### Fleet Core
| Command | Description |
|---------|-------------|
| `clawforge create <id>` | Interactive agent creation wizard |
| `clawforge create <id> --from <archetype> --name "X" --role "Y" --emoji 🔧` | Non-interactive |
| `clawforge list [--json]` | List all agents |
| `clawforge inspect <id> [--json]` | Deep view of agent |
| `clawforge edit <id> --soul/--agents/--tools/--heartbeat` | Open file in $EDITOR |
| `clawforge clone <src> <dst>` | Duplicate agent |
| `clawforge destroy <id> --yes` | Remove agent |
| `clawforge activate <id>` | Add to OpenClaw config |
| `clawforge deactivate <id>` | Remove from config |
| `clawforge bind <id> <channel>` | Wire to Discord |
| `clawforge unbind <id>` | Remove binding |
| `clawforge export <id> [--output file.clawforge]` | Package as tarball |
| `clawforge import <file.clawforge> [--id <id>]` | Import agent |

### Observability
| Command | Description |
|---------|-------------|
| `clawforge status [id] [--json]` | Fleet health dashboard |
| `clawforge cost [id] [--today/--week] [--json]` | Cost tracking |
| `clawforge logs <id> [--follow] [--tail N] [--json]` | View logs |

### Templates
| Command | Description |
|---------|-------------|
| `clawforge template list` | List archetypes |
| `clawforge template show <name>` | Preview template |
| `clawforge template create <name> --from <agent>` | Save as template |
| `clawforge template delete <name>` | Remove template |

### Config & Utils
| Command | Description |
|---------|-------------|
| `clawforge config [key] [value]` | View/set config |
| `clawforge doctor` | System health check |
| `clawforge completions bash/zsh/fish` | Shell completions |
| `clawforge version` | Print version |
| `clawforge help` | Help |

### Changelog (clwatch integration)
| Command | Description |
|---------|-------------|
| `clawforge changelog check [--auto]` | Check for tool updates |
| `clawforge changelog status` | Show current versions |
| `clawforge changelog watch` | Daemon mode |

## TUI

### Entry
`clawforge tui` — Launch interactive dashboard

### Screens

1. **Fleet Overview** (default)
   - Table: ID, Name, Model, Channel, Status, Memory, Activity
   - Keybinds: `c` create, `d` destroy, `enter` inspect, `q` quit

2. **Agent Detail**
   - Config summary
   - Workspace file status
   - Recent logs (last 10 lines)
   - Keybinds: `e` edit, `b` bind, `a` activate, `esc` back

3. **Create Agent**
   - Form: ID, Name, Role, Emoji, Model, Archetype
   - Preview generated files

4. **Cost Dashboard**
   - Bar chart: costs by agent
   - Total, today, week toggles

5. **Log Viewer**
   - Scrollable log output
   - Filter by agent

### Keybinds (global)
- `q` / `ctrl+c` — quit
- `?` — help
- `1-5` — switch screens
- `/` — search/filter

## Project Structure

```
clawforge/
├── cmd/
│   ├── root.go           # Entry point
│   ├── create.go         # fleet create
│   ├── list.go           # fleet list
│   ├── inspect.go        # fleet inspect
│   ├── edit.go           # fleet edit
│   ├── clone.go          # fleet clone
│   ├── destroy.go        # fleet destroy
│   ├── activate.go       # fleet activate
│   ├── deactivate.go     # fleet deactivate
│   ├── bind.go           # fleet bind/unbind
│   ├── export.go         # fleet export
│   ├── import.go         # fleet import
│   ├── status.go         # observability status
│   ├── cost.go           # observability cost
│   ├── logs.go           # observability logs
│   ├── template.go       # template commands
│   ├── config.go         # config commands
│   ├── doctor.go         # diagnostics
│   ├── completions.go    # shell completions
│   ├── changelog.go      # clwatch integration
│   └── tui.go            # TUI entry
├── internal/
│   ├── config/
│   │   └── config.go     # Config loading/saving
│   ├── fleet/
│   │   ├── agent.go      # Agent struct + CRUD
│   │   ├── workspace.go  # Workspace file management
│   │   ├── bindings.go   # Channel bindings
│   │   └── archetype.go  # Built-in archetypes
│   ├── observability/
│   │   ├── status.go     # Fleet status
│   │   ├── cost.go       # Cost tracking
│   │   └── logs.go       # Log reading
│   ├── changelog/
│   │   └── clwatch.go    # clwatch integration
│   └── tui/
│       ├── app.go        # Bubbletea app
│       ├── fleet.go      # Fleet overview screen
│       ├── detail.go     # Agent detail screen
│       ├── create.go     # Create agent form
│       ├── cost.go       # Cost dashboard
│       └── logs.go       # Log viewer
├── pkg/
│   └── version/
│       └── version.go    # Version info
├── archetypes/
│   ├── generalist.yaml
│   ├── coder.yaml
│   ├── monitor.yaml
│   ├── researcher.yaml
│   └── communicator.yaml
├── main.go
├── go.mod
├── go.sum
├── Makefile
├── .goreleaser.yml
└── README.md
```

## Build & Release

### Makefile
```makefile
build:
	go build -o bin/clawforge .

test:
	go test ./... -v

lint:
	golangci-lint run

install: build
	cp bin/clawforge /usr/local/bin/

release:
	goreleaser release --rm-dist
```

### goreleaser
- Build for: darwin (amd64/arm64), linux (amd64/arm64), windows (amd64)
- Archive: tar.gz with README, LICENSE
- Homebrew: update `cyperx84/homebrew-tap`

## Migration Path

1. **Phase 1: Core Fleet** — create, list, inspect, destroy, activate, deactivate, bind
2. **Phase 2: Observability** — status, cost, logs
3. **Phase 3: Templates** — template list/show/create
4. **Phase 4: TUI** — all screens
5. **Phase 5: Config & Utils** — config, doctor, completions
6. **Phase 6: Changelog** — clwatch integration

## Testing

- Unit tests for all internal packages
- Integration tests against temp `~/.openclaw` directory
- TUI snapshot tests (optional)

## Success Criteria

- [ ] All 23 bash commands ported
- [ ] TUI with 5 screens working
- [ ] Tests pass
- [ ] goreleaser builds for all platforms
- [ ] Homebrew formula updated
- [ ] Docs updated

## Constraints

- Zero external deps at runtime (static binary)
- Bash scripts removed after Go binary ships
- Backwards compatible with existing `~/.openclaw` structure
