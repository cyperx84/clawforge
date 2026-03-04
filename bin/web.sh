#!/usr/bin/env bash
# web.sh — Launch the ClawForge web dashboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAWFORGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="${CLAWFORGE_DIR}/web"
BINARY="${SCRIPT_DIR}/clawforge-web"

export CLAWFORGE_DIR

usage() {
  cat <<EOF
Usage: clawforge web [options]

Launch the ClawForge web dashboard.
Accessible from your phone, tablet, or any browser on the network.

Options:
  --port <port>        Port to listen on (default: 9876)
  --open               Open in default browser
  --build              Force rebuild the web binary
  --help               Show this help

Examples:
  clawforge web                    # Start on http://localhost:9876
  clawforge web --port 8080        # Custom port
  clawforge web --open             # Start + open browser

Keyboard shortcuts (in browser):
  1/2/3/4      Filter: all/running/done/failed
  Escape       Close preview panel
  Click task   Open detail + agent output preview
EOF
}

PORT=9876
OPEN=false
BUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port|-p)   PORT="$2"; shift 2 ;;
    --open|-o)   OPEN=true; shift ;;
    --build)     BUILD=true; shift ;;
    --help|-h)   usage; exit 0 ;;
    *)           shift ;;
  esac
done

# Build if needed
if [[ ! -f "$BINARY" ]] || $BUILD; then
  echo "Building web dashboard..."
  if ! command -v go &>/dev/null; then
    echo "Error: go is required. Install with: brew install go"
    exit 1
  fi
  (cd "$WEB_DIR" && go build -o "$BINARY" .)
  echo "Built: $BINARY"
fi

# Open browser
if $OPEN; then
  (sleep 1 && open "http://localhost:${PORT}" 2>/dev/null || xdg-open "http://localhost:${PORT}" 2>/dev/null) &
fi

# Run
exec "$BINARY" --port="$PORT"
