#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

command -v shellcheck >/dev/null 2>&1 || {
  echo 'shellcheck not found (brew install shellcheck)' >&2
  exit 1
}

shellcheck bin/wt install.sh update.sh test.sh lint.sh tests/*.sh
# zsh is not supported by shellcheck; syntax-check the wrapper instead.
zsh -n shell/wt.zsh

printf 'Lint passed.\n'
