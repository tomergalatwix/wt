#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"

(
  cd "$REPO"
  "$WT_BIN" grow > "$root/grow.log"
  "$WT_BIN" alloc feature/alloc > "$root/alloc.log" 2>&1
)
assert_not_contains '__WT_ALLOCATED__' "$root/alloc.log"
assert_contains 'Updating master from origin' "$root/alloc.log"
assert_contains 'Allocated: feature/alloc' "$root/alloc.log"
assert_eq 'feature/alloc' "$(git -C "$root/repo-worktrees/feature/alloc" branch --show-current)"

if (cd "$REPO" && "$WT_BIN" create old-name > "$root/create.log" 2>&1); then
  fail 'wt create unexpectedly succeeded'
fi
assert_contains 'Unknown command: create' "$root/create.log"

git -C "$REPO" worktree add -q "$root/external-old" -b external-old origin/master
(
  cd "$root/external-old"
  "$WT_BIN" realloc "$root/external-old" feature/realloc --yes > "$root/realloc.log"
)
new_path="$root/repo-worktrees/feature/realloc"
test -d "$new_path"
assert_eq 'feature/realloc' "$(git -C "$new_path" branch --show-current)"
if git -C "$REPO" worktree list --porcelain | grep -q "worktree $root/external-old"; then
  fail 'old external worktree is still registered'
fi
assert_contains 'Moving selected worktree to temporary free slot' "$root/realloc.log"
assert_contains 'Using reallocated slot' "$root/realloc.log"

(
  cd "$REPO"
  "$WT_BIN" grow > /dev/null
  if "$WT_BIN" realloc free-1 nope --yes > "$root/realloc-free.log" 2>&1; then
    fail 'realloc of free slot unexpectedly succeeded'
  fi
)
assert_contains 'Worktree is already free. Use wt alloc' "$root/realloc-free.log"
