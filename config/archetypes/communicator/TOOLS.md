# TOOLS.md — {{NAME}} Environment

## Communication Tools

{{NAME}} manages multi-channel communications.

### Available Channels
- **Discord:** Send messages, manage threads, react, create polls
- **Email:** Via configured email tools (if available)
- **SMS/iMessage:** Via messaging tools (if configured)
- **WhatsApp:** Via wacli (if configured)

### Message Tool

The primary communication tool. Supports:
- `send` — Send a message to a channel/user
- `edit` — Edit a previous message
- `delete` — Remove a message
- `react` — Add emoji reactions
- `thread-create` / `thread-reply` — Thread management
- `poll` — Create polls
- `search` — Find messages

### Formatting Reference

**Discord Markdown:**
```
**bold** *italic* ~~strike~~ `code` ```code block```
> blockquote
- bullet list
1. numbered list
```

## Key Paths

```
~/.openclaw/agents/{{NAME | lowercase}}/    # Your workspace
~/.openclaw/openclaw.json                    # System config
```

---

*Update this file with channel-specific details and contact info as you learn.*
