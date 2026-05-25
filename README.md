# wt

`wt` is a small Git worktree helper for keeping a reusable pool of local worktrees.

It gives you:

- `wt` - an interactive `fzf` picker for worktrees and actions
- `wt list` - a compact worktree table
- `wt go <query>` - `cd` into a worktree by name, branch, or path match
- `wt create <branch>` - create or checkout a branch in a free worktree
- `wt release <query>` - detach a worktree and return it to the free pool

## Dependencies

Required:

- `git`
- `fzf`

Recommended:

- `yarn` if your repo needs dependency installation after worktree creation

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

The installer copies:

- `bin/wt` to `~/.local/bin/wt`
- `shell/wt.zsh` to `~/.config/wt/wt.zsh`

It also adds shell integration to `~/.zshrc` if missing.

## Worktree Layout

By default, `wt` expects the reusable pool to live under:

```text
<repo>/.claude/worktrees
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

Initialize a pool:

```bash
wt init --size 5
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

Create a branch, then fetch and rebase it on `origin/master` with autostash:

```bash
wt create my-feature
```

Checkout an existing branch into a free slot:

```bash
wt create existing-branch
```

Release a worktree back into the pool:

```bash
wt release my-feature
```

Force release a dirty worktree:

```bash
wt release my-feature --force
```

## Interactive Mode

Run:

```bash
wt
```

You will see a worktree picker with:

```text
NAME  STATUS  LAST MODIFIED  BRANCH
```

After selecting a worktree, choose:

```text
go          cd into this worktree
release     detach and return this worktree to the free pool
create      create or checkout a branch in this free worktree
```

`create` is only shown for `free-N` worktrees.

## Notes

The main checkout is treated as the anchor checkout. It appears as `main` in `wt list` and `wt go main`, but it is not released into the reusable pool.

`wt create` refreshes from Git directly; it does not rely on local aliases such as `rbms`. After checkout/create, it runs:

```bash
git fetch
git rebase origin/master --autostash
```

Pass `--base <ref>` to create from a different initial base; the rebase target remains `origin/master`.
