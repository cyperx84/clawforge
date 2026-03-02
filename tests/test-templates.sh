#!/usr/bin/env bash
# test-templates.sh — Test task templates system
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="${SCRIPT_DIR}/../bin/clawforge"
TEMPLATES="${SCRIPT_DIR}/../bin/templates.sh"
BUILTIN_DIR="${SCRIPT_DIR}/../lib/templates"
USER_DIR="${HOME}/.clawforge/templates"
PASS=0 FAIL=0

# Backup user templates if they exist
USER_BACKUP=""
cleanup() {
  # Remove test template if created
  rm -f "${USER_DIR}/test-template-123.json"
  if [[ -n "$USER_BACKUP" && -d "$USER_BACKUP" ]]; then
    rm -rf "$USER_DIR"
    mv "$USER_BACKUP" "$USER_DIR"
  fi
}
trap cleanup EXIT

assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc"
    ((FAIL++)) || true
  fi
}

assert_contains() {
  local desc="$1" expected="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    ((FAIL++)) || true
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

echo "=== test-templates.sh ==="

# Script exists and is executable
assert_ok "templates.sh exists" test -f "$TEMPLATES"
assert_ok "templates.sh is executable" test -x "$TEMPLATES"

# Help
assert_ok "templates --help exits 0" "$TEMPLATES" --help
assert_contains "help shows template usage" "template" "$TEMPLATES" --help
assert_contains "help shows new command" "new" "$TEMPLATES" --help

# Routes via CLI
assert_ok "CLI routes templates --help" "$CLI" templates --help

# ── Built-in templates exist ──────────────────────────────────────────
echo "Test 1: built-in templates"
assert_ok "templates dir exists" test -d "$BUILTIN_DIR"
assert_ok "migration.json exists" test -f "$BUILTIN_DIR/migration.json"
assert_ok "refactor.json exists" test -f "$BUILTIN_DIR/refactor.json"
assert_ok "test-coverage.json exists" test -f "$BUILTIN_DIR/test-coverage.json"
assert_ok "bugfix.json exists" test -f "$BUILTIN_DIR/bugfix.json"
assert_ok "security-audit.json exists" test -f "$BUILTIN_DIR/security-audit.json"

# ── Template content validation ───────────────────────────────────────
echo "Test 2: template content"

# migration
mode=$(jq -r '.mode' "$BUILTIN_DIR/migration.json")
assert_eq "migration mode is swarm" "swarm" "$mode"
agents=$(jq -r '.maxAgents' "$BUILTIN_DIR/migration.json")
assert_eq "migration maxAgents is 4" "4" "$agents"
auto_merge=$(jq -r '.autoMerge' "$BUILTIN_DIR/migration.json")
assert_eq "migration autoMerge is true" "true" "$auto_merge"
ci_loop=$(jq -r '.ciLoop' "$BUILTIN_DIR/migration.json")
assert_eq "migration ciLoop is true" "true" "$ci_loop"

# refactor
mode=$(jq -r '.mode' "$BUILTIN_DIR/refactor.json")
assert_eq "refactor mode is sprint" "sprint" "$mode"
auto_merge=$(jq -r '.autoMerge' "$BUILTIN_DIR/refactor.json")
assert_eq "refactor autoMerge is false" "false" "$auto_merge"

# test-coverage
mode=$(jq -r '.mode' "$BUILTIN_DIR/test-coverage.json")
assert_eq "test-coverage mode is swarm" "swarm" "$mode"
agents=$(jq -r '.maxAgents' "$BUILTIN_DIR/test-coverage.json")
assert_eq "test-coverage maxAgents is 3" "3" "$agents"

# bugfix
mode=$(jq -r '.mode' "$BUILTIN_DIR/bugfix.json")
assert_eq "bugfix mode is sprint" "sprint" "$mode"
quick=$(jq -r '.quick' "$BUILTIN_DIR/bugfix.json")
assert_eq "bugfix quick is true" "true" "$quick"

# security-audit
mode=$(jq -r '.mode' "$BUILTIN_DIR/security-audit.json")
assert_eq "security-audit mode is review" "review" "$mode"
depth=$(jq -r '.depth' "$BUILTIN_DIR/security-audit.json")
assert_eq "security-audit depth is deep" "deep" "$depth"

# ── All templates are valid JSON ──────────────────────────────────────
echo "Test 3: JSON validity"
for f in "$BUILTIN_DIR"/*.json; do
  name=$(basename "$f" .json)
  if jq . "$f" >/dev/null 2>&1; then
    echo "  ✅ $name.json is valid JSON"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name.json is invalid JSON"
    FAIL=$((FAIL+1))
  fi
done

# ── List templates ────────────────────────────────────────────────────
echo "Test 4: list templates"
assert_contains "list shows migration" "migration" "$TEMPLATES"
assert_contains "list shows refactor" "refactor" "$TEMPLATES"
assert_contains "list shows bugfix" "bugfix" "$TEMPLATES"
assert_contains "list shows test-coverage" "test-coverage" "$TEMPLATES"
assert_contains "list shows security-audit" "security-audit" "$TEMPLATES"

# JSON list
json_list=$("$TEMPLATES" --json 2>/dev/null || true)
count=$(echo "$json_list" | jq 'length' 2>/dev/null || echo 0)
if [[ "$count" -ge 5 ]]; then
  echo "  ✅ JSON list has >= 5 templates"
  PASS=$((PASS+1))
else
  echo "  ❌ JSON list has $count templates (expected >= 5)"
  FAIL=$((FAIL+1))
fi

# ── Show template ─────────────────────────────────────────────────────
echo "Test 5: show template"
assert_contains "show migration" "swarm\|mode" "$TEMPLATES" show migration
assert_contains "show refactor" "sprint\|mode" "$TEMPLATES" show refactor

# JSON show
json_show=$("$TEMPLATES" show bugfix --json 2>/dev/null || true)
has_mode=$(echo "$json_show" | jq -e '.mode' >/dev/null 2>&1 && echo "yes" || echo "no")
assert_eq "JSON show has mode" "yes" "$has_mode"

# ── Template used in sprint --template ─────────────────────────────
echo "Test 6: sprint --template flag"
assert_contains "sprint help shows template" "template" "$CLI" sprint --help

echo ""
echo "  Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
