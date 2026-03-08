#!/usr/bin/env bash
# test-web.sh — Test v1.4 web dashboard
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

echo "=== test-web.sh ==="

# Test 1: web help
echo "Test 1: web command"
help=$("$BIN_DIR/web.sh" --help 2>&1)
assert_contains "web has usage" "Usage:" "$help"
assert_contains "web has --port" "--port" "$help"
assert_contains "web has --open" "--open" "$help"
assert_contains "web mentions phone" "phone" "$help"

# Test 2: binary exists
echo "Test 2: binary"
if [[ -f "$BIN_DIR/clawforge-web" ]]; then
  echo "  ✅ web binary exists"; PASS=$((PASS+1))
else
  echo "  ❌ web binary missing"; FAIL=$((FAIL+1))
fi

# Test 3: web source files
echo "Test 3: source files"
assert_contains "go.mod exists" "module" "$(cat "${SCRIPT_DIR}/../web/go.mod")"
if [[ -f "${SCRIPT_DIR}/../web/main.go" ]]; then
  echo "  ✅ main.go exists"; PASS=$((PASS+1))
else
  echo "  ❌ main.go missing"; FAIL=$((FAIL+1))
fi
if [[ -f "${SCRIPT_DIR}/../web/index.html" ]]; then
  echo "  ✅ index.html exists"; PASS=$((PASS+1))
else
  echo "  ❌ index.html missing"; FAIL=$((FAIL+1))
fi

# Test 4: start server, test API, stop
echo "Test 4: server API"
TEST_PORT=19877
export CLAWFORGE_DIR="${SCRIPT_DIR}/.."
"$BIN_DIR/clawforge-web" --port="$TEST_PORT" &
WEB_PID=$!
sleep 1

API_RESPONSE=$(curl -s "http://localhost:${TEST_PORT}/api/dashboard" 2>/dev/null || echo "FAIL")
kill $WEB_PID 2>/dev/null || true
wait $WEB_PID 2>/dev/null || true

if echo "$API_RESPONSE" | jq -e '.stats' >/dev/null 2>&1; then
  echo "  ✅ API returns valid JSON with stats"; PASS=$((PASS+1))
else
  echo "  ❌ API response invalid: $API_RESPONSE"; FAIL=$((FAIL+1))
fi

if echo "$API_RESPONSE" | jq -e '.tasks' >/dev/null 2>&1; then
  echo "  ✅ API returns tasks array"; PASS=$((PASS+1))
else
  echo "  ❌ API missing tasks"; FAIL=$((FAIL+1))
fi

# Test 5: HTML response
echo "Test 5: HTML response"
"$BIN_DIR/clawforge-web" --port="$TEST_PORT" &
WEB_PID=$!
sleep 1

HTML=$(curl -s "http://localhost:${TEST_PORT}/" 2>/dev/null || echo "FAIL")
kill $WEB_PID 2>/dev/null || true
wait $WEB_PID 2>/dev/null || true

assert_contains "HTML has title" "ClawForge Dashboard" "$HTML"
assert_contains "HTML has stats div" "id=\"stats\"" "$HTML"
assert_contains "HTML has task list" "id=\"task-list\"" "$HTML"
assert_contains "HTML has filter bar" "filter-bar" "$HTML"
assert_contains "HTML has preview panel" "preview-panel" "$HTML"

# Test 6: CLI routing
echo "Test 6: CLI routing"
cli_help=$("$BIN_DIR/clawforge" help 2>&1)
assert_contains "help shows web" "web" "$cli_help"
assert_contains "help shows Web Dashboard" "Web Dashboard" "$cli_help"

# Test 7: version
echo "Test 7: version"
version=$(cat "${SCRIPT_DIR}/../VERSION")
assert_eq "version is 1.6.0" "1.6.0" "$version"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
