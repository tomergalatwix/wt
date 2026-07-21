#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

now_ms() {
  perl -MTime::HiRes=time -e 'printf "%d\n", time() * 1000'
}

root="$(new_test_root)"
create_repo_fixture "$root"
(cd "$REPO" && "$WT_BIN" grow --size 5 > /dev/null)

real_git="$(command -v git)"
fake_bin="$root/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *" status --porcelain"* ]]; then
  sleep "${WT_TEST_STATUS_DELAY:-0}"
fi

exec "${WT_TEST_REAL_GIT:?}" "$@"
FAKE_GIT
chmod +x "$fake_bin/git"

start="$(now_ms)"
(cd "$REPO" && PATH="$fake_bin:$PATH" WT_TEST_REAL_GIT="$real_git" WT_TEST_STATUS_DELAY=0.25 WT_STATUS_JOBS=6 "$WT_BIN" list > "$root/list.log")
elapsed=$(( $(now_ms) - start ))

assert_contains '6 worktrees total' "$root/list.log"
if ((elapsed > 1500)); then
  fail "wt list took ${elapsed}ms with slow status checks; expected <= 1500ms"
fi
