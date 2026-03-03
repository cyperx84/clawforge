#!/usr/bin/env bash
# init.sh — Scan project and generate initial memory entries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

MEMORY_BASE="$HOME/.clawforge/memory"

# ── Help ───────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: init.sh [options]

Scans the current directory for project structure and generates
initial memory entries for agent context.

Options:
  --claude-md    Also create CLAUDE.md if missing
  --help         Show this help
EOF
}

# ── Parse args ────────────────────────────────────────────────────────
CREATE_CLAUDE_MD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude-md)  CREATE_CLAUDE_MD=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)            log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Detect repo name ─────────────────────────────────────────────────
REPO_NAME=$(basename "$(pwd)")
REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || true)
[[ -n "$REMOTE_URL" ]] && REPO_NAME=$(basename "$REMOTE_URL" .git)

MEMORY_FILE="${MEMORY_BASE}/${REPO_NAME}.jsonl"
mkdir -p "$MEMORY_BASE"

# ── Helper: add memory ───────────────────────────────────────────────
ENTRY_COUNT=0
add_memory() {
  local text="$1"
  local tags="${2:-init}"
  local tags_json
  tags_json=$(echo "$tags" | tr ',' '\n' | jq -R . | jq -s .)
  local entry
  entry=$(jq -cn \
    --arg id "init-$(date +%s)-${ENTRY_COUNT}" \
    --arg text "$text" \
    --argjson tags "$tags_json" \
    --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "init" \
    '{id:$id, text:$text, tags:$tags, created:$created, source:$source}')
  echo "$entry" >> "$MEMORY_FILE"
  ENTRY_COUNT=$((ENTRY_COUNT + 1))
  echo "  + $text"
}

echo "Scanning: $(pwd)"
echo "Repo: $REPO_NAME"
echo ""

OBSERVATIONS=()

# ── Language / package manager detection ─────────────────────────────
if [[ -f "package.json" ]]; then
  add_memory "Node.js project (package.json)" "lang,node"
  # Check for specific package managers
  if [[ -f "pnpm-lock.yaml" ]]; then
    add_memory "Uses pnpm as package manager" "tooling,pnpm"
  elif [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
    add_memory "Uses bun as package manager" "tooling,bun"
  elif [[ -f "yarn.lock" ]]; then
    add_memory "Uses yarn as package manager" "tooling,yarn"
  elif [[ -f "package-lock.json" ]]; then
    add_memory "Uses npm as package manager" "tooling,npm"
  fi
  # Detect test runner from package.json
  if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    TEST_CMD=$(jq -r '.scripts.test' package.json)
    if echo "$TEST_CMD" | grep -q "vitest"; then
      add_memory "Uses vitest for testing" "testing,vitest"
    elif echo "$TEST_CMD" | grep -q "jest"; then
      add_memory "Uses jest for testing" "testing,jest"
    elif echo "$TEST_CMD" | grep -q "mocha"; then
      add_memory "Uses mocha for testing" "testing,mocha"
    fi
  fi
  # Detect framework from dependencies
  if jq -e '.dependencies.next // .devDependencies.next' package.json >/dev/null 2>&1; then
    add_memory "Next.js framework detected" "framework,nextjs"
  elif jq -e '.dependencies.react // .devDependencies.react' package.json >/dev/null 2>&1; then
    add_memory "React project" "framework,react"
  fi
  if jq -e '.dependencies.express // .devDependencies.express' package.json >/dev/null 2>&1; then
    add_memory "Uses Express.js" "framework,express"
  fi
  # Detect TypeScript
  if [[ -f "tsconfig.json" ]]; then
    add_memory "TypeScript project" "lang,typescript"
  fi
fi

if [[ -f "go.mod" ]]; then
  MODULE=$(head -1 go.mod | sed 's/^module //')
  add_memory "Go project (module: $MODULE)" "lang,go"
  if [[ -f "go.sum" ]]; then
    add_memory "Go dependencies managed with go modules" "tooling,go"
  fi
fi

if [[ -f "Cargo.toml" ]]; then
  add_memory "Rust project (Cargo.toml)" "lang,rust"
fi

if [[ -f "pyproject.toml" ]]; then
  add_memory "Python project (pyproject.toml)" "lang,python"
  if grep -q "pytest" pyproject.toml 2>/dev/null; then
    add_memory "Uses pytest for testing" "testing,pytest"
  fi
elif [[ -f "setup.py" ]] || [[ -f "setup.cfg" ]]; then
  add_memory "Python project" "lang,python"
elif [[ -f "requirements.txt" ]]; then
  add_memory "Python project (requirements.txt)" "lang,python"
fi

# ── Build tools ──────────────────────────────────────────────────────
if [[ -f "Makefile" ]]; then
  add_memory "Has Makefile for build tasks" "tooling,make"
fi

if [[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
  add_memory "Docker setup present" "tooling,docker"
fi

# ── CI detection ─────────────────────────────────────────────────────
if [[ -d ".github/workflows" ]]; then
  WF_COUNT=$(find .github/workflows -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ')
  add_memory "GitHub Actions CI ($WF_COUNT workflow files)" "ci,github-actions"
fi

if [[ -f ".gitlab-ci.yml" ]]; then
  add_memory "GitLab CI configured" "ci,gitlab"
fi

# ── Misc ─────────────────────────────────────────────────────────────
if [[ -f "CLAUDE.md" ]]; then
  add_memory "Has CLAUDE.md project instructions" "config"
fi

if [[ -f ".env.example" ]] || [[ -f ".env.local" ]]; then
  add_memory "Uses environment variables (.env)" "config"
fi

# ── Optional: create CLAUDE.md ───────────────────────────────────────
if $CREATE_CLAUDE_MD && [[ ! -f "CLAUDE.md" ]]; then
  cat > CLAUDE.md <<'CLAUDEEOF'
# Project Instructions

## Overview
<!-- Describe your project here -->

## Development
<!-- Build, test, and run commands -->

## Conventions
<!-- Code style, naming conventions, etc. -->
CLAUDEEOF
  echo ""
  echo "Created CLAUDE.md (edit to add project instructions)"
fi

echo ""
if [[ $ENTRY_COUNT -eq 0 ]]; then
  echo "No project files detected. Memory file not created."
else
  echo "Wrote $ENTRY_COUNT memory entries to: $MEMORY_FILE"
fi
