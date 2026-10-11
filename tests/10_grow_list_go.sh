#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"

(cd "$REPO" && "$WT_BIN" grow --size 2 > "$root/grow.log")
test -d "$root/repo-worktrees/free-1"
test -d "$root/repo-worktrees/free-2"
assert_contains 'Growing worktree pool: adding 2 slot(s)...' "$root/grow.log"
assert_contains 'Added free-1' "$root/grow.log"
assert_contains 'Added free-2' "$root/grow.log"

(cd "$REPO" && "$WT_BIN" list > "$root/list.log")
assert_contains 'NAME' "$root/list.log"
assert_contains 'BRANCH' "$root/list.log"
assert_contains 'main' "$root/list.log"
assert_contains 'free-1' "$root/list.log"
assert_contains 'free-2' "$root/list.log"
assert_contains '3 worktrees total' "$root/list.log"

printf 'tracked\n' >> "$root/repo-worktrees/free-1/README.md"
printf 'untracked\n' > "$root/repo-worktrees/free-2/generated.tmp"
(cd "$REPO" && WT_CACHE_TTL=0 "$WT_BIN" list > "$root/list-status.log")
assert_eq 'dirty' "$(awk '$1 == "free-1" { print $2 }' "$root/list-status.log")"
assert_eq 'clean' "$(awk '$1 == "free-2" { print $2 }' "$root/list-status.log")"

free_path="$(cd "$REPO" && "$WT_BIN" go free-1 --print-path)"
assert_eq "$(cd "$root/repo-worktrees/free-1" && pwd -P)" "$(cd "$free_path" && pwd -P)"

main_path="$(cd "$root/repo-worktrees/free-1" && "$WT_BIN" go main --print-path)"
assert_eq "$(cd "$REPO" && pwd -P)" "$(cd "$main_path" && pwd -P)"

(cd "$REPO" && "$WT_BIN" go main > "$root/go-main.log")
assert_contains 'Found worktree main:' "$root/go-main.log"
assert_contains 'Run: cd ' "$root/go-main.log"

if (cd "$REPO" && "$WT_BIN" go missing-worktree > "$root/go-missing.log" 2>&1); then
  fail 'wt go missing-worktree unexpectedly succeeded'
fi
assert_contains "Could not find worktree containing 'missing-worktree'." "$root/go-missing.log"

git -C "$REPO" worktree add -q "$root/repo-worktrees/amb-one" -b amb-one origin/master
git -C "$REPO" worktree add -q "$root/repo-worktrees/amb-two" -b amb-two origin/master
if (cd "$REPO" && "$WT_BIN" go amb > "$root/go-ambiguous.log" 2>&1); then
  fail 'wt go amb unexpectedly succeeded'
fi
assert_contains "Ambiguous worktree query 'amb':" "$root/go-ambiguous.log"
assert_contains 'amb-one (amb-one)' "$root/go-ambiguous.log"
assert_contains 'amb-two (amb-two)' "$root/go-ambiguous.log"
