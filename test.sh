#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WT_REPO_ROOT="$ROOT_DIR"
export WT_BIN="${WT_BIN:-$ROOT_DIR/bin/wt}"
export WT_SHELL="$ROOT_DIR/shell/wt.zsh"
export PATH="$(dirname "$WT_BIN"):$PATH"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export LEFTHOOK=0
export WT_COLOR=0

if [[ $# -gt 0 ]]; then
  tests=("$@")
else
  tests=()
  for test_file in "$ROOT_DIR"/tests/*.sh; do
    [[ "$(basename "$test_file")" == "lib.sh" ]] && continue
    tests+=("$test_file")
  done
fi

pass=0
for test_file in "${tests[@]}"; do
  name="${test_file#$ROOT_DIR/}"
  printf 'RUN  %s\n' "$name"
  if bash "$test_file"; then
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
