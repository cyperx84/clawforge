# Scenario Playbooks

Use these as copy-paste runbooks for common workflows.

## 1) Small bug fix (fast path)

```bash
clawforge sprint "Fix null pointer in auth middleware" --quick
clawforge status
clawforge history --limit 5
```

When to use: low-risk, localized fix.

## 2) Medium feature (balanced quality)

```bash
clawforge sprint --routing auto "Add JWT refresh token flow"
clawforge watch --daemon
clawforge dashboard
```

When to use: one repo feature with normal review/testing depth.

## 3) Large migration across repos

```bash
clawforge swarm --repos ~/github/api,~/github/web,~/github/shared   "Upgrade auth package v2 to v3"
clawforge conflicts --check
clawforge cost --summary
```

When to use: cross-repo compatibility updates.

## 4) Review and fix PR issues

```bash
clawforge review --pr 42
clawforge review --pr 42 --fix
```

When to use: quality gate with optional auto-remediation.

## 5) Seed memory for a repo

```bash
cd ~/github/api
clawforge init --claude-md
clawforge memory add "Run prisma generate after schema changes"
clawforge memory show
```

When to use: onboarding new repos or adding recurring lessons.

## 6) Weekly eval cadence

```bash
clawforge eval weekly
clawforge eval log --command sprint --mode quick --repo api --status ok --duration-ms 300000
clawforge eval compare --week-a 2026-09 --week-b 2026-10
```

When to use: track reliability and delivery improvements.
