# ClawForge Fleet Scorecard

Weekly health check for your agent fleet.

## Fleet Health (weekly)

| Week | Agents Active | Agents Created | Agents Destroyed | Channel Issues | Model Errors | Notes |
|------|:---:|:---:|:---:|:---:|:---:|------|
| YYYY-WW | | | | | | |

## Agent Reliability

| Agent | Uptime % | Errors/Week | Channel Health | Model | Notes |
|-------|:---:|:---:|:---:|:---:|------|
| main | | | | | |
| builder | | | | | |

## Gold-Path Checks (run weekly)

1. `clawforge list` — fleet overview renders correctly
2. `clawforge status` — all active agents show health
3. `clawforge doctor` — no critical issues
4. `clawforge create test-agent --from generalist --no-interactive` — agent creation works
5. `clawforge destroy test-agent --yes` — cleanup works

## Notes

Track issues, regressions, or observations here.
