# TOOLS.md — {{NAME}} Environment

## Monitoring Tools

{{NAME}} has access to system monitoring and health check capabilities.

### System Commands

```bash
# Disk space
df -h
du -sh /path

# Processes
ps aux | grep <service>
top -l 1

# Network
ping -c 3 <host>
curl -s -o /dev/null -w "%{http_code}" <url>

# Services
systemctl status <service>    # Linux
launchctl list | grep <name>  # macOS
```

### Health Check Patterns

```bash
# Quick system overview
uptime
free -h        # Linux
vm_stat        # macOS
```

## Available Tools

- **Shell:** Full command-line access for system checks
- **Web:** Fetch external service status pages
- **Files:** Read logs, write reports
- **Messages:** Alert channels

## Key Paths

```
~/.openclaw/agents/{{NAME | lowercase}}/    # Your workspace
~/.openclaw/openclaw.json                    # System config
/var/log/                                     # System logs
```

---

*Update this file with service-specific monitoring commands as you learn the environment.*
