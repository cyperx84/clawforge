#!/usr/bin/env bash
# test-routing.sh — Test model routing (bin/routing.sh + --routing flag)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${BIN_DIR}/routing.sh"

PASS=0 FAIL=0
ORIG_REGISTRY=""
TMPDIR=""

cleanup() {
  if [[ -n "$ORIG_REGISTRY" ]]; then
    echo "$ORIG_REGISTRY" > "$REGISTRY_FILE"
  else
    echo '{"tasks":[]}' > "$REGISTRY_FILE"
  fi
  [[ -n "$TMPDIR" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
  # Remove test routing file if created
  rm -f "${HOME}/.clawforge/routing-test-backup.json"
}
trap cleanup EXIT

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local desc="$1" expected="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    FAIL=$((FAIL+1))
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== test-routing.sh ==="

# Save and reset
ORIG_REGISTRY=$(cat "$REGISTRY_FILE" 2>/dev/null || echo '{"tasks":[]}')
echo '{"tasks":[]}' > "$REGISTRY_FILE"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/repo"
git -C "$TMPDIR/repo" init -b main >/dev/null 2>&1
echo "test" > "$TMPDIR/repo/README.md"
git -C "$TMPDIR/repo" add -A
git -C "$TMPDIR/repo" -c commit.gpgsign=false commit -m "init" >/dev/null 2>&1

# ── routing.sh exists and is executable ──────────────────────────────
echo "Test 1: routing.sh exists"
assert_ok "routing.sh exists" test -f "$BIN_DIR/routing.sh"
assert_ok "routing.sh is executable" test -x "$BIN_DIR/routing.sh"

# ── routing-defaults.json exists ─────────────────────────────────────
echo "Test 2: routing defaults config"
DEFAULTS="${SCRIPT_DIR}/../config/routing-defaults.json"
assert_ok "routing-defaults.json exists" test -f "$DEFAULTS"
# Validate JSON structure
scope_model=$(jq -r '.scope' "$DEFAULTS")
assert_eq "defaults scope is haiku" "haiku" "$scope_model"
impl_model=$(jq -r '.implement' "$DEFAULTS")
assert_eq "defaults implement is sonnet" "sonnet" "$impl_model"
review_model=$(jq -r '.review' "$DEFAULTS")
assert_eq "defaults review is opus" "opus" "$review_model"
cifix_model=$(jq -r '.["ci-fix"]' "$DEFAULTS")
assert_eq "defaults ci-fix is haiku" "haiku" "$cifix_model"

# ── load_routing + get_model_for_phase ───────────────────────────────
echo "Test 3: load_routing cheap"
load_routing "cheap"
model=$(get_model_for_phase "scope")
assert_eq "cheap scope → haiku" "claude-haiku-4-5" "$model"
model=$(get_model_for_phase "implement")
assert_eq "cheap implement → haiku" "claude-haiku-4-5" "$model"
model=$(get_model_for_phase "review")
assert_eq "cheap review → haiku" "claude-haiku-4-5" "$model"
model=$(get_model_for_phase "ci-fix")
assert_eq "cheap ci-fix → haiku" "claude-haiku-4-5" "$model"

echo "Test 4: load_routing quality"
load_routing "quality"
model=$(get_model_for_phase "scope")
assert_eq "quality scope → opus" "claude-opus-4-6" "$model"
model=$(get_model_for_phase "implement")
assert_eq "quality implement → opus" "claude-opus-4-6" "$model"
model=$(get_model_for_phase "review")
assert_eq "quality review → opus" "claude-opus-4-6" "$model"

echo "Test 5: load_routing auto (from defaults)"
load_routing "auto"
model=$(get_model_for_phase "scope")
assert_eq "auto scope → haiku" "claude-haiku-4-5" "$model"
model=$(get_model_for_phase "implement")
assert_eq "auto implement → sonnet" "claude-sonnet-4-5" "$model"
model=$(get_model_for_phase "review")
assert_eq "auto review → opus" "claude-opus-4-6" "$model"
model=$(get_model_for_phase "ci-fix")
assert_eq "auto ci-fix → haiku" "claude-haiku-4-5" "$model"

echo "Test 6: no routing returns empty"
load_routing ""
model=$(get_model_for_phase "scope")
assert_eq "empty routing returns empty" "" "$model"

echo "Test 7: invalid strategy fails"
assert_fail "bad strategy fails" load_routing "invalid-strategy"

echo "Test 8: unknown phase returns empty"
load_routing "auto"
model=$(get_model_for_phase "nonexistent-phase")
assert_eq "unknown phase returns empty" "" "$model"

# ── Sprint help shows --routing ──────────────────────────────────────
echo "Test 9: sprint help shows --routing"
assert_contains "sprint help has --routing" "routing" "$BIN_DIR/sprint.sh" --help

# ── Swarm help shows --routing ───────────────────────────────────────
echo "Test 10: swarm help shows --routing"
assert_contains "swarm help has --routing" "routing" "$BIN_DIR/swarm.sh" --help

# ── Sprint --routing dry-run ─────────────────────────────────────────
echo "Test 11: sprint --routing dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/sprint.sh" "$TMPDIR/repo" "Add auth" --routing cheap --dry-run 2>&1 || true)
assert_contains "sprint routing dry-run shows Routing" "Routing" echo "$output"
assert_contains "sprint routing dry-run shows cheap" "cheap" echo "$output"

# ── Swarm --routing dry-run ──────────────────────────────────────────
echo "Test 12: swarm --routing dry-run"
echo '{"tasks":[]}' > "$REGISTRY_FILE"
output=$("$BIN_DIR/swarm.sh" "$TMPDIR/repo" "Add logging" --routing quality --dry-run 2>&1 || true)
assert_contains "swarm routing dry-run shows Routing" "Routing" echo "$output"
assert_contains "swarm routing dry-run shows quality" "quality" echo "$output"

# ── User routing.json (auto mode) ───────────────────────────────────
echo "Test 13: user routing.json override"
mkdir -p "${HOME}/.clawforge"
# Back up existing if present
[[ -f "${HOME}/.clawforge/routing.json" ]] && cp "${HOME}/.clawforge/routing.json" "${HOME}/.clawforge/routing-test-backup.json"
cat > "${HOME}/.clawforge/routing.json" <<'EOF'
{
  "scope": "opus",
  "implement": "opus",
  "review": "haiku",
  "ci-fix": "sonnet"
}
EOF
load_routing "auto"
model=$(get_model_for_phase "scope")
assert_eq "user config scope → opus" "claude-opus-4-6" "$model"
model=$(get_model_for_phase "review")
assert_eq "user config review → haiku" "claude-haiku-4-5" "$model"
model=$(get_model_for_phase "ci-fix")
assert_eq "user config ci-fix → sonnet" "claude-sonnet-4-5" "$model"

# Restore or remove
if [[ -f "${HOME}/.clawforge/routing-test-backup.json" ]]; then
  mv "${HOME}/.clawforge/routing-test-backup.json" "${HOME}/.clawforge/routing.json"
else
  rm -f "${HOME}/.clawforge/routing.json"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
