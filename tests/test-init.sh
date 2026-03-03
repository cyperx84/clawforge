#!/usr/bin/env bash
# test-init.sh — Test init command (Feature 4)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
source "${SCRIPT_DIR}/../lib/common.sh"

PASS=0 FAIL=0
TMPDIR=""
MEMORY_BASE="$HOME/.clawforge/memory"

cleanup() {
  [[ -n "$TMPDIR" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
  rm -f "${MEMORY_BASE}/test-init-node-$$".jsonl
  rm -f "${MEMORY_BASE}/test-init-go-$$".jsonl
  rm -f "${MEMORY_BASE}/test-init-empty-$$".jsonl
}
trap cleanup EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: $expected, got: $actual)"; FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (missing: $needle)"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-init.sh ==="

TMPDIR=$(mktemp -d)

# Test 1: --help
echo "Test 1: --help flag"
help_output=$("$BIN_DIR/init.sh" --help 2>&1 || true)
assert_contains "help shows usage" "Usage:" "$help_output"

# Test 2: Node.js project detection
echo "Test 2: Node.js project"
NODEDIR="$TMPDIR/test-init-node-$$"
mkdir -p "$NODEDIR"
git -C "$NODEDIR" init -q 2>/dev/null
cat > "$NODEDIR/package.json" <<'EOF'
{"name":"my-app","scripts":{"test":"vitest run","build":"next build"},"dependencies":{"next":"14.0.0","react":"18.0.0"},"devDependencies":{"vitest":"1.0.0"}}
EOF
touch "$NODEDIR/tsconfig.json"
touch "$NODEDIR/pnpm-lock.yaml"
mkdir -p "$NODEDIR/.github/workflows"
touch "$NODEDIR/.github/workflows/ci.yml"

output=$(cd "$NODEDIR" && "$BIN_DIR/init.sh" 2>/dev/null)
assert_contains "detects Node.js" "Node.js" "$output"
assert_contains "detects pnpm" "pnpm" "$output"
assert_contains "detects vitest" "vitest" "$output"
assert_contains "detects Next.js" "Next.js" "$output"
assert_contains "detects TypeScript" "TypeScript" "$output"
assert_contains "detects GitHub Actions" "GitHub Actions" "$output"

MEM_FILE="${MEMORY_BASE}/test-init-node-$$.jsonl"
if [[ -f "$MEM_FILE" ]]; then
  mem_count=$(wc -l < "$MEM_FILE" | tr -d ' ')
  assert_eq "multiple memories written" "true" "$( [[ "$mem_count" -ge 4 ]] && echo true || echo false )"
  # Check all lines are valid JSON
  valid=true
  while IFS= read -r line; do
    echo "$line" | jq . >/dev/null 2>&1 || valid=false
  done < "$MEM_FILE"
  assert_eq "all entries valid JSON" "true" "$valid"
  # Check source is init
  first_source=$(head -1 "$MEM_FILE" | jq -r '.source')
  assert_eq "source is init" "init" "$first_source"
else
  assert_eq "memory file created" "true" "false"
fi

# Test 3: Go project detection
echo "Test 3: Go project"
GODIR="$TMPDIR/test-init-go-$$"
mkdir -p "$GODIR"
git -C "$GODIR" init -q 2>/dev/null
echo "module github.com/test/myapp" > "$GODIR/go.mod"
touch "$GODIR/go.sum"
touch "$GODIR/Makefile"
touch "$GODIR/Dockerfile"

output=$(cd "$GODIR" && "$BIN_DIR/init.sh" 2>/dev/null)
assert_contains "detects Go" "Go project" "$output"
assert_contains "detects Makefile" "Makefile" "$output"
assert_contains "detects Docker" "Docker" "$output"

# Test 4: --claude-md flag
echo "Test 4: --claude-md flag"
MDDIR="$TMPDIR/test-init-empty-$$"
mkdir -p "$MDDIR"
git -C "$MDDIR" init -q 2>/dev/null
touch "$MDDIR/package.json"
echo '{"name":"x"}' > "$MDDIR/package.json"
(cd "$MDDIR" && "$BIN_DIR/init.sh" --claude-md 2>/dev/null) || true
assert_eq "CLAUDE.md created" "true" "$([ -f "$MDDIR/CLAUDE.md" ] && echo true || echo false)"

# Test 5: --claude-md doesn't overwrite existing
echo "Test 5: --claude-md respects existing"
echo "# Existing" > "$MDDIR/CLAUDE.md"
(cd "$MDDIR" && "$BIN_DIR/init.sh" --claude-md 2>/dev/null) || true
content=$(cat "$MDDIR/CLAUDE.md")
assert_contains "existing CLAUDE.md preserved" "Existing" "$content"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
