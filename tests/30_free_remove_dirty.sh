#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"

git -C "$REPO" worktree add -q "$root/dirty-free" -b dirty-free origin/master
printf 'dirty\n' >> "$root/dirty-free/README.md"
if (cd "$REPO" && "$WT_BIN" free "$root/dirty-free" > "$root/free-no-force.log" 2>&1); then
  fail 'dirty free without force unexpectedly succeeded'
fi
assert_contains 'Changed files:' "$root/free-no-force.log"
assert_contains 'M README.md' "$root/free-no-force.log"
assert_contains '--force or -f' "$root/free-no-force.log"

(cd "$REPO" && "$WT_BIN" free "$root/dirty-free" -f > "$root/free-force.log" 2>&1)
assert_contains 'continuing because --force/-f was provided' "$root/free-force.log"
free_path="$(awk '/^Path: / { print $2 }' "$root/free-force.log" | tail -n1)"
test -n "$free_path"
grep -q 'dirty' "$free_path/README.md"
test -n "$(git -C "$free_path" status --porcelain)"

git -C "$REPO" worktree add -q "$root/remove-me" -b remove-me origin/master
(cd "$REPO" && "$WT_BIN" remove "$root/remove-me" --yes > "$root/remove.log")
assert_contains 'Removed: remove-me' "$root/remove.log"
if git -C "$REPO" worktree list --porcelain | grep -q "worktree $root/remove-me"; then
  fail 'removed worktree is still registered'
fi

git -C "$REPO" worktree add -q "$root/dirty-realloc" -b dirty-realloc origin/master
printf 'carry\n' >> "$root/dirty-realloc/README.md"
(cd "$REPO" && "$WT_BIN" realloc "$root/dirty-realloc" feature/dirty-realloc --yes -f > "$root/realloc-force.log" 2>&1)
assert_contains 'Changed files:' "$root/realloc-force.log"
assert_contains 'Reallocated slot is dirty' "$root/realloc-force.log"
new_path="$root/repo-worktrees/feature/dirty-realloc"
test -d "$new_path"
assert_eq 'feature/dirty-realloc' "$(git -C "$new_path" branch --show-current)"
grep -q 'carry' "$new_path/README.md"
