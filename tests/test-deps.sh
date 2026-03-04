#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0; FAIL=0
ORIG=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
cleanup(){ echo "$ORIG" > "$REGISTRY_FILE"; }
trap cleanup EXIT

ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

contains(){ local d="$1" n="$2"; shift 2; out=$($@ 2>&1 || true); echo "$out"|grep -q "$n" && ok "$d" || { no "$d"; echo "$out"; }; }

echo "=== test-deps.sh ==="
echo '{"tasks":[]}' > "$REGISTRY_FILE"

T1='{"id":"a","short_id":1,"description":"Task A","status":"running"}'
T2='{"id":"b","short_id":2,"description":"Task B","status":"spawned","depends_on":"a"}'
T3='{"id":"c","short_id":3,"description":"Task C","status":"spawned","depends_on":"b"}'
registry_add "$T1" >/dev/null
registry_add "$T2" >/dev/null
registry_add "$T3" >/dev/null

contains "help works" "Usage:" "$BIN_DIR/deps.sh" --help
contains "shows graph header" "Dependency Graph" "$BIN_DIR/deps.sh"
contains "shows wait relation" "waits for" "$BIN_DIR/deps.sh"
contains "blocked filter works" "blocked" "$BIN_DIR/deps.sh" --blocked

json=$($BIN_DIR/deps.sh --json)
echo "$json" | jq -e '.nodes|length==3' >/dev/null && ok "json nodes" || no "json nodes"
echo "$json" | jq -e '.edges|length==2' >/dev/null && ok "json edges" || no "json edges"

contains "cli help includes deps" "deps" "$BIN_DIR/clawforge" help

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
