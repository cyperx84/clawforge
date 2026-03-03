# ClawForge v0.6 PRD — Fleet Operations (Atomic)

Keep it simple. Each feature is one file + one flag. No over-engineering.

## Repo: ~/.openclaw/workspace/clawforge
## Branch: feat/v06-fleet-operations

## Feature 1: Multi-Repo Swarm (`--repos` flag on swarm)

### What it does
`clawforge swarm --repos ~/api,~/web,~/shared "Upgrade auth v2 to v3"`

- `--repos <comma-separated-paths>` flag on swarm command
- `--repos-file <path>` reads repo paths from a file (one per line)
- For each repo: creates a worktree, spawns an agent with repo-specific context
- Agent prompt includes: "You are working on repo: <name>. Other repos in this task: <list>"
- Each repo gets its own sub-task ID: #5.api, #5.web, #5.shared
- Status/dashboard groups by parent task
- Each agent creates a PR in its own repo
- That's it. No campaigns, no rollout phases, no repo contracts.

### Implementation
- Modify bin/swarm.sh:
  - Parse --repos and --repos-file flags
  - If --repos provided, skip scope decomposition — one agent per repo
  - Pass repo path to spawn-agent.sh
  - Track all agents under one parent task ID
- Modify bin/scope-task.sh:
  - When multiple repos, generate one sub-task per repo with repo-aware context
- Update registry/active-tasks.json format to include repo field
- Add test: tests/test-multi-repo.sh

## Feature 2: Model Routing (`routing.json` + `--routing` flag)

### What it does
```json
// ~/.clawforge/routing.json
{
  "scope": "haiku",
  "implement": "sonnet", 
  "review": "opus",
  "ci-fix": "haiku"
}
```

`clawforge sprint --routing auto "Add auth middleware"`

- `--routing auto` uses ~/.clawforge/routing.json
- `--routing cheap` uses cheapest model for all phases
- `--routing quality` uses best model for all phases
- `--model` still overrides everything
- Default: no routing (uses whatever model the agent defaults to)
- Sprint phases: scope → implement → review → ci-fix
- Each phase passes --model flag to the claude/codex invocation

### Implementation
- New file: bin/routing.sh (< 80 lines)
  - load_routing(strategy) — reads config, returns model per phase
  - get_model_for_phase(phase) — returns model string
- Modify bin/sprint.sh and bin/swarm.sh:
  - Parse --routing flag
  - Before each phase, call get_model_for_phase
  - Pass model to agent spawn
- Ship default routing.json in config/routing-defaults.json
- Add test: tests/test-routing.sh

## Feature 3: Agent Memory (JSONL per repo)

### What it does
```bash
clawforge memory                           # show stats
clawforge memory show                      # list all memories for cwd repo
clawforge memory add "Always run prisma generate after schema changes"
clawforge memory search "prisma"           # grep memories
clawforge memory forget --id <id>          # remove one
clawforge memory clear                     # wipe repo memory
```

Storage: `~/.clawforge/memory/<repo-name>.jsonl`
Each line: `{"id":"uuid","text":"...","tags":["ci","prisma"],"created":"ISO","source":"manual|learn|ci-fail"}`

### Implementation
- New file: bin/memory.sh (< 150 lines)
  - Subcommands: show, add, search, forget, clear
  - Detect repo name from cwd git remote or dirname
  - JSONL append for add, grep for search, jq filter for forget
- Modify bin/spawn-agent.sh:
  - Before spawning, load memories for current repo
  - Inject into agent prompt as "## Project Notes\n<memories>"
  - Max 20 most recent memories (keep prompt lean)
- Modify bin/learn.sh:
  - After learn capture, also append to memory JSONL with source=learn
- Add test: tests/test-memory.sh

## Feature 4: Init Command (`clawforge init`)

### What it does
```bash
cd ~/my-project
clawforge init
# → Scans repo structure
# → Generates ~/.clawforge/memory/<repo>.jsonl with initial observations
# → Outputs summary
```

- Detects: language, framework, test runner, build tool, package manager
- Detection is simple: check for package.json, Cargo.toml, go.mod, pyproject.toml, Makefile, etc.
- Generates initial memory entries: "Node.js project", "Uses vitest for tests", "Has CI at .github/workflows/"
- Optionally creates CLAUDE.md if missing (--claude-md flag)
- That's it. No RAG, no embeddings, no AST parsing.

### Implementation
- New file: bin/init.sh (< 100 lines)
  - file-existence checks for common project files
  - Parse package.json for scripts.test, scripts.build etc
  - Write observations to memory JSONL
  - Print summary to terminal
- Add test: tests/test-init.sh

## Feature 5: History Command (`clawforge history`)

### What it does
```bash
clawforge history                    # last 10 runs
clawforge history --all              # all runs
clawforge history --repo api         # filter by repo
clawforge history --mode swarm       # filter by mode
```

### Implementation
- New file: bin/history.sh (< 80 lines)
  - Reads registry/completed-tasks.jsonl (new file)
  - Columns: Date | Mode | Task | Status | Duration | Cost | PR
  - Filters: --repo, --mode, --limit (default 10)
- Modify bin/clean.sh:
  - After cleaning a completed task, append to completed-tasks.jsonl
- Add test: tests/test-history.sh

## Testing
- Add 5 new test files
- Target: all existing + new tests pass
- Keep test style consistent with existing

## Version
- Bump VERSION to 0.6.0
- Update README
