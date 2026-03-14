# fish completion for clawforge

# Fleet commands + legacy coding commands
set -l commands create list inspect edit bind unbind clone activate deactivate destroy \
  migrate export import template compat upgrade-check coding \
  sprint swarm review scope spawn stop steer attach check status \
  cost conflicts merge history eval learn clean templates init routing \
  resume diff pr doctor logs on-complete dashboard config multi-review \
  summary parse-cost profile replay export completions help version

complete -c clawforge -f
complete -c clawforge -n "not __fish_seen_subcommand_from $commands" -a "$commands"

# Fleet command descriptions
complete -c clawforge -n "__fish_seen_subcommand_from create" -a "Create a new agent"
complete -c clawforge -n "__fish_seen_subcommand_from list" -a "Fleet overview"
complete -c clawforge -n "__fish_seen_subcommand_from inspect" -a "Deep view of agent DNA"
complete -c clawforge -n "__fish_seen_subcommand_from edit" -a "Open agent workspace files"
complete -c clawforge -n "__fish_seen_subcommand_from bind" -a "Wire agent to Discord channel"
complete -c clawforge -n "__fish_seen_subcommand_from unbind" -a "Remove channel binding"
complete -c clawforge -n "__fish_seen_subcommand_from clone" -a "Duplicate an agent"
complete -c clawforge -n "__fish_seen_subcommand_from activate" -a "Add agent to config and restart"
complete -c clawforge -n "__fish_seen_subcommand_from deactivate" -a "Remove agent from config"
complete -c clawforge -n "__fish_seen_subcommand_from destroy" -a "Full removal of agent"
complete -c clawforge -n "__fish_seen_subcommand_from migrate" -a "Workspace isolation migration"
complete -c clawforge -n "__fish_seen_subcommand_from export" -a "Package agent as archive"
complete -c clawforge -n "__fish_seen_subcommand_from import" -a "Import agent archive"
complete -c clawforge -n "__fish_seen_subcommand_from template" -a "Manage agent templates"
complete -c clawforge -n "__fish_seen_subcommand_from compat" -a "Fleet compatibility check"
complete -c clawforge -n "__fish_seen_subcommand_from upgrade-check" -a "Check for tool updates"
complete -c clawforge -n "__fish_seen_subcommand_from coding" -a "Legacy coding workflow commands"

# template subcommands
complete -c clawforge -n "__fish_seen_subcommand_from template" -a "list show create delete"

# coding subcommands
complete -c clawforge -n "__fish_seen_subcommand_from coding" -a "sprint review swarm attach steer stop"

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

# create flags
complete -c clawforge -n "__fish_seen_subcommand_from create" -l from -d "Archetype template" -xa "generalist coder monitor researcher communicator"
complete -c clawforge -n "__fish_seen_subcommand_from create" -l name -d "Agent name" -x
complete -c clawforge -n "__fish_seen_subcommand_from create" -l role -d "Agent role description" -x
complete -c clawforge -n "__fish_seen_subcommand_from create" -l emoji -d "Agent emoji" -x
complete -c clawforge -n "__fish_seen_subcommand_from create" -l channel -d "Discord channel" -x
