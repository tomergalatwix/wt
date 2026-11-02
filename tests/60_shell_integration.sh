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
assert_contains 'Switched to worktree main.' "$root/go-main-pwd.log"
main_pwd="$(tail -n1 "$root/go-main-pwd.log")"
assert_eq "$(cd "$REPO" && pwd -P)" "$(cd "$main_pwd" && pwd -P)"

if PATH="$(dirname "$WT_BIN"):$PATH" zsh -lc "source '$WT_SHELL'; cd '$REPO'; wt go missing-worktree" > "$root/go-missing-shell.log" 2>&1; then
  fail 'shell wt go missing-worktree unexpectedly succeeded'
fi
assert_contains "Could not find worktree containing 'missing-worktree'." "$root/go-missing-shell.log"

git -C "$REPO" worktree add -q "$root/repo-worktrees/to-free" -b to-free origin/master
mkdir -p "$root/repo-worktrees/to-free/subdir"
PATH="$(dirname "$WT_BIN"):$PATH" zsh -lc "source '$WT_SHELL'; cd '$root/repo-worktrees/to-free/subdir'; WT_COLOR=0 wt free '$root/repo-worktrees/to-free' > '$root/free.log'; pwd" > "$root/free-pwd.log"
free_pwd="$(tail -n1 "$root/free-pwd.log")"
assert_eq "$(cd "$root/repo-worktrees/free-1/subdir" && pwd -P)" "$free_pwd"
assert_not_contains '__WT_FREED__' "$root/free.log"

# An open shell picks up a changed wrapper file on its next wt call.
cp "$WT_SHELL" "$root/wt.zsh"
PATH="$(dirname "$WT_BIN"):$PATH" zsh -lc "source '$root/wt.zsh'; cd '$REPO'; wt list > /dev/null; printf '\\n__wt_reloaded() { print reloaded; }\\n' >> '$root/wt.zsh'; touch -t 203001010000 '$root/wt.zsh'; wt list > /dev/null; __wt_reloaded" > "$root/reload.log" 2>&1
assert_eq 'reloaded' "$(tail -n1 "$root/reload.log")"

