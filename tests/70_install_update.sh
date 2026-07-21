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

sha="1234567890abcdef1234567890abcdef12345678"
raw_root="$root/raw"
mkdir -p "$raw_root/$sha"
cp "$WT_REPO_ROOT/install.sh" "$raw_root/$sha/install.sh"
mkdir -p "$raw_root/$sha/bin" "$raw_root/$sha/shell"
cp "$WT_REPO_ROOT/bin/wt" "$raw_root/$sha/bin/wt"
cp "$WT_REPO_ROOT/shell/wt.zsh" "$raw_root/$sha/shell/wt.zsh"

PATH="$install_dir:$PATH" WT_REPO_REF="$sha" WT_REPO_RAW_ROOT="file://$raw_root" WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" "$install_dir/wt" update > "$root/update-sha.log"
assert_contains "Downloading installer from: file://$raw_root/$sha/install.sh" "$root/update-sha.log"
assert_contains 'wt installed.' "$root/update-sha.log"
