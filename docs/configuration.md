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
