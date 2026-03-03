#!/usr/bin/env bash
# install.sh — Install ClawForge from source
set -euo pipefail

VERSION=$(cat VERSION 2>/dev/null || echo "dev")
PREFIX="${PREFIX:-/usr/local}"
OPENCLAW=false

usage() {
  cat <<EOF
ClawForge Installer v${VERSION}

Usage: ./install.sh [options]

Options:
  --prefix <path>    Install prefix (default: /usr/local)
  --openclaw         Install as OpenClaw skill (symlink to ~/.openclaw/skills/)
  --uninstall        Remove ClawForge
  --help             Show this help

Methods:
  ./install.sh                     # Install to /usr/local/bin
  ./install.sh --prefix ~/.local   # Install to ~/.local/bin
  ./install.sh --openclaw          # Install as OpenClaw skill
EOF
}

UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)    PREFIX="$2"; shift 2 ;;
    --openclaw)  OPENCLAW=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    --help|-h)   usage; exit 0 ;;
    *)           echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if $UNINSTALL; then
  echo "Uninstalling ClawForge..."
  rm -f "${PREFIX}/bin/clawforge"
  rm -f "${PREFIX}/bin/clawforge-dashboard"
  echo "Done. Removed from ${PREFIX}/bin/"
  exit 0
fi

echo "Installing ClawForge v${VERSION}..."

# Check dependencies
for cmd in bash jq git tmux; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "⚠️  Missing dependency: $cmd"
  fi
done

if $OPENCLAW; then
  # Symlink into OpenClaw skills
  SKILL_DIR="${HOME}/.openclaw/skills/clawforge"
  mkdir -p "$SKILL_DIR"
  ln -sf "${SCRIPT_DIR}/bin/clawforge" "${SKILL_DIR}/clawforge"
  ln -sf "${SCRIPT_DIR}/bin/clawforge-dashboard" "${SKILL_DIR}/clawforge-dashboard"

  # Also add to PATH via symlink
  mkdir -p "${PREFIX}/bin"
  ln -sf "${SCRIPT_DIR}/bin/clawforge" "${PREFIX}/bin/clawforge"
  ln -sf "${SCRIPT_DIR}/bin/clawforge-dashboard" "${PREFIX}/bin/clawforge-dashboard"

  echo "✅ Installed as OpenClaw skill + PATH symlinks"
else
  # Standard install: symlink binaries
  mkdir -p "${PREFIX}/bin"
  ln -sf "${SCRIPT_DIR}/bin/clawforge" "${PREFIX}/bin/clawforge"
  ln -sf "${SCRIPT_DIR}/bin/clawforge-dashboard" "${PREFIX}/bin/clawforge-dashboard"

  echo "✅ Installed to ${PREFIX}/bin/"
fi

echo ""
echo "Verify: clawforge version"
echo "Get started: clawforge help"
