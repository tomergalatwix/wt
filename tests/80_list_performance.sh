#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# `wt list` reads live state with a fixed number of processes per repo: the
# git and stat call counts must not grow with the number of worktrees, and it
# must never scan worktree contents.

root="$(new_test_root)"
create_repo_fixture "$root"

fake_bin="$root/bin"
mkdir -p "$fake_bin"
for tool in git stat; do
  cat > "$fake_bin/$tool" <<FAKE
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$root/$tool.calls"
case "\$*" in
  *" status --porcelain"*|*" ls-files --others"*|*" diff-index "*)
    echo "wt list must not scan worktree contents: \$*" >&2
    exit 42
    ;;
esac
exec "$(command -v "$tool")" "\$@"
FAKE
  chmod +x "$fake_bin/$tool"
done

list_with_counts() {
  rm -f "$root/git.calls" "$root/stat.calls"
  (cd "$REPO" && PATH="$fake_bin:$PATH" "$WT_BIN" list > "$root/list.log")
  printf '%s %s\n' "$(wc -l < "$root/git.calls" | tr -d ' ')" "$(wc -l < "$root/stat.calls" | tr -d ' ')"
}

(cd "$REPO" && "$WT_BIN" grow --size 2 > /dev/null)
small="$(list_with_counts)"
assert_contains '3 worktrees total' "$root/list.log"

(cd "$REPO" && "$WT_BIN" grow --size 8 > /dev/null)
large="$(list_with_counts)"
assert_contains '11 worktrees total' "$root/list.log"

assert_eq "$small" "$large"
assert_eq 1 "${large#* }"
git_calls="${large% *}"
((git_calls <= 2)) || fail "wt list ran git $git_calls times; expected <= 2"
