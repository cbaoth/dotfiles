---
description: 'Data care for agents — scoped searches (never crawl / or mounted storage), personal-data minimization, approval prompts that are easy to review'
# applyTo: used by GitHub Copilot; Claude Code loads this unconditionally
# (no `paths` key) as an always-on rule via .claude/rules/ symlink
applyTo: '**'
---

# Data Care

The machines this runs on mount tens of terabytes of NFS and NTFS storage
(`/srv`, `/mnt`, `/media`, `/run/media`). That storage holds personal data,
including other people's. Whatever you read goes into the conversation
context and can end up in commits, memory, notes or replies.

## Scope every search

- Never search from `/`, `~` or `/home`, and never into a mount root.
  Unscoped `find`, `du`, `rg`, `grep -r`, `locate`, `tree` take minutes there
  and surface file names nobody asked for.
- Start from the working directory or the repo. Narrow with exact names,
  `-maxdepth`, and `-xdev` (stay on one filesystem).
- A relative path in pasted output means "ask where it ran". It is not a
  reason to search the whole system for it.
- When you don't know where something lives, **stop and ask**, even in auto
  mode. The user can usually name the directory or the file.
- A `mount-guard` prompt or a mount path in a Read prompt means the user has
  to approve. Don't route around it with another tool, a variable or `cd`.

## Minimize personal data

Personal data here means mail, chat logs, voice recordings, photos, contacts,
and documents written by or about other people. Before opening any of it,
work down this list:

1. Synthetic or self-generated data (make your own test input).
2. Sanitized samples or fixtures that already exist in the project.
3. Metadata only: counts, sizes, types, durations. Not names or content.
4. Ask the user to pick the files, or to set up test data.

Read personal content directly only when the task is about that content
(e.g. the user asked for help with their mail). Then also:

- Read only what the task needs. Don't browse neighboring files.
- Never copy it into a repo, commit message, memory, note or artifact. This
  dotfiles repo is public.
- In replies, refer to people by role ("the sender"), not by name or address,
  unless the user needs the detail.
- If a directory turns out more sensitive than expected (mixed content), stop
  and say so before reading further.

## Keep approvals reviewable

The user approves commands from a one-line, unhighlighted prompt. Make the
risky part easy to see:

- One purpose per command that needs approval. Put a destructive or
  mount-touching command (`rm -r`, `mv` onto a mount, writes under `/srv`) in
  its own call, not inside a long script or a `for` loop.
- Use literal paths in that command, not variables, so the target is visible.
- For a multi-line script, write it to a file first (scratchpad, or `ccrun`
  for privileged steps) and run the file, so the user can read it with syntax
  highlighting.
