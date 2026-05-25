#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

bash -n "$WT_BIN"
zsh -n "$WT_SHELL"

help_out="$(mktemp)"
"$WT_BIN" help > "$help_out"
assert_contains 'wt - recycled git worktree pool helper' "$help_out"
assert_contains 'wt grow [--size N] [--base REF] [--warm]' "$help_out"
assert_contains 'wt alloc [branch] [--base REF]' "$help_out"
assert_contains 'wt realloc <query> [branch] [--base REF] [--force|-f] [--yes]' "$help_out"
assert_contains 'wt free <query> [--force|-f]' "$help_out"
assert_contains 'wt update' "$help_out"
