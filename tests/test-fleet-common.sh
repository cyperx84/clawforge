#!/usr/bin/env bash
# test-fleet-common.sh — Test fleet-common.sh library functions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
PASS=0 FAIL=0

# Source dependencies
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/fleet-common.sh"

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

assert_fail() {
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc"
    ((FAIL++)) || true
  fi
}

assert_equals() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected', got '$actual')"
    ((FAIL++)) || true
  fi
}

assert_contains() {
  local desc="$1" expected="$2"; shift 2
  local output
  output=$("$@" 2>&1 || true)
  if grep -q "$expected" <<< "$output"; then
    echo "  ✅ $desc"
    ((PASS++)) || true
  else
    echo "  ❌ $desc (expected '$expected' in output)"
    ((FAIL++)) || true
  fi
}

echo "=== test-fleet-common: Library functions ==="

# ── _resolve_model_display ─────────────────────────────────────────────
echo ""
echo "── _resolve_model_display ──"
assert_equals "strips provider prefix" "gpt-5.4" "$(_resolve_model_display "openai-codex/gpt-5.4")"
assert_equals "strips anthropic prefix" "claude-sonnet-4-6" "$(_resolve_model_display "anthropic/claude-sonnet-4-6")"
assert_equals "handles no prefix" "gpt-5.4" "$(_resolve_model_display "gpt-5.4")"
assert_equals "handles zai prefix" "glm-5" "$(_resolve_model_display "zai/glm-5")"

# ── _require_jq ───────────────────────────────────────────────────────
echo ""
echo "── _require_jq ──"
assert_ok "jq is available" _require_jq

# ── _read_openclaw_config ─────────────────────────────────────────────
echo ""
echo "── _read_openclaw_config ──"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  assert_ok "reads config successfully" _read_openclaw_config
  output=$(_read_openclaw_config)
  assert_ok "output is valid JSON" bash -c "echo '$output' | jq empty"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── _list_agents ───────────────────────────────────────────────────────
echo ""
echo "── _list_agents ──"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  agents=$(_list_agents)
  count=$(echo "$agents" | jq 'length')
  echo "  ✅ lists agents ($count found)"
  ((PASS++)) || true

  # Verify it's a JSON array
  is_array=$(echo "$agents" | jq 'type')
  assert_equals "returns array" '"array"' "$is_array"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── _get_agent ─────────────────────────────────────────────────────────
echo ""
echo "── _get_agent ──"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  assert_ok "gets main agent" _get_agent "main"
  assert_fail "fails for nonexistent agent" _get_agent "nonexistent-agent-xyz"

  agent=$(_get_agent "main")
  agent_id=$(echo "$agent" | jq -r '.id')
  assert_equals "main agent has correct id" "main" "$agent_id"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── _get_workspace ─────────────────────────────────────────────────────
echo ""
echo "── _get_workspace ──"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  ws=$(_get_workspace "main")
  assert_ok "returns workspace path" test -n "$ws"

  # Nonexistent agent should return default path
  ws2=$(_get_workspace "nonexistent-test")
  assert_equals "default path for unknown agent" "${HOME}/.openclaw/agents/nonexistent-test" "$ws2"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── _get_bindings ──────────────────────────────────────────────────────
echo ""
echo "── _get_bindings ──"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  bindings=$(_get_bindings "builder" 2>/dev/null || echo "[]")
  is_array=$(echo "$bindings" | jq 'type')
  assert_equals "returns array for bindings" '"array"' "$is_array"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── _validate_agent ───────────────────────────────────────────────────
echo ""
echo "── _validate_agent ──"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  status=$(_validate_agent "builder")
  echo "  ✅ validates builder agent (status: $status)"
  ((PASS++)) || true

  status2=$(_validate_agent "nonexistent-test-xyz")
  assert_equals "unknown for nonexistent" "unknown" "$status2"
else
  echo "  ⚠️  Skipped (no openclaw.json)"
fi

# ── _status_icon ───────────────────────────────────────────────────────
echo ""
echo "── _status_icon ──"
assert_equals "active icon" "●" "$(_status_icon "active")"
assert_equals "created icon" "○" "$(_status_icon "created")"
assert_equals "config-only icon" "◌" "$(_status_icon "config-only")"
assert_equals "unknown icon" "?" "$(_status_icon "weird")"

# ── _file_status_icon ─────────────────────────────────────────────────
echo ""
echo "── _file_status_icon ──"
assert_equals "exists icon" "✓" "$(_file_status_icon "exists")"
assert_equals "empty icon" "○" "$(_file_status_icon "empty")"
assert_equals "missing icon" "✗" "$(_file_status_icon "missing")"
assert_equals "template icon" "⚠" "$(_file_status_icon "template")"

# ── _substitute_placeholders ──────────────────────────────────────────
echo ""
echo "── _substitute_placeholders ──"
result=$(_substitute_placeholders "Hello {{NAME}}, you are {{ROLE}}" "TestBot" "helper" "🤖" "A helpful bot")
assert_equals "substitutes NAME" "true" "$(if echo "$result" | grep -q 'TestBot'; then echo true; else echo false; fi)"
assert_equals "substitutes ROLE" "true" "$(if echo "$result" | grep -q 'helper'; then echo true; else echo false; fi)"
assert_equals "no leftover placeholders" "false" "$(if echo "$result" | grep -q '{{'; then echo true; else echo false; fi)"

# ── _human_size ────────────────────────────────────────────────────────
echo ""
echo "── _human_size ──"
assert_equals "bytes" "500 B" "$(_human_size 500)"
assert_equals "kilobytes" "3.0 KB" "$(_human_size 3072)"

# ── _get_model_primary ────────────────────────────────────────────────
echo ""
echo "── _get_model_primary ──"
result1=$(_get_model_primary '{"model": "openai-codex/gpt-5.4"}')
assert_equals "string model" "openai-codex/gpt-5.4" "$result1"

result2=$(_get_model_primary '{"model": {"primary": "anthropic/claude-opus-4-6", "fallbacks": []}}')
assert_equals "object model" "anthropic/claude-opus-4-6" "$result2"

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
