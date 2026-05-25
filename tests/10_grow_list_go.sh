#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"

(cd "$REPO" && "$WT_BIN" grow --size 2 > "$root/grow.log")
test -d "$root/repo-worktrees/free-1"
test -d "$root/repo-worktrees/free-2"
assert_contains 'Creating detached worktree free-1' "$root/grow.log"
assert_contains 'Creating detached worktree free-2' "$root/grow.log"

(cd "$REPO" && "$WT_BIN" list > "$root/list.log")
assert_contains 'NAME' "$root/list.log"
assert_contains 'BRANCH' "$root/list.log"
assert_contains 'main' "$root/list.log"
assert_contains 'free-1' "$root/list.log"
assert_contains 'free-2' "$root/list.log"
assert_contains '3 worktrees total' "$root/list.log"

free_path="$(cd "$REPO" && "$WT_BIN" go free-1 --print-path)"
assert_eq "$(cd "$root/repo-worktrees/free-1" && pwd -P)" "$(cd "$free_path" && pwd -P)"

main_path="$(cd "$root/repo-worktrees/free-1" && "$WT_BIN" go main --print-path)"
assert_eq "$(cd "$REPO" && pwd -P)" "$(cd "$main_path" && pwd -P)"
