---
title: Git workflow — multi-machine dotfiles, branches, worktrees, recovery
hosts: [all]
status: resolved
tags: [git, workflow, rebase, worktree, stash, reflog]
updated: 2026-07-20
---

Practical git workflow for this repo (and any personal repo synced across
machines). The recurring pain here is **working directly on `master` from
several machines**, which produces `ahead N, behind M` divergence. This note is
how to make that painless and how to never lose work.

## Defaults now set (in `.gitconfig`)

These are tracked in [`dotfiles/.gitconfig`](../../dotfiles/.gitconfig), so every
machine gets them:

| Setting | Effect |
| --- | --- |
| `pull.rebase = true` | `git pull` replays your local commits on top of the fetched ones (linear history) instead of making a merge bubble |
| `rebase.autoStash = true` | a dirty working tree is stashed before a rebase/pull and re-applied after — no "cannot rebase: unstaged changes" |
| `merge.conflictStyle = zdiff3` | conflict markers also show the original (merge-base) text, which is what makes conflicts resolvable |

With these, the normal cross-machine cycle is just:

```sh
git pull      # fetch + rebase local commits on top, auto-stashing if dirty
# ... work, commit ...
git push
```

## The divergence cycle (what happened, why it's fine)

`ahead 7, behind 11` means: 11 commits on `origin` you don't have, 7 local ones
not pushed. It looks alarming but resolves cleanly as long as the two sides
didn't change the *same lines*:

```sh
git fetch origin
git log --oneline master..origin/master   # what they have that you don't
git log --oneline origin/master..master   # what you have that they don't
git rebase origin/master                  # or just: git pull
```

**Predict conflicts before doing it** — files changed on *both* sides since the
split are the only ones that can conflict:

```sh
mb=$(git merge-base master origin/master)
comm -12 <(git diff --name-only "$mb" master     | LC_ALL=C sort) \
         <(git diff --name-only "$mb" origin/master | LC_ALL=C sort)
```

**Dry-run without touching your working tree** — rebase a throwaway worktree:

```sh
git worktree add --detach /tmp/rb master
( cd /tmp/rb && git rebase origin/master; git rebase --abort 2>/dev/null )
git worktree remove --force /tmp/rb
```

## Feature branches for anything incomplete

Don't leave half-finished edits sitting dirty on `master` (they get in the way
of every pull/rebase). Park them on a branch instead:

```sh
git switch -c wip/global-aliases   # create + switch
# ... commit WIP freely ...
git switch master                  # go back, tree is clean

# when it's ready:
git switch master
git merge --ff-only wip/global-aliases   # or rebase it first for a clean line
git branch -d wip/global-aliases
```

This replaces most stash usage: the work is a real commit (survives reboots,
shows in `git log`, recoverable) instead of a fragile stash entry.

## Worktrees — two checkouts, zero switching

A worktree is a second working directory backed by the same repo. Use it to
work on two topics at once without stashing or branch-switching:

```sh
git worktree add ../dotfiles-wip wip/global-aliases   # new dir on that branch
git worktree add --detach ../dotfiles-test master     # throwaway, e.g. dry-runs
git worktree list
git worktree remove ../dotfiles-wip
```

Great for "I'm mid-edit here but need to check/fix something else" — the thing
that otherwise tempts a risky stash.

## Stash — the safe way

Stash is fine for genuinely short-lived interruptions; the data-loss traps are
avoidable:

```sh
git stash push -m "msg" -- path/to/file   # stash SPECIFIC files, with a name
git stash list                            # see them (they have messages)
git stash show -p stash@{0}               # preview the diff before touching it
git stash apply stash@{0}                 # apply but KEEP the stash (safe)
git stash pop                             # apply and DROP — only once you're sure
git stash branch wip/foo stash@{0}        # turn a stash into a branch
```

Rules that prevent lost work:
- Prefer **`apply`** over `pop`. `pop` drops the stash; if applying hits a
  conflict it can look like the stash vanished. `apply` leaves it intact until
  you explicitly `git stash drop`.
- Always **`push -m`** with a message — an unnamed `WIP on master:` stash from
  three weeks ago is unidentifiable.
- A dropped stash is still recoverable via `reflog` (below) for a while.

## Conflict resolution ("a file changed on both sides")

When a merge/rebase stops on a conflict, git writes markers into the file. With
`zdiff3` they look like:

```
<<<<<<< ours
your version
||||||| base
the original both sides started from
=======
their version
>>>>>>> theirs
```

Edit the file to the intended final result (delete the markers), then:

```sh
git add <file>
git rebase --continue      # or: git merge --continue
```

Helpers:
- `git checkout --ours <file>` / `--theirs <file>` — take one side wholesale.
- `git mergetool` — open a 3-way tool (VS Code's merge editor works well).
- `git rebase --abort` / `git merge --abort` — bail out, restore the pre-op state.
- `git diff --name-only --diff-filter=U` — list the still-conflicted files.

## Safety nets — nothing is truly lost

- **`git reflog`** — a log of everywhere `HEAD` has been. Recovers commits after
  a bad reset/rebase, or a dropped stash, for ~90 days:
  ```sh
  git reflog                 # find the good state, e.g. HEAD@{5} or a hash
  git reset --hard HEAD@{5}  # go back to it
  ```
- **Backup tag before anything risky** — an instant, named undo point:
  ```sh
  git tag bak/pre-rebase-$(date +%Y%m%d) master
  # ... risky operation ...
  git reset --hard bak/pre-rebase-YYYYMMDD   # if it went wrong
  git tag -d bak/pre-rebase-YYYYMMDD         # remove once confirmed good
  ```
- **`git status` and `git log --oneline --graph --all`** before pushing —
  cheap sanity checks.

## dotfiles-specific

After a pull/rebase that brought in **new** tracked files under `bin/`, `lib/`,
or `dotfiles/`, run `dotfiles-link` so the symlinks are created. A pull that only
changed existing (already-linked) files needs nothing — the symlink already
points at the repo.
