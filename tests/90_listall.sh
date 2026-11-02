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
# Columns line up across repos even though their widest names differ.
assert_eq 1 "$(grep '^NAME' "$root/listall.log" | sort -u | wc -l | tr -d ' ')"

root_p="$(cd "$root" && pwd -P)"
(cd "$outside" && HOME="$root_p" WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall-home.log")
assert_contains "repo  ~/${repo_a#"$root_p"/}" "$root/listall-home.log"

(cd "$outside" && WT_COLOR=1 WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall-color.log")
assert_contains "$(printf '\033[1;34mrepo  %s' "$repo_a")" "$root/listall-color.log"

(cd "$outside" && XDG_STATE_HOME="$root/discovered" "$WT_BIN" discover "$root" > "$root/discover.log")
assert_contains 'Registered 1 repo(s) with worktree pools.' "$root/discover.log"
assert_eq "$repo_a" "$(cat "$root/discovered/wt/repos")"

rm -rf "$root/b"
(cd "$outside" && WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall-pruned.log")
assert_not_contains "$repo_b" "$root/listall-pruned.log"
assert_contains '2 worktrees across 1 repo' "$root/listall-pruned.log"
assert_eq "$repo_a" "$(cat "$registry")"

# Order: most worktrees first, then the repo with the newest worktree.
mkdir -p "$root/c" "$root/d"
create_repo_fixture "$root/c"
repo_c="$(cd "$REPO" && pwd -P)"
create_repo_fixture "$root/d"
repo_d="$(cd "$REPO" && pwd -P)"
(cd "$repo_c" && "$WT_BIN" list > /dev/null)
(cd "$repo_d" && "$WT_BIN" list > /dev/null)
touch -t 202001010000 "$repo_c"
(cd "$outside" && WT_CACHE_TTL=0 "$WT_BIN" listall > "$root/listall-order.log")
assert_eq "$repo_a $repo_d $repo_c" "$(awk '$1 == "repo" { printf "%s%s", sep, $2; sep = " " }' "$root/listall-order.log")"

# Registration is best-effort: an unusable state dir must not break commands.
: > "$root/state-is-a-file"
(cd "$repo_a" && XDG_STATE_HOME="$root/state-is-a-file" "$WT_BIN" list > "$root/list-bad-state.log")
assert_contains 'worktrees total' "$root/list-bad-state.log"

# Spotlight results reach pools deeper than the fallback scan.
deep="$root/deep/x/y/z"
mkdir -p "$deep"
create_repo_fixture "$deep"
repo_deep="$(cd "$REPO" && pwd -P)"
(cd "$repo_deep" && XDG_STATE_HOME="$root/scratch-state" "$WT_BIN" grow > /dev/null)
fake_bin="$root/fake-bin"
mkdir -p "$fake_bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s-worktrees"\n' "$deep/repo" > "$fake_bin/mdfind"
chmod +x "$fake_bin/mdfind"
(cd "$outside" && PATH="$fake_bin:$PATH" XDG_STATE_HOME="$root/spotlight" "$WT_BIN" discover "$root/deep" > /dev/null)
assert_eq "$repo_deep" "$(cat "$root/spotlight/wt/repos")"
