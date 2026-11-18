---
title: Gerrit review workflow
hosts: [all]
status: resolved
tags: [git, gerrit, review]
updated: 2026-11-17
---

# Gerrit review workflow

Use the target branch, remote, and review process specified by the project.

## Reviews and branch comparisons

Pushing a commit to `refs/for/<target>` creates or updates a review; it does not
itself advance the target branch. Until the change is submitted, a comparison
against the target can therefore show a reviewed commit as local-only, even
though Gerrit has it.

After fetching, `gibm` summarizes local branches and their configured
upstreams. `gild` shows the current branch's divergence from its upstream:
`<` is local-only, `>` is upstream-only. A new review branch might have no
upstream; a similarly named remote branch does not automatically make it one.
In that case, explicitly compare against the intended integration branch:

```sh
git log --graph --oneline --decorate --left-right 'HEAD...origin/main'
```

Here `origin/main` is an example, not a guessed default. Neither this comparison
nor an upstream relationship tells Gerrit where to submit a review. Different
commit hashes after rebasing or submission can also make divergence misleading
about whether the change landed; check the Gerrit review's status.

## Move a review commit off the integration branch

This example assumes the current local integration branch is `main`, its
intended remote counterpart is `origin/main`, and `review/my-change` is an
unused local branch name. Replace them with the project's actual names.

**Before starting:** preserve any uncommitted work, resolve or abort any
in-progress Git operation, and confirm the review is already in Gerrit. The
procedure moves a local branch pointer; it does not submit or update a review.

1. Check the worktree and current branch:

   ```sh
   git status
   git worktree list
   ```

   Continue only if the worktree is clean, you are on `main`, and no Git
   operation is in progress.

2. Fetch and inspect the commits unique to each branch:

   ```sh
   git fetch origin &&
     git log --graph --oneline --decorate --left-right 'main...origin/main'
   ```

   `<` commits are local-only; `>` commits are remote-only. Continue only if
   both commands succeed, you understand the divergence, and you intend to
   preserve **all** local-only commits on the new review branch.
   `git log --oneline origin/main..main` lists those commits separately.

3. Create and switch to the review branch at the current commit:

   ```sh
   git switch -c review/my-change main
   ```

4. **Only after the switch succeeds**, move local `main` to the fetched
   `origin/main`:

   ```sh
   git branch --force main origin/main
   ```

   This changes the local branch pointer, not the current working files or a
   remote branch. Git refuses if `main` is checked out in another worktree.

5. Verify the review branch is current and the two `main` pointers match:

   ```sh
   git status
   git rev-parse main origin/main
   ```

   The hashes must match. The existing review commits remain reachable from
   `review/my-change`, unchanged.

## Update an existing review

Follow the project's review instructions. For a single review commit, amend it
while preserving its `Change-Id` footer, then push the revised commit to the
same Gerrit target when ready. An example, if the project uses this workflow:

```sh
git commit --amend
git show -s --format=%B HEAD
git push origin HEAD:refs/for/main
```

Check the commit message and target before pushing. If the review contains
multiple commits or the project uses a different submission workflow, follow
its instructions instead. `git pull` may rebase local commits with this repo's
Git defaults; inspect first and rebase deliberately.
