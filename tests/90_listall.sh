#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
export XDG_STATE_HOME="$root/state"
registry="$XDG_STATE_HOME/wt/repos"
outside="$root/outside"
mkdir -p "$outside"

(cd "$outside" && "$WT_BIN" listall > "$root/empty.log")
assert_contains 'No repos registered yet.' "$root/empty.log"

mkdir -p "$root/a" "$root/b"
create_repo_fixture "$root/a"
repo_a="$(cd "$REPO" && pwd -P)"
create_repo_fixture "$root/b"
repo_b="$(cd "$REPO" && pwd -P)"

(cd "$repo_a" && "$WT_BIN" grow > /dev/null)
(cd "$repo_a" && "$WT_BIN" list > /dev/null)
(cd "$repo_b" && "$WT_BIN" list > /dev/null)
assert_eq 2 "$(wc -l < "$registry" | tr -d ' ')"

(cd "$outside" && WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall.log")
assert_contains "repo  $repo_a" "$root/listall.log"
assert_contains "repo  $repo_b" "$root/listall.log"
assert_match '^free-1[[:space:]]' "$root/listall.log"
assert_eq 2 "$(grep -c '^NAME' "$root/listall.log")"
assert_contains '3 worktrees across 2 repos' "$root/listall.log"

(cd "$outside" && WT_COLOR=1 WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall-color.log")
assert_contains "$(printf '\033[1;34mrepo  %s' "$repo_a")" "$root/listall-color.log"

rm -rf "$root/b"
(cd "$outside" && WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall-pruned.log")
assert_not_contains "$repo_b" "$root/listall-pruned.log"
assert_contains '2 worktrees across 1 repo' "$root/listall-pruned.log"
assert_eq "$repo_a" "$(cat "$registry")"
