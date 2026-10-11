#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

make_fake_yarn() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/yarn" <<'YARN'
#!/usr/bin/env bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  echo "fake-yarn-line-$i"
done
mkdir -p node_modules
YARN
  chmod +x "$dir/yarn"
}

root="$(new_test_root)"
fake_bin="$root/bin"
make_fake_yarn "$fake_bin"

create_repo_fixture_with_yarn "$root"
(
  cd "$REPO"
  PATH="$fake_bin:$PATH" "$WT_BIN" grow --size 3 > "$root/grow.log"
  PATH="$fake_bin:$PATH" "$WT_BIN" alloc feature/output > "$root/alloc.log" 2>&1
)

assert_contains 'Allocating feature/output' "$root/alloc.log"
assert_contains 'Updated master from origin' "$root/alloc.log"
assert_contains 'Using free slot: free-1' "$root/alloc.log"
assert_contains 'Dependencies installed' "$root/alloc.log"
assert_contains 'Compacted free pool: free-2..free-3 -> free-1..free-2' "$root/alloc.log"
assert_contains 'Allocated: feature/output' "$root/alloc.log"
assert_not_contains 'Pool:' "$root/alloc.log"
assert_not_contains 'Git hooks:' "$root/alloc.log"
assert_not_contains 'Moving worktree:' "$root/alloc.log"
assert_not_contains 'Moving worktree into branch slot' "$root/alloc.log"
assert_not_contains 'Closing free slot gap:' "$root/alloc.log"
assert_not_match '^Output:$' "$root/alloc.log"
assert_not_match '^\(none\)$' "$root/alloc.log"
assert_not_match '^fake-yarn-line-[0-9]+$' "$root/alloc.log"

verbose_root="$(new_test_root)"
verbose_fake_bin="$verbose_root/bin"
make_fake_yarn "$verbose_fake_bin"
create_repo_fixture_with_yarn "$verbose_root"
(
  cd "$REPO"
  PATH="$verbose_fake_bin:$PATH" "$WT_BIN" grow --size 2 > "$verbose_root/grow.log"
  PATH="$verbose_fake_bin:$PATH" "$WT_BIN" alloc --verbose feature/output-verbose > "$verbose_root/alloc-verbose.log" 2>&1
)

assert_contains 'Alloc requested for branch: feature/output-verbose' "$verbose_root/alloc-verbose.log"
assert_contains 'Pool:' "$verbose_root/alloc-verbose.log"
assert_contains 'Git hooks:' "$verbose_root/alloc-verbose.log"
assert_contains 'Moving worktree:' "$verbose_root/alloc-verbose.log"
assert_match '^Output:$' "$verbose_root/alloc-verbose.log"
assert_contains 'fake-yarn-line-10' "$verbose_root/alloc-verbose.log"
assert_contains 'Compacted free pool: free-2 -> free-1' "$verbose_root/alloc-verbose.log"
assert_contains 'Closing free slot gap: free-2 -> free-1' "$verbose_root/alloc-verbose.log"
