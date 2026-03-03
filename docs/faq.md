# FAQ

## Which mode should I use?
- `sprint`: default for most work
- `review`: quality gate for an existing PR
- `swarm`: parallel or multi-repo work

## When should I use `--routing auto`?
When you want cost/quality balance without manually picking models per phase.

## How does memory work?
Per-repo JSONL at `~/.clawforge/memory/<repo>.jsonl`. Top recent memories are injected into prompts.

## Why is history empty?
History entries are produced when tasks are cleaned/archived (`clawforge clean`).

## How do I inspect a running agent?
Use `clawforge dashboard`, then `Enter` to attach or `s` to steer.

## Can I stop a bad run quickly?
Yes: `clawforge stop <id> --yes`.

## What does eval do?
`clawforge eval` logs run outcomes and produces weekly summaries to guide improvements.
