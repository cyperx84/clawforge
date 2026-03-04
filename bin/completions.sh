#!/usr/bin/env bash
# completions.sh — Install shell completions for clawforge
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMP_DIR="${SCRIPT_DIR}/../completions"

usage() {
  cat <<EOF
Usage: clawforge completions <shell>

Install tab completions for clawforge.

Shells:
  bash       Install bash completions
  zsh        Install zsh completions
  fish       Install fish completions
  --help     Show this help

Examples:
  clawforge completions bash
  clawforge completions zsh
  clawforge completions fish

After installing, restart your shell or source the completion file.
EOF
}

[[ $# -eq 0 ]] && { usage; exit 0; }

case "$1" in
  bash)
    DEST="${BASH_COMPLETION_USER_DIR:-${HOME}/.local/share/bash-completion/completions}"
    mkdir -p "$DEST"
    cp "$COMP_DIR/clawforge.bash" "$DEST/clawforge"
    echo "Installed bash completions to $DEST/clawforge"
    echo "Restart your shell or run: source $DEST/clawforge"
    ;;
  zsh)
    # Try homebrew zsh completions first, then user dir
    if [[ -d "/opt/homebrew/share/zsh/site-functions" ]]; then
      DEST="/opt/homebrew/share/zsh/site-functions"
    elif [[ -d "${HOME}/.zsh/completions" ]]; then
      DEST="${HOME}/.zsh/completions"
    else
      DEST="${HOME}/.zsh/completions"
      mkdir -p "$DEST"
      echo "Add to .zshrc: fpath=(~/.zsh/completions \$fpath)"
    fi
    cp "$COMP_DIR/_clawforge" "$DEST/_clawforge"
    echo "Installed zsh completions to $DEST/_clawforge"
    echo "Run: rm -f ~/.zcompdump && compinit"
    ;;
  fish)
    DEST="${HOME}/.config/fish/completions"
    mkdir -p "$DEST"
    cp "$COMP_DIR/clawforge.fish" "$DEST/clawforge.fish"
    echo "Installed fish completions to $DEST/clawforge.fish"
    ;;
  --help|-h)
    usage
    ;;
  *)
    echo "Unknown shell: $1"
    echo "Supported: bash, zsh, fish"
    exit 1
    ;;
esac
