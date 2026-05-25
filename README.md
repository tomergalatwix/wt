# wt

`wt` is a small Git worktree helper for keeping a reusable pool of local worktrees.

It gives you:

- `wt` - an interactive `fzf` picker for worktrees and actions
- `wt list` - a compact worktree table
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

When `wt update` is run through the shell integration, it reloads the updated
wrapper in the current shell. If you run the binary directly, reload manually
with `source ~/.zshrc`.

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
```

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
files and ask before continuing. Dirty changes are preserved; a dirty free slot
will not be reused by `wt alloc` until it is cleaned.

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
NAME  STATUS  LAST MODIFIED  BRANCH
```

The main picker also includes:

```text
Add new worktree                         create next free-N
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
`Esc` exits the picker; `Backspace` returns from the action picker to the
worktree picker.

## Notes

The main checkout is treated as the anchor checkout. It appears as `main` in
`wt list` and `wt go main`, but it is not returned to the reusable pool.

`wt alloc` refreshes from Git directly; it does not rely on local aliases.
`wt` prints each implicit step it runs: fetch/base selection, slot selection,
worktree moves, checkout/rebase, and dependency installation decisions.
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
