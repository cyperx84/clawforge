# BUG: ClawForge overwrites entire openclaw.json, destroying non-agent config

**Severity:** Critical  
**Date:** 2026-03-16  
**Impact:** Two crash loops today, full config loss both times

## Root Cause

`internal/config/config.go` defines `OpenClawConfig` with only two fields:

```go
type OpenClawConfig struct {
    Agents   struct { ... } `json:"agents"`
    Bindings []Binding      `json:"bindings"`
}
```

When `ReadOpenClawConfig()` unmarshals `openclaw.json`, Go silently drops **every field not in the struct**: `channels`, `gateway`, `tools`, `memory`, `auth`, `models`, `plugins`, `hooks`, `session`, `commands`, `meta`, `wizard`, `talk`, `skills` — all gone.

Then `WriteOpenClawConfig()` marshals this stripped struct back and writes it to disk, destroying the entire config.

## What Gets Destroyed

- Discord configuration (token, guilds, 19 channels, DM policy)
- All 9 agent→channel bindings (ironically, because the Binding struct doesn't match the actual config format)
- Gateway mode (`gateway.mode: "local"`) — **this causes the crash loop** because the gateway refuses to start without it
- Memory/qmd backend configuration
- Auth profiles (Anthropic, OpenAI, OpenRouter, Z.AI, Gemini)
- Model providers (Z.AI/GLM)
- Tools configuration (whisper, media models)
- Hooks, session config, plugins
- Everything except agents.list and bindings (which are also broken)

## Timeline (2026-03-16)

1. **~13:10** — First crash: unknown trigger stripped config → crash loop ("gateway.mode unset")
2. **13:37** — Restored from 12:03 backup via config.apply
3. **~14:55** — `clawforge deploy deploy-test` ran, wrote config → stripped everything again
4. **14:56:39** — SIGTERM, crash loop ("gateway.mode unset") — 20+ rapid restart attempts
5. **15:07** — Manually recovered, gateway.mode restored
6. **15:21** — Second full restore from backup

## Fix Required

**Option A (proper fix):** Use `json.RawMessage` to preserve unknown fields:

```go
type OpenClawConfig struct {
    Agents   json.RawMessage `json:"agents"`
    Bindings json.RawMessage `json:"bindings"`
    Extra    map[string]json.RawMessage `json:"-"` // catch-all
}
```

Or better: read into `map[string]interface{}`, modify only the `agents.list` and `bindings` paths, write back.

**Option B (quick fix):** Read file as raw JSON, parse only what's needed, merge changes back into the original JSON before writing.

**Option C (safest):** Use `openclaw config.patch` via CLI/API instead of direct file writes. The gateway handles merge-writes correctly.

## Workaround

Don't use `clawforge deploy/create/destroy` until the config write is fixed. Manage agents via `openclaw` CLI or gateway API directly.
