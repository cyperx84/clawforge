# bash completion for clawforge
_clawforge() {
  local cur prev commands
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Fleet commands + legacy coding commands
  commands="create list inspect edit bind unbind clone activate deactivate destroy
    migrate export import template compat upgrade-check coding
    sprint swarm review scope spawn stop steer attach check status
    cost conflicts merge history eval learn clean templates init routing
    resume diff pr doctor logs on-complete dashboard config multi-review
    summary parse-cost profile replay export completions help version"

  case "$prev" in
    clawforge)
      COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      return 0
      ;;
    create)
      COMPREPLY=($(compgen -W "--from --name --role --emoji --model --channel --dry-run --help" -- "$cur"))
      return 0
      ;;
    template)
      COMPREPLY=($(compgen -W "list show create delete" -- "$cur"))
      return 0
      ;;
    coding)
      COMPREPLY=($(compgen -W "sprint review swarm attach steer stop" -- "$cur"))
      return 0
      ;;
    config)
      COMPREPLY=($(compgen -W "show get set unset init path" -- "$cur"))
      return 0
      ;;
    profile)
      COMPREPLY=($(compgen -W "list show create delete use" -- "$cur"))
      return 0
      ;;
    export)
      COMPREPLY=($(compgen -W "--format --status --since --save" -- "$cur"))
      return 0
      ;;
    --from)
      COMPREPLY=($(compgen -W "generalist coder monitor researcher communicator" -- "$cur"))
      return 0
      ;;
    --agent)
      COMPREPLY=($(compgen -W "claude codex" -- "$cur"))
      return 0
      ;;
    --format)
      COMPREPLY=($(compgen -W "markdown json text" -- "$cur"))
      return 0
      ;;
    --status)
      COMPREPLY=($(compgen -W "done failed running all" -- "$cur"))
      return 0
      ;;
    --effort)
      COMPREPLY=($(compgen -W "high medium low" -- "$cur"))
      return 0
      ;;
    --routing)
      COMPREPLY=($(compgen -W "auto cheap quality" -- "$cur"))
      return 0
      ;;
    --repo|--save|--output)
      COMPREPLY=($(compgen -d -- "$cur"))
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "--repo --branch --task --agent --model --effort --timeout --auto-clean --notify --dry-run --help --json --after" -- "$cur"))
  fi
}
complete -F _clawforge clawforge
