#!/usr/bin/env bash
# test-reliability.sh — Test v0.7 reliability features
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-reliability.sh ==="

# Test 1: sprint help shows new flags
echo "Test 1: sprint new flags"
sprint_help=$("$BIN_DIR/sprint.sh" --help 2>&1)
assert_contains "sprint has --auto-clean" "--auto-clean" "$sprint_help"
assert_contains "sprint has --timeout" "--timeout" "$sprint_help"

# Test 2: swarm help shows new flags
echo "Test 2: swarm new flags"
swarm_help=$("$BIN_DIR/swarm.sh" --help 2>&1)
assert_contains "swarm has --auto-clean" "--auto-clean" "$swarm_help"
assert_contains "swarm has --timeout" "--timeout" "$swarm_help"

# Test 3: clean help shows new flags
echo "Test 3: clean new flags"
clean_help=$("$BIN_DIR/clean.sh" --help 2>&1)
assert_contains "clean has --prune-days" "--prune-days" "$clean_help"
assert_contains "clean has --keep-branch" "--keep-branch" "$clean_help"

# Test 4: doctor runs
echo "Test 4: doctor command"
doctor_out=$("$BIN_DIR/doctor.sh" 2>&1)
assert_contains "doctor shows title" "ClawForge Doctor" "$doctor_out"
assert_contains "doctor checks registry" "Registry" "$doctor_out"
assert_contains "doctor checks tmux" "tmux" "$doctor_out"
assert_contains "doctor checks worktrees" "Worktrees" "$doctor_out"
assert_contains "doctor checks stale" "Stale" "$doctor_out"
assert_contains "doctor checks branches" "Branches" "$doctor_out"
assert_contains "doctor checks disk" "Disk" "$doctor_out"

# Test 5: doctor help
echo "Test 5: doctor help"
doctor_help=$("$BIN_DIR/doctor.sh" --help 2>&1)
assert_contains "doctor help has --fix" "--fix" "$doctor_help"
assert_contains "doctor help has --json" "--json" "$doctor_help"

# Test 6: flock in common.sh
echo "Test 6: file locking"
common_src=$(cat "${SCRIPT_DIR}/../lib/common.sh")
assert_contains "common has flock" "flock" "$common_src"
assert_contains "common has _with_lock" "_with_lock" "$common_src"
assert_contains "common has _unlock" "_unlock" "$common_src"
assert_contains "common has REGISTRY_LOCK" "REGISTRY_LOCK" "$common_src"

# Test 7: disk_check function
echo "Test 7: disk check"
assert_contains "common has disk_check" "disk_check" "$common_src"

# Test 8: sprint source has trap
echo "Test 8: signal traps"
sprint_src=$(cat "$BIN_DIR/sprint.sh")
assert_contains "sprint has trap" "trap" "$sprint_src"
assert_contains "sprint has SIGINT" "SIGINT" "$sprint_src"
assert_contains "sprint has SIGTERM" "SIGTERM" "$sprint_src"

# Test 9: sprint source has watchdog
echo "Test 9: watchdog timeout"
assert_contains "sprint has WATCHDOG_PID" "WATCHDOG_PID" "$sprint_src"
assert_contains "sprint has TIMEOUT_MIN" "TIMEOUT_MIN" "$sprint_src"

# Test 10: clawforge routes doctor
echo "Test 10: CLI routing"
cli_help=$("$BIN_DIR/clawforge" help 2>&1)
assert_contains "help shows doctor" "doctor" "$cli_help"
assert_contains "help shows Reliability" "Reliability" "$cli_help"

# Test 11: version bump
echo "Test 11: version"
version=$(cat "${SCRIPT_DIR}/../VERSION")
assert_eq "version is 1.5.3" "1.5.3" "$version"

# Test 12: doctor --fix runs without errors
echo "Test 12: doctor --fix"
fix_out=$("$BIN_DIR/doctor.sh" --fix 2>&1)
assert_contains "fix runs cleanly" "ClawForge Doctor" "$fix_out"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
