# AGENTS.md

Guidance for AI agents working in this repository.

## What this is

`wt` is a Git worktree pool helper: a single bash script plus a zsh wrapper.
`README.md` is the user-facing reference for commands, flags, and environment
variables; read it before changing behavior.

## Layout

| Path | Role |
|------|------|
| `bin/wt` | The whole CLI (bash). `main()` at the bottom dispatches to `cmd_<name>()` functions. |
| `shell/wt.zsh` | zsh wrapper that `cd`s the user's shell. The binary can't change the caller's cwd, so it prints `__WT_*` marker lines when `WT_SHELL_INTEGRATION=1` and the wrapper acts on them. |
| `install.sh` / `update.sh` | Copy `bin/wt` → `~/.local/bin/wt` and `shell/wt.zsh` → `~/.config/wt/wt.zsh`; add the `source` line to `~/.zshrc`. |
| `test.sh` + `tests/NN_*.sh` | CLI test suite; `tests/lib.sh` holds fixtures and asserts. |
| `lint.sh` | `shellcheck` over all bash files + `zsh -n` on the wrapper. |

The repo is the source of truth. `~/.local/bin/wt` is only an installed copy —
run `./install.sh` to try local changes through the real shell integration.

## Commands

```bash
./lint.sh                          # shellcheck + zsh syntax check
./test.sh                          # full suite
./test.sh tests/20_alloc_realloc.sh  # one file
```

Run both before finishing any change; CI (`.github/workflows/ci.yml`) runs
lint on Ubuntu and tests on macOS. Tests build throwaway repos under
`$TMPDIR`, point `XDG_CACHE_HOME` and `XDG_STATE_HOME` at a scratch dir, and set
`GIT_CONFIG_GLOBAL=/dev/null`, so they never touch real repos, caches, or user
config — and they run inside sandboxes that only allow writes to `$TMPDIR`.

Temp files: always pass `mktemp` an explicit `"${TMPDIR:-/tmp}/name.XXXXXX"`
template. Bare `mktemp` / `mktemp -t` on macOS ignore `TMPDIR`.

## Invariants

- **Main checkout is the anchor.** It shows as `main`, is never freed or
  removed, and never joins the pool.
- **Pool path** is `<repo-parent>/<repo-name>-worktrees` unless `WT_POOL_DIR`
  is set. Free slots are `free-N` (`WT_FREE_PREFIX`), detached HEAD.
- **No gaps.** After allocation, `compact_free_slots` renumbers free slots;
  `free` renames into the smallest available `free-N`.
- **Async allocation.** `alloc` moves the slot into place synchronously, then
  `finish_allocation` (fetch, checkout/rebase, deps install, compaction) runs in
  a background subshell. State and logs live under
  `${XDG_CACHE_HOME:-~/.cache}/wt/setup/`; `list` shows `setup`/`failed`, and
  `free`/`realloc`/`remove` must refuse while setup is running.
- **Dirty work is never silently lost.** Commands that reuse a worktree go
  through `ensure_clean_for_reuse`: prompt on a TTY, die when non-interactive,
  discard only with `--force`/`-f`.
- **`list` and the picker stay cheap.** They must not scan worktree contents
  (`git status`, `diff-index`, `ls-files --others`); `tests/80_list_performance.sh`
  enforces this with a fake `git`. Rows are cached (`WT_CACHE_TTL`, default
  300s) — call `clear_worktree_rows_cache` after any mutation.
- **Repo registry.** `main` calls `register_repo` for every repo-scoped
  command, appending to `${XDG_STATE_HOME:-~/.local/state}/wt/repos`; it must
  stay best-effort (never fail the command). `listall` runs outside any repo
  and prunes entries that are no longer git repos.
  `discover` (also run by `install.sh`) seeds it from `<repo>-worktrees`
  pools via Spotlight when `mdfind` exists, plus a depth-3 `find`; keep it
  working without `mdfind` (Linux).
- **Git ops inside worktrees go through `git_wt`**, which reuses the main
  checkout's Lefthook or disables hooks, so missing hook deps never block
  pool management.
- **Dependency install is best-effort**: a missing lockfile or package manager
  is a skip message, not a failure.

## Conventions

- Bash with `set -euo pipefail`; keep functions small, `local` everything,
  pass `repo` explicitly as the first argument.
- User output goes through `info` / `success` / `warning` / `phase` / `die`
  (they honor `WT_COLOR=0` and `NO_COLOR`). Long-running commands use
  `run_logged` / `run_logged_in_dir` so output is summarized unless `--verbose`.
- The `__WT_*` marker protocol between `bin/wt` and `shell/wt.zsh` is an
  interface: change both sides together and cover it in
  `tests/60_shell_integration.sh`.
- The wrapper handles markers for bare `wt` and `wt listall -i`; both pickers
  share `pick_action`. Actions picked in the all-repos picker re-run as
  `wt <cmd> <abs-path>` from the user's cwd, so `main` resolves the repo from an
  absolute-path argument first (`repo_root_from_args`) — keep that working.
- Tests: one numbered file per area, `source "$(dirname "$0")/lib.sh"`, use the
  `assert_*` helpers. Don't use a bare `! cmd` as an assertion — `set -e`
  ignores it; use `assert_not_contains` / `assert_not_match`.

## Keep in sync

A user-visible change (command, flag, output, env var) usually touches all of:

1. `bin/wt` — implementation and `cmd_help`
2. `shell/wt.zsh` — if the command needs `cd` or new markers
3. `README.md` — usage and behavior
4. `tests/` — including `tests/00_syntax_help.sh` for help text

## Commits

Conventional Commits (`feat:`, `fix:`, `perf:`, `test:`, `docs:`, `chore:`),
imperative, lowercase subject.
