#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WT_REPO_ROOT="$ROOT_DIR"
export WT_BIN="${WT_BIN:-$ROOT_DIR/bin/wt}"
export WT_SHELL="$ROOT_DIR/shell/wt.zsh"
PATH="$(dirname "$WT_BIN"):$PATH"
export PATH
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export LEFTHOOK=0
export WT_COLOR=0

if [[ $# -gt 0 ]]; then
  tests=()
  for test_file in "$@"; do
    tests+=("$(cd "$(dirname "$test_file")" && pwd)/$(basename "$test_file")")
  done
else
  tests=()
  for test_file in "$ROOT_DIR"/tests/*.sh; do
    [[ "$(basename "$test_file")" == "lib.sh" ]] && continue
    tests+=("$test_file")
  done
fi

# macOS /bin/bash 3.2 ignores TMPDIR for here-doc temp files and falls back to
# the cwd when the system temp dirs are unwritable (e.g. in a sandbox).
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/wt-run.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
export XDG_STATE_HOME="$work_dir/state"

pass=0
for test_file in "${tests[@]}"; do
  name="${test_file#"$ROOT_DIR"/}"
  printf 'RUN  %s\n' "$name"
  if (cd "$work_dir" && bash "$test_file"); then
    printf 'PASS %s\n' "$name"
    pass=$((pass + 1))
  else
    status=$?
    printf 'FAIL %s\n' "$name" >&2
    exit "$status"
  fi
  printf '\n'
done

printf 'Passed %d test file(s).\n' "$pass"
