#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
install_dir="$root/bin"
config_dir="$root/config/wt"
shell_rc="$root/zshrc"
mkdir -p "$root/home"

(
  cd "$WT_REPO_ROOT"
  HOME="$root/home" WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" ./install.sh > "$root/install.log"
)

test -x "$install_dir/wt"
test -f "$config_dir/wt.zsh"
assert_contains 'wt installed.' "$root/install.log"
assert_contains 'source "$HOME/.config/wt/wt.zsh"' "$shell_rc"

PATH="$install_dir:$PATH" WT_REPO_RAW_BASE="file://$WT_REPO_ROOT" WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" "$install_dir/wt" update > "$root/update.log"
assert_contains 'Downloading installer from: file://' "$root/update.log"
assert_contains 'wt installed.' "$root/update.log"
