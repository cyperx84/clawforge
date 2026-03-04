#!/usr/bin/env bash
# test-dx.sh — Test v1.3 developer experience features
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    local actual=0
  else
    local actual=$?
  fi
  if [[ "$expected" -eq 0 && $actual -eq 0 ]] || [[ "$expected" -ne 0 && $actual -ne 0 ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected exit=$expected, got=$actual)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-dx.sh ==="

# Test 1: profile help
echo "Test 1: profile command"
help=$("$BIN_DIR/profile.sh" --help 2>&1)
assert_contains "profile has usage" "Usage:" "$help"
assert_contains "profile has create" "create" "$help"
assert_contains "profile has use" "use" "$help"
assert_contains "profile has list" "list" "$help"

# Test 2: profile create/show/use/delete
echo "Test 2: profile CRUD"
"$BIN_DIR/profile.sh" create test-profile --agent claude --model test-model --timeout 5 >/dev/null 2>&1
show=$("$BIN_DIR/profile.sh" show test-profile 2>&1)
assert_contains "profile show has agent" "claude" "$show"
assert_contains "profile show has model" "test-model" "$show"

use=$("$BIN_DIR/profile.sh" use test-profile 2>&1)
assert_contains "profile use has --agent" "--agent claude" "$use"
assert_contains "profile use has --model" "--model test-model" "$use"
assert_contains "profile use has --timeout" "--timeout 5" "$use"

list=$("$BIN_DIR/profile.sh" list 2>&1)
assert_contains "profile list has test-profile" "test-profile" "$list"

"$BIN_DIR/profile.sh" delete test-profile >/dev/null 2>&1
assert_exit "profile delete works" 1 "$BIN_DIR/profile.sh" show test-profile

# Test 3: replay help
echo "Test 3: replay command"
help=$("$BIN_DIR/replay.sh" --help 2>&1)
assert_contains "replay has usage" "Usage:" "$help"
assert_contains "replay has --model" "--model" "$help"
assert_contains "replay has --dry-run" "--dry-run" "$help"
assert_exit "replay no args fails" 1 "$BIN_DIR/replay.sh"

# Test 4: export help + basic run
echo "Test 4: export command"
help=$("$BIN_DIR/export.sh" --help 2>&1)
assert_contains "export has usage" "Usage:" "$help"
assert_contains "export has --format" "--format" "$help"
assert_contains "export has --status" "--status" "$help"
assert_contains "export has --since" "--since" "$help"

report=$("$BIN_DIR/export.sh" 2>&1)
assert_contains "export markdown has header" "ClawForge Task Report" "$report"
assert_contains "export markdown has summary" "Summary" "$report"

json=$("$BIN_DIR/export.sh" --format json 2>&1)
# Should be valid JSON
echo "$json" | jq empty 2>/dev/null
if [[ $? -eq 0 ]]; then
  echo "  ✅ export json is valid"; PASS=$((PASS+1))
else
  echo "  ❌ export json is invalid"; FAIL=$((FAIL+1))
fi

# Test 5: completions help
echo "Test 5: completions command"
help=$("$BIN_DIR/completions.sh" --help 2>&1)
assert_contains "completions has usage" "Usage:" "$help"
assert_contains "completions has bash" "bash" "$help"
assert_contains "completions has zsh" "zsh" "$help"
assert_contains "completions has fish" "fish" "$help"

# Test 6: completion files exist
echo "Test 6: completion files"
assert_exit "bash completion exists" 0 test -f "${SCRIPT_DIR}/../completions/clawforge.bash"
assert_exit "zsh completion exists" 0 test -f "${SCRIPT_DIR}/../completions/_clawforge"
assert_exit "fish completion exists" 0 test -f "${SCRIPT_DIR}/../completions/clawforge.fish"

# Test 7: spawn --after flag
echo "Test 7: spawn --after in help"
help=$("$BIN_DIR/spawn-agent.sh" --help 2>&1)
assert_contains "spawn has --after" "--after" "$help"

# Test 8: on-complete Discord/Slack
echo "Test 8: on-complete webhook support"
oc=$(cat "$BIN_DIR/on-complete.sh")
assert_contains "on-complete has discord_webhook" "discord_webhook" "$oc"
assert_contains "on-complete has slack_webhook" "slack_webhook" "$oc"
assert_contains "on-complete has embeds" "embeds" "$oc"

# Test 9: doctor enhancements
echo "Test 9: doctor enhancements"
doc=$(cat "$BIN_DIR/doctor.sh")
assert_contains "doctor has lock check" "Lock Files" "$doc"
assert_contains "doctor has config check" "Configuration" "$doc"
assert_contains "doctor has profiles check" "Profiles" "$doc"

# Test 10: CLI routing
echo "Test 10: CLI routing"
cli_help=$("$BIN_DIR/clawforge" help 2>&1)
assert_contains "help shows profile" "profile" "$cli_help"
assert_contains "help shows replay" "replay" "$cli_help"
assert_contains "help shows export" "export" "$cli_help"
assert_contains "help shows completions" "completions" "$cli_help"
assert_contains "help shows Developer Experience" "Developer Experience" "$cli_help"

# Test 11: version
echo "Test 11: version"
version=$(cat "${SCRIPT_DIR}/../VERSION")
if [[ "$version" == "1.4.1" ]]; then
  echo "  ✅ version is 1.4.1"; PASS=$((PASS+1))
else
  echo "  ❌ version is $version, expected 1.4.1"; FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
