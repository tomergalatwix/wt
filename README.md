<div align="center">

# wt

**A reusable pool of git worktrees: allocate a branch in a second, jump between them with fzf.**

[![CI](https://img.shields.io/github/actions/workflow/status/tomergalatwix/wt/ci.yml?branch=master&label=CI)](https://github.com/tomergalatwix/wt/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/tomergalatwix/wt?sort=semver)](https://github.com/tomergalatwix/wt/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-4EAA25)

[Install](#install) ·
[Quick start](#quick-start) ·
[Commands](#commands) ·
[Configuration](#configuration) ·
[FAQ](#faq--troubleshooting) ·
[Contributing](#contributing)

</div>

---

`wt` is a small bash CLI with a zsh wrapper that keeps a pool of ready-made
worktrees next to your repo. Instead of creating and deleting a worktree for
every branch, you allocate one of the `free-N` slots, work in it, and free it
back to the pool when you are done.

The idea is borrowed from
[this blog post by Dave Schumaker](https://daveschumaker.net/tag/worktrees/).

## Why

- **Fast allocation.** `wt alloc` moves a free slot into place immediately and
  your shell is already in it. Fetching, checkout/rebase and pool compaction
  finish in the background.
- **Reuse instead of re-create.** Slots are recycled, so you don't pay for a
  fresh checkout every time you switch tasks.
- **One picker for everything.** Run `wt` for an fzf picker of worktrees and
  actions: go, free, realloc, remove, alloc.
- **Every repo, from anywhere.** `wt listall` shows the worktrees of every repo
  `wt` knows about, from any directory.
- **Cheap and live.** Nothing is cached. Lists read live Git state with a fixed
  handful of processes per repo, so changes made outside `wt` show up
  immediately.
- **Safe by default.** Dirty work is never silently discarded, and the main
  checkout is never freed or removed.

## Install

**Requirements:** `git` and [`fzf`](https://github.com/junegunn/fzf)
(`brew install fzf` on macOS). Optional: `yarn`, `pnpm` or `npm`, if your repo
has the matching lockfile and you want [`--deps`](#dependencies-opt-in) to
install dependencies.

```bash
curl -fsSL https://raw.githubusercontent.com/tomergalatwix/wt/master/install.sh | bash
source ~/.zshrc
```

From a local clone:

```bash
./install.sh
source ~/.zshrc
```

The installer:

- copies `bin/wt` to `~/.local/bin/wt`;
- copies `shell/wt.zsh` to `~/.config/wt/wt.zsh`;
- adds `~/.local/bin` to `PATH` and the shell integration to `~/.zshrc` if
  they are missing;
- runs [`wt discover`](#all-repos) to register repos that already have a
  worktree pool.

The remote installer fetches the **latest release tag**, or `master` if there
are no releases yet. To install unreleased changes, set `WT_REPO_REF` to a
branch, tag or commit SHA:

```bash
curl -fsSL https://raw.githubusercontent.com/tomergalatwix/wt/master/install.sh | WT_REPO_REF=master bash
```

### Updating

```bash
wt update
```

`wt update` runs the installer for the latest release (the same
`WT_REPO_REF` rules apply), so it also re-runs `wt discover` to register repos.
To update without relying on the installed command:

```bash
curl -fsSL https://raw.githubusercontent.com/tomergalatwix/wt/master/update.sh | bash
```

Open shells pick up the new wrapper on their next `wt` call: the wrapper
re-sources `~/.config/wt/wt.zsh` when the file changed, so there is no need to
`source ~/.zshrc` after `wt update` or `./install.sh`.

`wt version` (or `wt --version`) prints the installed version, or `dev` for a
build installed from a local checkout.

#### Update check

Once a day, `wt` checks for a newer release in the background. The check never
blocks a command. On the next run in a terminal, it asks:

```text
wt vX is available (you have vY). Update now? [Y/n]
```

`Y` updates and then re-runs the command you typed; `n` snoozes the prompt for
a week (`wt update` works any time). The check is skipped for `wt go`,
`help`, `version`, `update`, non-interactive (non-TTY) runs and `dev` builds.
Set `WT_NO_UPDATE_CHECK=1` to turn it off.

## Quick start

```bash
cd ~/code/my-repo

wt grow --size 3          # create free-1, free-2, free-3 next to the repo
wt alloc my-feature       # new branch off the fresh remote default branch; cd's into it
wt list                   # see what is where
wt go main                # back to the main checkout
wt go -                   # and back again, like cd -
wt free my-feature        # done: return the slot to the pool
wt                        # or do all of the above from the fzf picker
```

`wt list` shows in-use worktrees first, most recently active on top, with the
free slots grouped at the bottom:

```console
$ wt list
NAME                LAST MODIFIED     BRANCH
main                just now          master
fix-login-redirect  12 mins ago       fix-login-redirect
search-filters      3 hours ago       search-filters
bump-deps           2 days ago        bump-deps
free-1              1 week ago        (detached HEAD)
free-2              1 week ago        (detached HEAD)
free-3              2 weeks ago       (detached HEAD)
```

## Commands

| Command | What it does |
|---------|--------------|
| `wt` | Interactive fzf picker for worktrees and actions. Outside a repo, opens the all-repos picker. |
| `wt list` | Compact worktree table, with reusable free slots grouped at the bottom. |
| `wt listall [-i]` | The same table for every repo `wt` has been used in, from any directory. `-i` opens the picker across them. |
| `wt go <query>` | `cd` into a worktree by name, branch or path match. `wt go -` jumps back. |
| `wt grow [--size N]` | Add reusable `free-N` worktrees to the pool. |
| `wt alloc <branch>` | Allocate a new branch, or check out an existing one, in a free worktree. |
| `wt realloc <query> <branch>` | Free a selected worktree and allocate a branch into the same slot. |
| `wt free [query]` | Detach a worktree (default: the current one) and return it to the free pool. |
| `wt remove <query>` | Delete a worktree from the pool. |
| `wt discover [DIR...]` | Register repos that have a `<repo>-worktrees` pool. |
| `wt update` | Reinstall the latest release from GitHub. |
| `wt version` | Print the installed version. |
| `wt help` | Print usage. |

<details>
<summary><b>Full usage and flags</b></summary>

```text
wt [--verbose|-v]                       (interactive picker)
wt grow [--size N] [--base REF] [--warm] [--verbose]
wt alloc [branch] [--base REF] [--deps] [--verbose]
wt realloc <query> [branch] [--base REF] [--deps] [--force|-f] [--yes] [--verbose]
wt go <query> [--print-path]
wt list [--verbose|-v]
wt listall [-i|--interactive] [--verbose|-v]
wt discover [DIR...]
wt free [query] [--force|-f] [--verbose]
wt remove <query> [--force|-f] [--yes]
wt update
wt version
```

| Flag | Applies to | Effect |
|------|------------|--------|
| `--size N` | `grow` | Number of free slots to add. |
| `--base REF` | `grow`, `alloc`, `realloc` | Create a new branch from `REF` instead of the remote default branch. |
| `--deps` | `alloc`, `realloc` | Also install dependencies from the lockfile. |
| `--warm` | `grow` | Install dependencies in the new slots. |
| `--force`, `-f` | `free`, `realloc` | Discard dirty changes without prompting. |
| `--force`, `-f` | `remove` | Remove a worktree that has uncommitted changes (refused otherwise). |
| `--yes` | `realloc`, `remove` | Skip the confirmation prompt. |
| `--verbose`, `-v` | `wt`, `list`, `listall` | Add a `STATUS` column. |
| `--verbose`, `-v` | `alloc`, `realloc`, `grow`, `free` | Keep detailed Git and package-manager output in the background setup log. |
| `--print-path` | `go` | Print the path instead of changing directory. |

</details>

## Usage

### Allocating branches

```bash
wt alloc my-feature                 # new branch from the fresh remote default branch
wt alloc existing-branch            # check out an existing branch into a free slot
wt alloc my-feature --base release  # new branch from another base
wt alloc my-feature --deps          # also install dependencies
```

`wt alloc` refreshes from Git directly; it does not rely on local aliases.

- **New branch:** it fetches the remote default branch, creates the branch from
  that fresh ref, and jumps your shell into the new worktree. Pass
  `--base <ref>` to start from a different base.
- **Existing branch:** it checks out the branch, then runs:

  ```bash
  git fetch
  git rebase <remote-default-branch> --autostash
  ```

Allocation is asynchronous. The free slot is moved into place right away, so
shell integration can switch to it immediately; fetching, checkout/rebase,
dependency installation (with `--deps`) and pool compaction continue in the
background. `wt alloc` prints the selected slot and the background log path;
use the log for live progress or full failure output.

While setup is running, `wt list -v` shows `setup` in the `STATUS` column, and
`free`, `realloc` and `remove` are blocked until it finishes. A failed setup
shows as `failed` and keeps its log for diagnosis. If a setup is interrupted
(terminal closed, reboot), its worktree shows as `failed` instead of blocking
`free`, `realloc` or `remove`.

For troubleshooting, keep the full Git and package-manager output in the log:

```bash
wt alloc my-feature --verbose
```

### Dependencies (opt-in)

Dependency installation is opt-in: pass `--deps` to `alloc` or `realloc`, or
`--warm` to `grow`. Without it, `alloc` only does the Git work: a fresh branch
off the remote default branch, or a checkout and rebase of an existing one.

It is also best-effort. If `wt` finds `yarn.lock`, `pnpm-lock.yaml` or
`package-lock.json`, it uses the matching package manager when it is
available. If the package manager is missing, `wt` prints that it skipped
dependency installation instead of failing the worktree operation.

### Freeing, reallocating and removing

```bash
wt free my-feature                 # detach and return to the pool
wt free                            # free the worktree you are in
wt free my-feature --force         # or -f: discard dirty changes without asking
wt realloc my-feature next-branch  # reuse this slot for another branch
wt remove my-feature               # delete the worktree (asks first)
```

- `free` detaches HEAD and renames the worktree to the smallest available
  `free-N`. It also accepts the exact path of any registered Git worktree,
  even one `wt` did not allocate.
- `realloc` asks for confirmation, because it detaches the selected worktree,
  moves it into the free pool, then renames it to the target branch.
- `remove` also accepts the exact path of any registered Git worktree. It asks
  for confirmation unless you pass `--yes`. The main checkout is protected.
- Without `--force`/`-f`, a dirty `free` or `realloc` shows the changed files
  and asks before discarding them. With `--force`/`-f`, dirty changes are
  discarded without prompting, so reusable slots stay clean.

### The pool

By default the pool lives next to the repo:

```text
<repo-parent>/<repo-name>-worktrees/
├── free-1
├── free-2
└── free-3
```

The pool has no gaps. After an allocation, `wt` renumbers the free slots: if
`free-1`, `free-2` and `free-3` exist and `free-2` is allocated, `free-3` is
renamed to `free-2`.

The main checkout is the anchor. It appears as `main` in `wt list` and
`wt go main`, but it is never returned to the pool.

### Interactive picker

Run `wt` to open a worktree picker:

```text
NAME  LAST MODIFIED  BRANCH
```

`wt -v` adds a `STATUS` column, like `wt list -v`. The picker also has an
`Add new worktree` entry, which runs `wt grow`. After you select a worktree,
choose an action:

```text
go                  cd into this worktree
free                detach and return this worktree to the free pool
realloc             free this worktree and allocate another branch into it
remove              delete this worktree from the pool
alloc               allocate or checkout a branch in this free worktree
```

- `remove` is not shown for `main`, and asks for confirmation.
- `free` and `realloc` are shown only for worktrees that are not free.
- `alloc` is shown only for `free-N` worktrees.

| Key | Action |
|-----|--------|
| `Esc` | Exit the picker. |
| `⌘←` | Go back from the action picker to the worktree picker (exits the worktree picker). Terminals send `⌘←` as `ctrl-a` or `Home`, so both work. |
| `Backspace` | Edits the search only. |

The picker, like `wt list`, shows in-use worktrees first by recent activity.
Free slots are always grouped at the bottom and sorted lexicographically.

### All repos

```bash
wt listall      # one table per repo, under a blue title
wt listall -i   # the picker across every repo
```

Any `wt` command run inside a repo records it in
`${XDG_STATE_HOME:-~/.local/state}/wt/repos`. `listall` shows each registered
repo as a blue title followed by its worktree table, and drops repos that no
longer exist.

`wt listall -i` opens the same picker across every registered repo, grouped
under a title per repo and ordered like `wt listall`. Running `wt` with no
arguments outside a git repo opens it too. The actions are the same, minus
`Add new worktree`. Commands given an absolute worktree path (for example
`wt free /path/to/worktree`) act on that worktree's repo, so they work from any
directory.

To register repos you haven't run `wt` in yet (the installer does this too):

```bash
wt discover          # search under $HOME
wt discover ~/code   # or under specific roots
```

`discover` registers every repo that has a `<repo>-worktrees` pool next to it.
On macOS it asks Spotlight (any depth); everywhere, it also scans three levels
deep, skipping hidden folders, `Library` and `node_modules`.

### The STATUS column

By default, lists and the picker don't scan worktree contents for changes, and
have no `STATUS` column. `--verbose`/`-v` (on `wt`, `wt list` and
`wt listall [-i]`) adds one:

| Status | Meaning |
|--------|---------|
| `clean` | No changes. |
| `N changed` | `N` changed files, from `git status`. |
| `setup` | Background setup is running. |
| `failed` | Background setup failed or was interrupted. |

It runs `git status` for every worktree in parallel, so on large repos it
takes about a second instead of under 100 ms. Commands that can discard or
reuse worktrees (`free`, `alloc` and `realloc`) always run full clean checks
before changing anything.

### Output

Successful mutating commands keep their output short. Long-running steps are
shown as phases, and their output is summarized as an ellipsis plus the last
three lines.

## Configuration

<details>
<summary><b>Environment variables</b></summary>

| Variable | Default | Effect |
|----------|---------|--------|
| `WT_POOL_DIR` | `<repo-parent>/<repo-name>-worktrees` | Where the pool lives. |
| `WT_FREE_PREFIX` | `free-` | Name prefix of free slots. |
| `WT_FZF_COMMAND` | `fzf` | The fzf binary used by the picker. |
| `WT_COLOR=0` / `NO_COLOR=1` | unset | Disable colored status lines. |
| `WT_NO_UPDATE_CHECK=1` | unset | Disable the daily [update check](#update-check). |
| `WT_REPO_REF` | latest release | Branch, tag or commit SHA that `install.sh` and `wt update` install. Falls back to `master` if there are no releases. |
| `WT_INSTALL_DIR` | `~/.local/bin` | Where `install.sh` puts the binary. |
| `WT_CONFIG_DIR` | `~/.config/wt` | Where `install.sh` puts the zsh wrapper. |
| `WT_SHELL_RC` | `~/.zshrc` | The rc file `install.sh` adds the shell integration to. |

```bash
export WT_POOL_DIR=/path/to/worktrees
```

</details>

<details>
<summary><b>Data locations</b></summary>

| Path | Contents |
|------|----------|
| `~/.local/bin/wt` | The installed CLI. |
| `~/.config/wt/wt.zsh` | The zsh wrapper, sourced from `~/.zshrc`. |
| `${XDG_STATE_HOME:-~/.local/state}/wt/repos` | Registry of known repos, used by `listall`. |
| `${XDG_STATE_HOME:-~/.local/state}/wt/setup/` | Background setup state and logs. Freeing or removing a worktree deletes its setup files. |
| `${XDG_STATE_HOME:-~/.local/state}/wt/update-check` | When the update check last ran, and any snooze. |

</details>

<details>
<summary><b>Git hooks and Lefthook</b></summary>

For Git operations inside worktrees, `wt` first tries to reuse Lefthook from the
main checkout (`node_modules/.bin/lefthook` or the package binary). If it can't
find one, it disables hooks for `wt`-managed Git operations with `LEFTHOOK=0`
and `core.hooksPath=/dev/null`, so missing hook prerequisites never block pool
management.

</details>

## FAQ / troubleshooting

<details>
<summary><b>Do I need to reload my shell after <code>wt update</code>?</b></summary>

No. The wrapper re-sources `~/.config/wt/wt.zsh` on the next `wt` call when the
file changed. You only need `source ~/.zshrc` once, after the first install.

</details>

<details>
<summary><b>How does <code>wt go</code> change my directory?</b></summary>

A program can't change its parent shell's directory, so `wt go` prints a path.
The zsh wrapper (`~/.config/wt/wt.zsh`) reads it and does the `cd`. Without the
wrapper, use `cd "$(wt go my-feature)"`.

</details>

<details>
<summary><b>A worktree says <code>setup</code> and I can't free it.</b></summary>

Allocation is still finishing in the background. `free`, `realloc` and
`remove` wait for it. Follow the log path `wt alloc` printed to see progress.
An interrupted setup shows as `failed` and no longer blocks the slot.

</details>

<details>
<summary><b>Allocation failed. Where is the output?</b></summary>

In the background log under `${XDG_STATE_HOME:-~/.local/state}/wt/setup/`; its
path is printed by `wt alloc`. Re-run with `--verbose` to keep the full Git and
package-manager output there.

</details>

<details>
<summary><b>Why weren't my dependencies installed?</b></summary>

Dependency installation is opt-in. Pass `--deps` to `alloc` or `realloc`, or
`--warm` to `grow`. If the matching package manager isn't installed, `wt` skips
the step and says so.

</details>

<details>
<summary><b><code>wt listall</code> doesn't show one of my repos.</b></summary>

Run any `wt` command inside it once, or run `wt discover` (optionally with the
root directory to search). `discover` only finds repos with a
`<repo>-worktrees` pool next to them.

</details>

<details>
<summary><b>How do I try unreleased changes?</b></summary>

Install from `master` (or any branch, tag or SHA):

```bash
curl -fsSL https://raw.githubusercontent.com/tomergalatwix/wt/master/install.sh | WT_REPO_REF=master bash
```

</details>

## Contributing

Issues and pull requests are welcome. Read [AGENTS.md](AGENTS.md) first: it
covers the layout, invariants and conventions, and it applies to humans too.
Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

Questions or ideas? Reach me at [tomergal2000@gmail.com](mailto:tomergal2000@gmail.com).

```bash
./lint.sh                             # shellcheck + zsh syntax check
./test.sh                             # the full local CLI suite
./test.sh tests/20_alloc_realloc.sh   # one test file
```

CI runs lint on Ubuntu and tests on macOS. The tests build throwaway repos under
`$TMPDIR` and never touch your real repos, state or Git config. To try local
changes through the real shell integration, run `./install.sh`.

### Releases

Releases are cut manually from GitHub Actions: **Actions → Release → Run
workflow**, then choose `patch`, `minor` or `major`. The first release is
`v1.0.0`. The workflow runs CI, tags `vX.Y.Z` and publishes a GitHub Release
with the changes since the previous tag.
