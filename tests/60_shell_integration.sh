#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"

PATH="$(dirname "$WT_BIN"):$PATH" zsh -lc "source '$WT_SHELL'; cd '$REPO'; WT_COLOR=0 wt grow > '$root/grow.log'; WT_COLOR=0 wt alloc feature/shell > '$root/alloc.log'; pwd" > "$root/alloc-pwd.log"
alloc_pwd="$(tail -n1 "$root/alloc-pwd.log")"
assert_eq "$(cd "$root/repo-worktrees/feature/shell" && pwd -P)" "$(cd "$alloc_pwd" && pwd -P)"
assert_not_contains '__WT_ALLOCATED__' "$root/alloc.log"

PATH="$(dirname "$WT_BIN"):$PATH" zsh -lc "source '$WT_SHELL'; cd '$root/repo-worktrees/feature/shell'; wt go main; pwd" > "$root/go-main-pwd.log"
main_pwd="$(tail -n1 "$root/go-main-pwd.log")"
assert_eq "$(cd "$REPO" && pwd -P)" "$(cd "$main_pwd" && pwd -P)"

git -C "$REPO" worktree add -q "$root/repo-worktrees/to-free" -b to-free origin/master
mkdir -p "$root/repo-worktrees/to-free/subdir"
PATH="$(dirname "$WT_BIN"):$PATH" zsh -lc "source '$WT_SHELL'; cd '$root/repo-worktrees/to-free/subdir'; WT_COLOR=0 wt free '$root/repo-worktrees/to-free' > '$root/free.log'; pwd" > "$root/free-pwd.log"
free_pwd="$(tail -n1 "$root/free-pwd.log")"
assert_eq "$(cd "$root/repo-worktrees/free-1/subdir" && pwd -P)" "$free_pwd"
assert_not_contains '__WT_FREED__' "$root/free.log"
