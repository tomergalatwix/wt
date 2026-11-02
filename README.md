# wt

`wt` is a small Git worktree helper for keeping a reusable pool of local worktrees.
The idea is borrowed from this blog post: https://daveschumaker.net/tag/worktrees/

It gives you:

- `wt` - an interactive `fzf` picker for worktrees and actions
- `wt list` - a compact worktree table with reusable free slots grouped at the bottom
- `wt listall` - the same table for every repo `wt` has been used in, from any directory
- `wt go <query>` - `cd` into a worktree by name, branch, or path match
- `wt grow` - add reusable `free-N` worktrees to the pool
- `wt alloc <branch>` - allocate or checkout a branch in a free worktree
- `wt realloc <query> <branch>` - free a selected worktree and allocate a branch into it
- `wt free <query>` - detach a worktree and return it to the free pool
- `wt remove <query>` - delete a worktree from the pool
- `wt update` - reinstall the latest version from GitHub

## Dependencies

Required:

- `git`
- `fzf`

Optional:

- `yarn`, `pnpm`, or `npm` if your repo has the matching lockfile and you want dependency installation after worktree creation

## Output

Mutating commands keep successful default output concise. `wt alloc` moves a
free worktree into place immediately, so shell integration can switch to it
right away. Fetching, checkout/rebase, dependency installation, and pool
compaction then continue in the background.

While allocation is running, `wt list -v` shows `setup` in the status column.
`free`, `realloc`, and `remove` are blocked until it finishes. Allocation prints
the background log path; use it for live progress or complete failure output.
Failed setup is shown as `failed` in `wt list -v` and keeps its log for diagnosis.

Use `--verbose` (or `-v`) to retain detailed Git/package-manager output in the
background setup log for troubleshooting:

```bash
wt alloc my-feature --verbose
```

Install `fzf` on macOS:

```bash
brew install fzf
```

## Install

Install from a published GitHub repo:

```bash
curl -fsSL https://raw.githubusercontent.com/tomergalatwix/wt/master/install.sh | bash
source ~/.zshrc
```

If you cloned this repo locally:

```bash
./install.sh
source ~/.zshrc
```

Update an existing install:

```bash
wt update
```

Open shells pick up the new wrapper on their next `wt` call: it re-sources
`~/.config/wt/wt.zsh` when the file changed, so there is no need to
`source ~/.zshrc` after `wt update` or `./install.sh`.

Or without relying on the installed command:

```bash
curl -fsSL https://raw.githubusercontent.com/tomergalatwix/wt/master/update.sh | bash
```

The installer copies:

- `bin/wt` to `~/.local/bin/wt`
- `shell/wt.zsh` to `~/.config/wt/wt.zsh`

It also adds shell integration to `~/.zshrc` if missing.

## Worktree Layout

By default, `wt` expects the reusable pool to live under:

```text
<repo-parent>/<repo-name>-worktrees
```

Reusable free slots are named:

```text
free-1
free-2
free-3
...
```

After allocation, `wt` closes gaps in the reusable pool. For example, if
`free-1`, `free-2`, and `free-3` exist and `free-2` is allocated, `free-3`
is renamed down to `free-2`.

You can override the pool path:

```bash
export WT_POOL_DIR=/path/to/worktrees
```

## Examples

Add one reusable free slot:

```bash
wt grow
```

Add several reusable free slots:

```bash
wt grow --size 5
```

Open the interactive picker:

```bash
wt
```

List worktrees:

```bash
wt list
wt list -v   # adds a STATUS column
```

List worktrees of every known repo, from any directory:

```bash
wt listall
```

Any `wt` command run inside a repo records it in
`${XDG_STATE_HOME:-~/.local/state}/wt/repos`. `listall` shows each repo as a
blue title followed by its worktree table, and drops repos that no longer
exist.

To register repos you haven't run `wt` in yet (the installer does this too):

```bash
wt discover          # search under $HOME
wt discover ~/code   # or specific roots
```

`discover` registers every repo that has a `<repo>-worktrees` pool next to it.
On macOS it asks Spotlight (any depth); everywhere it also scans three levels
deep, skipping hidden folders, `Library`, and `node_modules`.

Jump to a worktree:

```bash
wt go free-1
wt go my-feature
wt go main
```

Jump back like `cd -`:

```bash
wt go -
```

Alloc a branch from the fresh remote default branch:

```bash
wt alloc my-feature
```

Checkout an existing branch into a free slot:

```bash
wt alloc existing-branch
```

Reallocate an existing worktree to another branch:

```bash
wt realloc my-current-worktree next-branch
```

`realloc` asks for confirmation because it detaches the selected worktree,
moves/renames it into the free pool, then renames it to the target branch.

Free a worktree back into the pool:

```bash
wt free my-feature
```

`free` can also take the exact path of any registered Git worktree, even if
that worktree was not allocated by `wt`.

Force-free a dirty worktree:

```bash
wt free my-feature --force
wt free my-feature -f
```

Without `--force`/`-f`, dirty `free` and `realloc` operations show the changed
files and ask before discarding them. With `--force`/`-f`, dirty changes are
discarded without prompting so reusable slots stay clean.

Remove a worktree:

```bash
wt remove my-feature
```

`remove` can also take the exact path of any registered Git worktree. It asks
for confirmation unless you pass `--yes`.

## Interactive Mode

Run:

```bash
wt
```

You will see a worktree picker with:

```text
NAME  LAST MODIFIED  BRANCH
```

`wt -v` adds a `STATUS` column, like `wt list -v`.

The main picker also includes:

```text
Add new worktree                         add next free-N
```

After selecting an existing worktree, choose:

```text
go                  cd into this worktree
free                detach and return this worktree to the free pool
realloc             free this worktree and allocate another branch into it
remove              delete this worktree from the pool
alloc               allocate or checkout a branch in this free worktree
```

`remove` is not shown for `main` and asks for confirmation.
`free` and `realloc` are only shown for non-free worktrees.
`alloc` is only shown for `free-N` worktrees.
`Add new worktree` runs `wt grow`.
`Esc` exits the picker; `⌘←` returns from the action picker to the worktree
picker (and exits the worktree picker). Terminals send `⌘←` as `ctrl-a` or
`Home`, so both work; `Backspace` only edits the search.

The picker and `wt list` show in-use worktrees first by recent activity. Free
slots are always grouped at the bottom and sorted lexicographically.

### All repos

`wt listall -i` opens the same picker across every registered repo, grouped
under a blue title per repo and ordered like `wt listall`. Running `wt` with no arguments outside
a git repo opens it too. The actions are the same, minus `Add new worktree`.
Commands given an absolute worktree path (e.g. `wt free /path/to/worktree`)
act on that worktree's repo, so they work from any directory.

By default the list and picker do not scan worktree contents for changes, and
have no `STATUS` column. `--verbose`/`-v` (on `wt`, `wt list`, and
`wt listall [-i]`) adds it: `clean`, `N changed` (from `git status`), or
`setup`/`failed` for background setup. It runs `git status` for every worktree
in parallel, so on large repos it takes about a second instead of under 100ms.
Commands that can discard or reuse worktrees (`free`, `alloc`, and `realloc`)
always run full clean checks before mutating anything.

Nothing is cached: every list reads live Git state with a fixed handful of
processes per repo, so changes made outside `wt` show up immediately.

Background setup state and logs live in `${XDG_STATE_HOME:-~/.local/state}/wt/setup/`.
If a setup is interrupted (terminal closed, reboot), its worktree shows as
`failed` instead of blocking `free`/`realloc`/`remove`. Freeing or removing a
worktree deletes its setup files.

## Notes

The main checkout is treated as the anchor checkout. It appears as `main` in
`wt list` and `wt go main`, but it is not returned to the reusable pool.

`wt alloc` refreshes from Git directly; it does not rely on local aliases.
`wt alloc` prints the selected slot and the background log path. Its log records
fetch/base selection, checkout/rebase, dependency installation, and compaction.
Long-running commands are shown as phases, and their output is summarized with
an ellipsis plus the last three lines to avoid overwhelming the terminal.
Set `WT_COLOR=0` or `NO_COLOR=1` to disable `wt`'s colored status lines.

For Git hooks, `wt` first tries to reuse Lefthook from the main checkout
(`node_modules/.bin/lefthook` or the package binary). If it cannot find one, it
falls back to disabling hooks for `wt`-managed Git operations with `LEFTHOOK=0`
and `core.hooksPath=/dev/null`, so missing hook prerequisites do not block
worktree pool management.

For new branches, it fetches the remote default branch, creates the branch from that fresh ref, and jumps your shell into the new worktree.

For existing branches, it checks out the branch, then runs:

```bash
git fetch
git rebase <remote-default-branch> --autostash
```

Pass `--base <ref>` to allocate a new branch from a different initial base.

Dependency installation is best-effort. If `wt` finds `yarn.lock`,
`pnpm-lock.yaml`, or `package-lock.json`, it uses the matching package manager
when available. If the package manager is missing, `wt` prints that it skipped
dependency installation instead of failing the worktree operation.

## Tests

Run the full local CLI suite:

```bash
./test.sh
```

Run one test file:

```bash
./test.sh tests/20_alloc_realloc.sh
```
