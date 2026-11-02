#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

bash -n "$WT_BIN"
zsh -n "$WT_SHELL"

help_out="$(mktemp "${TMPDIR:-/tmp}/wt-help.XXXXXX")"
"$WT_BIN" help > "$help_out"
assert_contains 'wt - recycled git worktree pool helper' "$help_out"
assert_contains 'wt grow [--size N] [--base REF] [--warm]' "$help_out"
assert_contains 'wt alloc [branch] [--base REF] [--deps] [--verbose]' "$help_out"
assert_contains 'wt realloc <query> [branch] [--base REF] [--deps] [--force|-f] [--yes]' "$help_out"
assert_contains 'wt listall' "$help_out"
assert_contains 'wt list [--verbose|-v]' "$help_out"
assert_contains 'Dependencies are NOT installed unless --deps.' "$help_out"
assert_contains 'wt discover [DIR...]' "$help_out"
assert_contains 'wt free [query] [--force|-f]' "$help_out"
assert_contains 'wt update' "$help_out"
