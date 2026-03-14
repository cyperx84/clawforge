# TOOLS.md — {{NAME}} Environment

## Coding Agents

{{NAME}} can dispatch to coding agents for complex tasks.

### Quick Reference

| Agent | Command | Notes |
|:--|:--|:--|
| Claude Code | `claude --print --permission-mode bypassPermissions "task"` | Headless, no PTY |
| Codex CLI | `codex exec --full-auto "task"` | Needs PTY + git repo |
| Gemini CLI | `gemini -p "task"` | 1M+ context, needs PTY |

### When to Use What

| Task | Approach |
|:--|:--|
| Quick fix | Direct edit |
| Complex feature | Claude Code session |
| Research-heavy build | Gemini CLI |
| Fast parallel batch | Codex per worktree |

## Development Environment

### Key Tools
- **Git:** Small atomic commits, imperative messages
- **Shell:** Full command-line access
- **Package managers:** Homebrew, npm, pip, cargo

### Code Conventions
- No trailing whitespace, newline at EOF
- Meaningful variable names
- Comments explain *why*, not *what*
- Branch naming: `feature/`, `fix/`, `refactor/`

## Key Paths

```
~/.openclaw/agents/{{NAME | lowercase}}/    # Your workspace
~/.openclaw/openclaw.json                    # System config
```

---

*Update this file as you learn more about the environment.*
