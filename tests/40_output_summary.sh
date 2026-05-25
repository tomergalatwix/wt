#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
fake_bin="$root/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/yarn" <<'YARN'
#!/usr/bin/env bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  echo "fake-yarn-line-$i"
done
mkdir -p node_modules
YARN
chmod +x "$fake_bin/yarn"

create_repo_fixture_with_yarn "$root"
(
  cd "$REPO"
  PATH="$fake_bin:$PATH" "$WT_BIN" grow > "$root/grow.log"
  PATH="$fake_bin:$PATH" "$WT_BIN" alloc feature/output > "$root/alloc.log" 2>&1
)
assert_contains 'Updating master from origin' "$root/alloc.log"
assert_contains 'Installing new dependencies' "$root/alloc.log"
assert_match '^Output:$' "$root/alloc.log"
assert_match '^\.\.\.$' "$root/alloc.log"
assert_contains 'fake-yarn-line-8' "$root/alloc.log"
assert_contains 'fake-yarn-line-9' "$root/alloc.log"
assert_contains 'fake-yarn-line-10' "$root/alloc.log"
assert_not_match '^fake-yarn-line-1$' "$root/alloc.log"
