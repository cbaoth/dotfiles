---
name: note
description: Capture what we just did as a system note (and extract a setup module if it's automatable)
agent: agent
---

Capture the work from this session as a system note.

If a topic or hint was supplied alongside the command, focus the capture on that.
Otherwise, use the whole session.

> Shared file: this is the single source for both Claude Code (`/note`, via the
> symlink at `.claude/commands/note.md`) and GitHub Copilot Chat (`/note`).
> Keep it free of tool-specific placeholders like `$ARGUMENTS` or
> `${input:...}` — both tools already see whatever the user typed after the
> command.

## 1. Decide the destination

Notes are split by **access tier** first, then by **kind**.

**Tier — which repo?**

- Public `docs/` in this repo: generic machine setup, troubleshooting, cheatsheets.
- Private `~/notes/`: anything vserver-internal, work, personal, gaming, or with
  real hostnames/credentials/identifiers in it. **When in doubt, `~/notes`.**

**Kind — which bucket?** (see `docs/README.md`)

| Bucket | When |
| ------ | ---- |
| `docs/setup/` | Steady-state config: "how this machine is set up." |
| `docs/troubleshooting/` | A problem and what happened. **Including failures and dead ends — those are the point.** |
| `docs/reference/` | Lookup syntax with no machine state attached. |

Prefer **updating an existing note** over creating a near-duplicate. Search first.

## 2. Write it

Frontmatter is mandatory:

```yaml
---
title: <short, specific>
hosts: [motoko]            # or [all]
status: resolved           # resolved | workaround | abandoned | open
revisit: 2026-12           # only if status is abandoned/open and time might fix it
tags: [...]
updated: <today, ISO-8601>
automated_by: setup/modules/NN-name.sh   # only if you also wrote/updated a module
---
```

For troubleshooting notes specifically:

- **Record what failed and why, not just the fix.** A note that only contains the
  working answer cannot stop you from re-running a known dead end six months from
  now. If something was tried and abandoned, say so, and say what would have to
  change before it is worth retrying.
- Do not tidy the journey into a clean solution. The mess is the value.

## 3. Extract a module if it earns one

If what we did is **idempotent and repeatable** (installing packages, enabling a
service, setting a `gsettings` key), also add or update a `setup/modules/NN-*.sh`
module and cross-link it — `automated_by:` in the note, `MODULE_DOC` in the
module. See `setup/README.md`.

Do **not** automate anything that edits `sudoers`, `pam.d`, or `fstab`. Note it
as deliberately manual and say why.

The re-run contract still applies: `system-setup --dry-run <module>` must report
zero changes on a machine that is already in the target state. Verify it.

## 4. Verify against the machine, not the old notes

The pre-existing Obsidian notes are **not a spec** — several turned out to be
wrong (they claimed KeePassXC had to come from apt; it is in fact the flatpak).
Before encoding anything as a rule, check the running system: `dpkg -l`,
`flatpak list`, `apt-cache policy`.

Watch for **virtual apt packages** (`exiftool`, `p7zip-full`): they install fine
but `dpkg-query` never reports them installed, which silently breaks the
idempotency contract. Always use the real package name. See
`docs/reference/package-managers.md`.

## 5. Sanitize before writing to the public repo

This repo is on GitHub. Strip WiFi SSIDs, disk/partition UUIDs, MAC addresses,
swap offsets, credentials, keys. Use placeholders; real values go in `_local/`.

Then check:

```bash
grep -rIEn '([0-9a-f]{2}:){5}[0-9a-f]{2}|[0-9A-F]{8}-[0-9A-F]{4}|[0-9A-F]{16}' docs/ setup/
```

## 6. Report back

Say which file(s) you wrote or updated, whether a module was extracted, and
anything you deliberately left out (and why). If you put it in `~/notes` rather
than here, say so and explain what made it private.
