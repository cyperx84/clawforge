#!/usr/bin/env bash
# deps.sh — Show task dependency graph and blocked tasks
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage(){ cat <<EOF
Usage: clawforge deps [options]

Show dependency graph for active tasks.

Options:
  --json           Output JSON graph
  --blocked        Show only blocked tasks
  --help           Show help
EOF
}

JSON_OUTPUT=false
BLOCKED_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUTPUT=true; shift ;;
    --blocked) BLOCKED_ONLY=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

_ensure_registry
tasks=$(jq '.tasks' "$REGISTRY_FILE" 2>/dev/null || echo '[]')

if $JSON_OUTPUT; then
  jq -n --argjson tasks "$tasks" '
    {
      nodes: ($tasks | map({id:.id, short_id:.short_id, description:.description, status:.status})),
      edges: ($tasks | map(select(.depends_on != null) | {from:.depends_on, to:.id}))
    }'
  exit 0
fi

echo "Dependency Graph"
echo ""
count=$(echo "$tasks" | jq 'length')
if [[ "$count" == "0" ]]; then
  echo "(no active tasks)"
  exit 0
fi

echo "$tasks" | jq -r '.[] | [.id, (.short_id//0|tostring), (.description//"—"), (.status//"—"), (.depends_on//"")] | @tsv' | while IFS=$'	' read -r id sid desc status dep; do
  if $BLOCKED_ONLY; then
    [[ -z "$dep" ]] && continue
    dep_status=$(echo "$tasks" | jq -r --arg d "$dep" '.[] | select(.id==$d) | .status' 2>/dev/null || true)
    [[ "$dep_status" == "done" ]] && continue
  fi

  if [[ -n "$dep" ]]; then
    dep_sid=$(echo "$tasks" | jq -r --arg d "$dep" '.[] | select(.id==$d) | (.short_id//0|tostring)' 2>/dev/null || echo "?")
    dep_status=$(echo "$tasks" | jq -r --arg d "$dep" '.[] | select(.id==$d) | .status' 2>/dev/null || echo "?")
    blocked=""
    [[ "$dep_status" != "done" ]] && blocked=" [blocked]"
    echo "  #$sid ($status)$blocked"
    echo "    └─ waits for #$dep_sid ($dep_status)"
    echo "       $desc"
  else
    echo "  #$sid ($status)"
    echo "    $desc"
  fi
  echo ""
done
