# HEARTBEAT.md — {{NAME}}

## Periodic Tasks

These checks run on each heartbeat interval:

### System Health
- Check disk space on key volumes (warn at 80%, alert at 90%)
- Check memory usage
- Verify critical services are running

### Network
- Ping key endpoints
- Check DNS resolution

### Logs
- Scan for new errors since last check
- Note any unusual patterns

### Report
- Post summary to channel if issues found
- Log all checks to daily memory file

---

*Customize these checks for your specific environment.*
