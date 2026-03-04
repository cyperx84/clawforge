# fish completion for clawforge

set -l commands sprint swarm review scope spawn stop steer attach check status \
  cost conflicts merge history eval learn clean templates init routing \
  resume diff pr doctor logs on-complete dashboard config multi-review \
  summary parse-cost profile replay export completions help version

complete -c clawforge -f
complete -c clawforge -n "not __fish_seen_subcommand_from $commands" -a "$commands"

# config subcommands
complete -c clawforge -n "__fish_seen_subcommand_from config" -a "show get set unset init path"

# profile subcommands
complete -c clawforge -n "__fish_seen_subcommand_from profile" -a "list show create delete use"

# Common flags
complete -c clawforge -l repo -d "Repository path" -rF
complete -c clawforge -l branch -d "Branch name" -x
complete -c clawforge -l task -d "Task description" -x
complete -c clawforge -l agent -d "Agent" -xa "claude codex"
complete -c clawforge -l model -d "Model" -x
complete -c clawforge -l effort -d "Effort level" -xa "high medium low"
complete -c clawforge -l timeout -d "Timeout minutes" -x
complete -c clawforge -l after -d "Wait for task" -x
complete -c clawforge -l auto-clean -d "Auto-clean on completion"
complete -c clawforge -l notify -d "Enable notifications"
complete -c clawforge -l dry-run -d "Dry run"
complete -c clawforge -l json -d "JSON output"
complete -c clawforge -l help -d "Show help"
complete -c clawforge -l format -d "Output format" -xa "markdown json text"
complete -c clawforge -l status -d "Status filter" -xa "done failed running all"
complete -c clawforge -l routing -d "Routing strategy" -xa "auto cheap quality"
