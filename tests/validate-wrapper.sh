#!/usr/bin/env bash
# Validation script for ClawForge Python wrapper
# Tests basic functionality without requiring pytest
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ClawForge Python Wrapper Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Counter for tests
PASSED=0
FAILED=0

test_command() {
    local name="$1"
    shift
    echo -n "Testing: $name... "

    if output=$(python3 -m clawforge_py "$@" 2>&1); then
        echo "✓"
        ((PASSED++))
        return 0
    else
        echo "✗"
        echo "  Error: $output"
        ((FAILED++))
        return 1
    fi
}

test_contains() {
    local name="$1"
    local expected="$2"
    shift 2
    echo -n "Testing: $name... "

    if output=$(python3 -m clawforge_py "$@" 2>&1); then
        if echo "$output" | grep -q "$expected"; then
            echo "✓"
            ((PASSED++))
            return 0
        else
            echo "✗"
            echo "  Expected output to contain: $expected"
            echo "  Got: $output"
            ((FAILED++))
            return 1
        fi
    else
        echo "✗"
        echo "  Command failed: $output"
        ((FAILED++))
        return 1
    fi
}

test_fails() {
    local name="$1"
    shift
    echo -n "Testing: $name... "

    if python3 -m clawforge_py "$@" >/dev/null 2>&1; then
        echo "✗"
        echo "  Expected command to fail, but it succeeded"
        ((FAILED++))
        return 1
    else
        echo "✓"
        ((PASSED++))
        return 0
    fi
}

# Run tests
cd "$PROJECT_ROOT"

echo "── Basic Commands ───────────────────────────────────────────"
test_contains "version command" "clawforge v" version
test_contains "help command" "Usage: clawforge" help
test_contains "help --all" "Direct Module Access" help --all

echo
echo "── Error Handling ───────────────────────────────────────────"
test_fails "unknown command fails" nonexistent-command

echo
echo "── Python Import ────────────────────────────────────────────"
echo -n "Testing: package import... "
if python3 -c "import clawforge_py; assert clawforge_py.__version__ == '0.4.0'" 2>&1; then
    echo "✓"
    ((PASSED++))
else
    echo "✗"
    ((FAILED++))
fi

echo -n "Testing: find script... "
if python3 -c "from clawforge_py.__main__ import find_clawforge_script; s = find_clawforge_script(); assert s.exists()" 2>&1; then
    echo "✓"
    ((PASSED++))
else
    echo "✗"
    ((FAILED++))
fi

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASSED passed, $FAILED failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi

echo
echo "✓ All validation tests passed!"
exit 0
