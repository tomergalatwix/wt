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
assert_contains 'Updated master from origin' "$root/alloc.log"
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
assert_contains 'Allocating feature/realloc...' "$root/realloc.log"
assert_contains 'Using selected free slot' "$root/realloc.log"

(
  cd "$REPO"
  "$WT_BIN" grow > /dev/null
  if "$WT_BIN" realloc free-1 nope --yes > "$root/realloc-free.log" 2>&1; then
    fail 'realloc of free slot unexpectedly succeeded'
  fi
)
assert_contains 'Worktree is already free. Use wt alloc' "$root/realloc-free.log"

direct_root="$(new_test_root)"
create_repo_fixture "$direct_root"
(
  cd "$REPO"
  "$WT_BIN" grow --size 3 > "$direct_root/direct-grow.log"
  "$WT_BIN" alloc feature/direct > "$direct_root/direct-alloc.log" 2>&1
)
test -d "$direct_root/repo-worktrees/feature/direct"
test -d "$direct_root/repo-worktrees/free-1"
test -d "$direct_root/repo-worktrees/free-2"
test ! -e "$direct_root/repo-worktrees/free-3"
assert_eq 'feature/direct' "$(git -C "$direct_root/repo-worktrees/feature/direct" branch --show-current)"
assert_contains 'Using free slot: free-1' "$direct_root/direct-alloc.log"
assert_contains 'Compacted free pool: free-2..free-3 -> free-1..free-2' "$direct_root/direct-alloc.log"
assert_not_contains 'Closing free slot gap:' "$direct_root/direct-alloc.log"
assert_not_match '^Output:$' "$direct_root/direct-alloc.log"
assert_not_match '^\(none\)$' "$direct_root/direct-alloc.log"

gap_root="$(new_test_root)"
create_repo_fixture "$gap_root"
(
  cd "$REPO"
  "$WT_BIN" grow --size 3 > "$gap_root/gap-grow.log"
  "$WT_BIN" alloc --slot "$gap_root/repo-worktrees/free-2" feature/gap > "$gap_root/gap-alloc.log" 2>&1
)
test -d "$gap_root/repo-worktrees/feature/gap"
test -d "$gap_root/repo-worktrees/free-1"
test -d "$gap_root/repo-worktrees/free-2"
test ! -e "$gap_root/repo-worktrees/free-3"
assert_eq 'feature/gap' "$(git -C "$gap_root/repo-worktrees/feature/gap" branch --show-current)"
assert_contains 'Using selected free slot: free-2' "$gap_root/gap-alloc.log"
assert_contains 'Compacted free pool: free-3 -> free-2' "$gap_root/gap-alloc.log"
assert_not_contains 'Closing free slot gap:' "$gap_root/gap-alloc.log"
assert_not_match '^Output:$' "$gap_root/gap-alloc.log"
assert_not_match '^\(none\)$' "$gap_root/gap-alloc.log"
