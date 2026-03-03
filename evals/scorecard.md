# ClawForge Evaluation Scorecard

Use this weekly to evaluate whether ClawForge is actually improving delivery.

## Weekly KPI Table

| Week | Lead Time (idea→merge, hrs) | PRs Shipped | Run Success % | Rework % (reopen/revert) | Incidents Post-Merge | Median Run Time (min) | p95 Run Time (min) | Human Time Saved (hrs) | UX Score (1–5) | Notes / Regressions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| YYYY-WW |  |  |  |  |  |  |  |  |  |  |

## Command Reliability (weekly)

| Command | Runs | Success % | Timeout % | Retry Rate % | Median Duration | p95 Duration | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| sprint |  |  |  |  |  |  |  |
| swarm |  |  |  |  |  |  |  |
| review |  |  |  |  |  |  |  |
| dashboard |  |  |  |  |  |  |  |
| memory/init/history |  |  |  |  |  |  |  |

## Gold-Path Scenarios (repeat each week)

1. **Small fix**: `clawforge sprint --quick`
2. **Medium feature**: `clawforge sprint --routing auto`
3. **Cross-repo migration**: `clawforge swarm --repos ...`

Track for each scenario:
- pass/fail
- elapsed time
- manual interventions needed
- quality outcome (review comments / test failures)

## UX Rubric (1–5)

- Discoverability (commands obvious?)
- Recovery (errors actionable?)
- Predictability (same behavior each run?)
- Control (easy steer/stop/override?)
- Cognitive load (how much user has to remember?)

Overall UX Score = average of 5 items.

## Weekly Review Prompt (20 min)

1. What improved this week?
2. What regressed this week?
3. Which one bottleneck should we fix next?
4. Which command generated the most babysitting?
5. One concrete change for next week.
