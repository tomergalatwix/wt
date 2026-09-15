#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"

(
  cd "$REPO"
  "$WT_BIN" grow --size 10 > "$root/grow.log"
)
git -C "$REPO" worktree add -q "$root/repo-worktrees/work-one" -b work-one origin/master

(cd "$REPO" && "$WT_BIN" list > "$root/list.log")

awk '
  $1 == "main" || $1 == "work-one" || $1 ~ /^free-[0-9]+$/ {
    if ($1 ~ /^free-[0-9]+$/) {
      seen_free = 1
    } else if (seen_free) {
      print "non-free worktree after free slot: " $1 > "/dev/stderr"
      exit 1
    }
  }
' "$root/list.log" || fail "free slots were not grouped at the bottom"

expected=$'free-1\nfree-10\nfree-2\nfree-3\nfree-4\nfree-5\nfree-6\nfree-7\nfree-8\nfree-9'
actual="$(awk '$1 ~ /^free-[0-9]+$/ { print $1 }' "$root/list.log")"
assert_eq "$expected" "$actual"
