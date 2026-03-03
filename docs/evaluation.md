# Evaluation Loop (v0.6.2)

Use evals to track whether ClawForge is improving delivery quality and reliability.

## Data files
- `evals/scorecard.md`
- `evals/run-log.schema.json`
- `evals/run-log.example.jsonl`
- `evals/run-log.jsonl` (generated)

## Logging a run
```bash
clawforge eval log   --command sprint   --mode quick   --repo api   --status ok   --duration-ms 420000   --cost-usd 0.42   --retries 1   --manual 1   --tests-passed true
```

## Weekly summary
```bash
clawforge eval weekly
clawforge eval weekly --week 2026-10
```

## Compare weeks
```bash
clawforge eval compare --week-a 2026-09 --week-b 2026-10
```

## Recommended weekly ritual
1. Log major runs
2. Review weekly summary
3. Update scorecard
4. Pick one reliability fix for next week
