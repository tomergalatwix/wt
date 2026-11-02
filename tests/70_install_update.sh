#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
install_dir="$root/bin"
config_dir="$root/config/wt"
shell_rc="$root/zshrc"
mkdir -p "$root/home"
export HOME="$root/home"

(
  cd "$root"
  HOME="$root/home" WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" "$WT_REPO_ROOT/install.sh" > "$root/install.log"
)

test -x "$install_dir/wt"
test -f "$config_dir/wt.zsh"
assert_contains 'wt installed.' "$root/install.log"
assert_contains 'Registered 0 repo(s) with worktree pools.' "$root/install.log"
assert_contains "Added wt to $shell_rc" "$root/install.log"
# shellcheck disable=SC2016
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
assert_contains 'Registered 0 repo(s) with worktree pools.' "$root/update.log"
assert_not_contains 'Added wt to' "$root/update.log"
assert_not_contains 'source' "$root/update.log"

# Updating replaces the running script; it must not read the new file at its
# old offset (that ran fragments of the new file as commands).
shifted="$root/shifted"
mkdir -p "$shifted/bin" "$shifted/shell"
cp "$WT_REPO_ROOT/install.sh" "$shifted/install.sh"
cp "$WT_REPO_ROOT/shell/wt.zsh" "$shifted/shell/wt.zsh"
{
  sed -n 1p "$WT_REPO_ROOT/bin/wt"
  for _ in {1..300}; do echo '# padding that shifts every offset'; done
  sed 1d "$WT_REPO_ROOT/bin/wt"
} > "$shifted/bin/wt"
cp "$WT_REPO_ROOT/bin/wt" "$install_dir/wt"
PATH="$install_dir:$PATH" WT_REPO_RAW_BASE="file://$shifted" WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" "$install_dir/wt" update > "$root/update-shift.log" 2>&1
assert_contains 'wt installed.' "$root/update-shift.log"
assert_not_contains 'command not found' "$root/update-shift.log"
assert_not_contains 'syntax error' "$root/update-shift.log"
cmp -s "$shifted/bin/wt" "$install_dir/wt" || fail 'update did not install the new binary'

"$WT_REPO_ROOT/bin/wt" version > "$root/version.log"
assert_contains 'wt dev' "$root/version.log"
"$WT_REPO_ROOT/bin/wt" --version > "$root/version.log"
assert_contains 'wt dev' "$root/version.log"

# Releases: the newest vX.Y.Z tag wins numerically; annotated tags resolve to
# their commit; without tags, master is used.
releases="$root/releases"
git init -q -b master "$releases"
rgit() { git -C "$releases" -c user.name='wt test' -c user.email=wt@example.com "$@"; }
rgit commit -q --allow-empty -m one
rgit tag v1.9.0
rgit commit -q --allow-empty -m two
rgit tag -a v1.10.0 -m v1.10.0
tag_sha="$(rgit rev-parse HEAD)"
rgit tag v2.0.0-beta
rgit commit -q --allow-empty -m three
master_sha="$(rgit rev-parse HEAD)"
old_sha="$(rgit rev-parse v1.9.0)"
for sha in "$tag_sha" "$master_sha" "$old_sha"; do
  mkdir -p "$raw_root/$sha"
  cp -R "$raw_root/1234567890abcdef1234567890abcdef12345678/." "$raw_root/$sha/"
done

update_from() {
  PATH="$install_dir:$PATH" WT_REPO_URL="$releases" WT_REPO_RAW_ROOT="file://$raw_root" WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" "$@" > "$root/update-ref.log"
}
update_from "$install_dir/wt" update
assert_contains "Downloading installer from: file://$raw_root/$tag_sha/install.sh" "$root/update-ref.log"
update_from env WT_REPO_REF=v1.9.0 "$install_dir/wt" update
assert_contains "file://$raw_root/$old_sha/install.sh" "$root/update-ref.log"
update_from env WT_REPO_REF=master "$install_dir/wt" update
assert_contains "file://$raw_root/$master_sha/install.sh" "$root/update-ref.log"
update_from bash "$WT_REPO_ROOT/update.sh"
assert_contains 'wt installed.' "$root/update-ref.log"
rgit tag -d v1.9.0 v1.10.0 v2.0.0-beta > /dev/null
update_from "$install_dir/wt" update
assert_contains "file://$raw_root/$master_sha/install.sh" "$root/update-ref.log"
rgit tag -a v1.10.0 -m v1.10.0 "$tag_sha"

# Update prompt: needs a terminal, so run through script(1).
released="$root/released-wt"
sed 's/^WT_VERSION="dev"$/WT_VERSION="1.2.0"/' "$WT_REPO_ROOT/bin/wt" > "$released"
chmod +x "$released"
grep -qx 'WT_VERSION="1.2.0"' "$released" || fail 'could not stamp a version'
export XDG_STATE_HOME="$root/state"
state="$XDG_STATE_HOME/wt/update-check"
mkdir -p "${state%/*}"
in_tty() {
  local input="$1"
  shift
  { sleep 0.5; printf '%s' "$input"; sleep 0.5; } | PATH="$install_dir:$PATH" WT_REPO_URL="$releases" WT_REPO_RAW_BASE="file://$WT_REPO_ROOT" \
    WT_INSTALL_DIR="$install_dir" WT_CONFIG_DIR="$config_dir" WT_SHELL_RC="$shell_rc" \
    script -q "$root/tty.log" "$@" > /dev/null
}

# A stale check refreshes the latest tag in the background without prompting.
printf '0 0 \n' > "$state"
in_tty '' "$released" listall
assert_not_contains 'is available' "$root/tty.log"
for _ in {1..50}; do
  grep -q 'v1.10.0$' "$state" && break
  sleep 0.1
done
assert_match '^[0-9]+ 0 v1.10.0$' "$state"

# Not a terminal: never prompts.
"$released" listall > "$root/notty.log" 2>&1
assert_not_contains 'is available' "$root/notty.log"

# Declining snoozes for a week.
now="$(date +%s)"
printf '%s 0 v1.10.0\n' "$now" > "$state"
in_tty $'n\n' "$released" listall
assert_contains 'wt v1.10.0 is available (you have v1.2.0). Update now? [Y/n]' "$root/tty.log"
assert_contains 'wt will ask again in a week' "$root/tty.log"
read -r _ snoozed _ < "$state"
((snoozed >= now + 7 * 86400)) || fail "decline should snooze a week, got $snoozed"
in_tty '' "$released" listall
assert_not_contains 'is available' "$root/tty.log"

# Same or older release: no prompt.
printf '%s 0 v1.2.0\n' "$now" > "$state"
in_tty '' "$released" listall
assert_not_contains 'is available' "$root/tty.log"

# Opted out, or a command that must stay fast: no prompt.
printf '%s 0 v1.10.0\n' "$now" > "$state"
in_tty '' env WT_NO_UPDATE_CHECK=1 "$released" listall
assert_not_contains 'is available' "$root/tty.log"
in_tty '' "$released" version
assert_not_contains 'is available' "$root/tty.log"

# Accepting updates, then runs the original command.
in_tty $'y\n' "$released" listall
assert_contains 'Update now? [Y/n]' "$root/tty.log"
assert_contains 'wt installed.' "$root/tty.log"
assert_contains 'Registered 0 repo(s) with worktree pools.' "$root/tty.log"
assert_contains 'No repos registered yet' "$root/tty.log"
