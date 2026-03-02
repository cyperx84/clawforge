#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=""
BIN_DIR="${HOME}/.local/bin"

usage() {
  cat <<USAGE
Usage: ./install.sh [--openclaw|--standalone] [--bin-dir <path>]

Modes:
  --openclaw    Install as OpenClaw skill + CLI symlink
  --standalone  Install CLI symlink only

Options:
  --bin-dir     Override bin directory (default: ~/.local/bin)
  -h, --help    Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openclaw) MODE="openclaw"; shift ;;
    --standalone) MODE="standalone"; shift ;;
    --bin-dir)
      BIN_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  if [[ -d "${HOME}/.openclaw" ]]; then
    MODE="openclaw"
  else
    MODE="standalone"
  fi
fi

mkdir -p "$BIN_DIR"
ln -sf "${SCRIPT_DIR}/bin/clawforge" "${BIN_DIR}/clawforge"

echo "✅ Linked CLI: ${BIN_DIR}/clawforge -> ${SCRIPT_DIR}/bin/clawforge"

if [[ "$MODE" == "openclaw" ]]; then
  SKILL_DIR="${HOME}/.openclaw/skills/clawforge"
  mkdir -p "${SKILL_DIR}/scripts"
  ln -sf "${SCRIPT_DIR}/SKILL.md" "${SKILL_DIR}/SKILL.md"
  ln -sf "${SCRIPT_DIR}/bin/clawforge" "${SKILL_DIR}/scripts/clawforge"
  echo "✅ Wired OpenClaw skill in ${SKILL_DIR}"
fi

echo
if command -v clawforge >/dev/null 2>&1; then
  echo "Installed: $(clawforge version)"
else
  echo "⚠️  'clawforge' not found in PATH yet. Add '${BIN_DIR}' to PATH."
fi

echo "Try: clawforge help"
