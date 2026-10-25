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
sleep 1
mkdir -p node_modules
YARN
  chmod +x "$dir/yarn"
}

make_failing_fetch_git() {
  local dir="$1"
  local real_git
  real_git="$(command -v git)"
  mkdir -p "$dir"
  cat > "$dir/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ "\$arg" == "fetch" ]]; then
    for line in 1 2 3 4 5; do
      echo "fetch failure detail \$line"
    done
    exit 42
  fi
done
exec "$real_git" "\$@"
EOF
  chmod +x "$dir/git"
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
test -d "$root/repo-worktrees/feature/output"
(cd "$REPO" && WT_CACHE_TTL=0 "$WT_BIN" list) > "$root/running-list.log"
assert_match '^output[[:space:]]+setup' "$root/running-list.log"
wait_for_setup "$REPO" "$root/repo-worktrees/feature/output" feature/output
setup_log="$(setup_log_from_alloc_output "$root/alloc.log")"

assert_contains 'Allocating feature/output' "$root/alloc.log"
assert_contains 'Using free slot: free-1' "$root/alloc.log"
assert_contains 'Worktree created: feature/output' "$root/alloc.log"
assert_contains 'Using base: origin/master' "$setup_log"
assert_contains 'Dependencies installed' "$setup_log"
assert_contains 'Compacted free pool: free-2..free-3 -> free-1..free-2' "$setup_log"
assert_contains 'Allocated: feature/output' "$setup_log"
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
wait_for_setup "$REPO" "$verbose_root/repo-worktrees/feature/output-verbose" feature/output-verbose
verbose_setup_log="$(setup_log_from_alloc_output "$verbose_root/alloc-verbose.log")"

assert_contains 'Creating branch from origin/master' "$verbose_setup_log"
assert_match '^Output:$' "$verbose_setup_log"
assert_contains 'fake-yarn-line-10' "$verbose_setup_log"
assert_contains 'Compacted free pool: free-2 -> free-1' "$verbose_setup_log"
assert_contains 'Closing free slot gap: free-2 -> free-1' "$verbose_setup_log"

failure_root="$(new_test_root)"
failure_bin="$failure_root/bin"
make_failing_fetch_git "$failure_bin"
create_repo_fixture "$failure_root"
(
  cd "$REPO"
  "$WT_BIN" grow > "$failure_root/grow.log"
  PATH="$failure_bin:$PATH" "$WT_BIN" alloc feature/fetch-failure > "$failure_root/failure-alloc.log" 2>&1
)
failure_log="$(setup_log_from_alloc_output "$failure_root/failure-alloc.log")"
wait_for_setup "$REPO" "$failure_root/repo-worktrees/feature/fetch-failure" feature/fetch-failure
assert_contains 'fetch failure detail 1' "$failure_log"
assert_contains 'fetch failure detail 5' "$failure_log"

invalid_base_root="$(new_test_root)"
create_repo_fixture "$invalid_base_root"
(
  cd "$REPO"
  "$WT_BIN" grow > "$invalid_base_root/grow.log"
  "$WT_BIN" alloc --base missing-base feature/invalid-base > "$invalid_base_root/invalid-base-alloc.log" 2>&1
)
invalid_base_log="$(setup_log_from_alloc_output "$invalid_base_root/invalid-base-alloc.log")"
for i in {1..100}; do
  (cd "$REPO" && WT_CACHE_TTL=0 "$WT_BIN" list) > "$invalid_base_root/invalid-base-list.log"
  grep -Eq '^invalid-base[[:space:]]+failed' "$invalid_base_root/invalid-base-list.log" && break
  sleep 0.1
done
assert_match '^invalid-base[[:space:]]+failed' "$invalid_base_root/invalid-base-list.log"
assert_contains "Base ref 'missing-base' does not exist." "$invalid_base_log"
