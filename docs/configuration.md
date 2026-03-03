# Configuration

## Core config
- `config/defaults.json`

Common fields include default agent/model and operational thresholds.

## Routing config
- `config/routing-defaults.json` (project defaults)
- `~/.clawforge/routing.json` (user override)

Routing strategies:
- `auto`
- `cheap`
- `quality`

`--model` always overrides routing.

## Registry files
- `registry/active-tasks.json`
- `registry/completed-tasks.jsonl`
- `registry/costs.jsonl`
- `registry/conflicts.jsonl`

## Memory files
- `~/.clawforge/memory/<repo-name>.jsonl`

## Version Sync (CI)

When you push a new version tag (`v*`), the `version-sync` GitHub Action automatically updates:
- `VERSION` file
- `package.json` version
- `pyproject.toml` version
- `Formula/clawforge.rb` URL + SHA256

The `publish-npm` and `publish-pypi` workflows run on GitHub releases to push to npm and PyPI respectively.

Required secrets:
- `NPM_TOKEN` — npm publish token (for `@cyperx84/clawforge`)
- `PYPI_TOKEN` — PyPI publish token (for `clawforge`)
