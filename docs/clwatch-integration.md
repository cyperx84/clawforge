# clwatch Integration

ClawForge integrates with [clwatch](https://github.com/cyperx84/clwatch) for enhanced fleet management capabilities.

## What clwatch Provides

clwatch monitors AI tool changelogs and provides:
- **Model compatibility tracking** — Know which models support which features
- **Deprecation monitoring** — Get alerts when tools or models are deprecated
- **Version tracking** — Track installed vs. latest versions of AI tools
- **Capability databases** — Query what models can do

## How ClawForge Uses clwatch

### Agent Creation

When creating agents with `clawforge create`:

1. **Model selection enrichment** — clwatch provides model compatibility info
2. **Deprecation warnings** — Warn if selected model is deprecated
3. **Feature flags** — Know which features the model supports

```bash
clawforge create --from coder
# clwatch enriches the model selection with compatibility data
```

### Fleet Compatibility Check

```bash
clawforge compat
```

Checks the entire fleet for:
- Deprecated models in use
- Missing capabilities for agent roles
- Version mismatches

### Upgrade Recommendations

```bash
clawforge upgrade-check
```

Provides:
- Available tool updates
- Breaking change warnings
- Recommended upgrade paths

### Doctor Enrichment

```bash
clawforge doctor
```

With clwatch, doctor includes:
- **Fleet Health** section — Model deprecations, capability gaps
- **Tool Versions** section — Installed vs. latest versions

## Optional Dependency

**ClawForge works without clwatch.** It's an optional enrichment:

- Without clwatch: Core fleet management works, but no compatibility tracking
- With clwatch: Enhanced model selection, deprecation alerts, version tracking

### Setup

1. Install clwatch:
   ```bash
   brew install cyperx84/tap/clwatch
   ```

2. Run initial sync:
   ```bash
   clwatch sync
   ```

3. ClawForge automatically detects and uses clwatch

### Verification

```bash
clawforge doctor
```

Look for "clwatch: available" in the output.

## Configuration

ClawForge respects these clwatch settings:

- `clwatch_tools` — Tools to monitor (default: claude-code, codex-cli, gemini-cli, opencode)
- `clwatch_interval` — How often to check for updates (default: 6h)

Configure in `~/.clawforge/config.json`:

```json
{
  "clwatch_tools": "claude-code,codex-cli,gemini-cli,opencode",
  "clwatch_interval": "6h"
}
```

## Troubleshooting

### clwatch not detected

```bash
which clwatch
clwatch --version
```

Ensure clwatch is in PATH and executable.

### Outdated compatibility data

```bash
clwatch sync
```

Force refresh the compatibility database.

### Version mismatch warnings

```bash
clawforge upgrade-check
```

See what needs updating and apply recommendations.
