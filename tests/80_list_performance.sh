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

if [[ "$*" == *" status --porcelain"* || "$*" == *" ls-files --others"* ]]; then
  if [[ "${WT_TEST_STATUS_FAIL:-0}" == 1 ]]; then
    echo "status/untracked scans should not be called" >&2
    exit 42
  fi
  sleep "${WT_TEST_STATUS_DELAY:-0}"
fi

if [[ "$*" == *" diff-index --quiet HEAD --"* ]]; then
  if [[ "${WT_TEST_DIFF_FAIL:-0}" == 1 ]]; then
    echo "diff-index should not be called" >&2
    exit 42
  fi
  sleep "${WT_TEST_DIFF_DELAY:-0}"
fi

exec "${WT_TEST_REAL_GIT:?}" "$@"
FAKE_GIT
chmod +x "$fake_bin/git"

start="$(now_ms)"
(cd "$REPO" && XDG_CACHE_HOME="$root/cache" PATH="$fake_bin:$PATH" WT_TEST_REAL_GIT="$real_git" WT_TEST_STATUS_FAIL=1 WT_TEST_DIFF_DELAY=0.25 WT_STATUS_JOBS=6 WT_CACHE_TTL=60 "$WT_BIN" list > "$root/list.log")
elapsed=$(( $(now_ms) - start ))

assert_contains '6 worktrees total' "$root/list.log"
if ((elapsed > 1500)); then
  fail "wt list took ${elapsed}ms with slow diff checks; expected <= 1500ms"
fi

start="$(now_ms)"
(cd "$REPO" && XDG_CACHE_HOME="$root/cache" PATH="$fake_bin:$PATH" WT_TEST_REAL_GIT="$real_git" WT_TEST_STATUS_FAIL=1 WT_TEST_DIFF_FAIL=1 WT_CACHE_TTL=60 "$WT_BIN" list > "$root/list-cached.log")
cached_elapsed=$(( $(now_ms) - start ))

assert_contains '6 worktrees total' "$root/list-cached.log"
if ((cached_elapsed > 500)); then
  fail "cached wt list took ${cached_elapsed}ms; expected <= 500ms"
fi
