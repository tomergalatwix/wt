#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WT_INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${WT_CONFIG_DIR:-$HOME/.config/wt}"
SHELL_RC="${WT_SHELL_RC:-$HOME/.zshrc}"

REPO_RAW_BASE="${WT_REPO_RAW_BASE:-https://raw.githubusercontent.com/tomergalatwix/wt/master}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_from_local_repo() {
  [[ -f "$SCRIPT_DIR/bin/wt" && -f "$SCRIPT_DIR/shell/wt.zsh" ]]
}

download_file() {
  local url="$1"
  local dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    echo "Error: install requires curl or wget" >&2
    exit 1
  fi
}

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"

if install_from_local_repo; then
  cp "$SCRIPT_DIR/bin/wt" "$INSTALL_DIR/wt"
  cp "$SCRIPT_DIR/shell/wt.zsh" "$CONFIG_DIR/wt.zsh"
else
  download_file "$REPO_RAW_BASE/bin/wt" "$INSTALL_DIR/wt"
  download_file "$REPO_RAW_BASE/shell/wt.zsh" "$CONFIG_DIR/wt.zsh"
fi

chmod +x "$INSTALL_DIR/wt"

source_line='source "$HOME/.config/wt/wt.zsh"'
path_line='export PATH="$PATH:$HOME/.local/bin"'

touch "$SHELL_RC"

if ! grep -Fq '$HOME/.local/bin' "$SHELL_RC"; then
  {
    echo ""
    echo "# wt"
    echo "$path_line"
  } >>"$SHELL_RC"
fi

if ! grep -Fq "$source_line" "$SHELL_RC"; then
  {
    echo ""
    echo "# wt shell integration"
    echo "$source_line"
  } >>"$SHELL_RC"
fi

if ! command -v fzf >/dev/null 2>&1; then
  cat <<'EOF'
wt installed, but fzf is missing.

Install fzf:
  brew install fzf

EOF
fi

cat <<EOF
wt installed.

Binary: $INSTALL_DIR/wt
Shell integration: $CONFIG_DIR/wt.zsh

Reload your shell:
  source "$SHELL_RC"

Try:
  wt
  wt list
EOF
