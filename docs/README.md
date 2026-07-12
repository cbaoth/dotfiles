# `docs/` — documentation & system notes

Two kinds of thing live here, and the split is the point.

**Repo meta** stays at the root of `docs/` — how *this repository* works:

| File | What |
| ---- | ---- |
| [linking-system.md](linking-system.md) | How `dotfiles-link` deploys the repo into `$HOME` |
| [shell-style-guide.md](shell-style-guide.md) | The extended shell style guide |
| [agent-instructions.adoc](agent-instructions.adoc) | How the AI-agent instruction files are wired up |
| [TODO.md](TODO.md) | Tasks and future improvements |

**System notes** go in one of three buckets — knowledge about *the machines*,
not about the repo. Notes are markdown with YAML frontmatter, and they are the
counterpart to [`setup/`](../setup/): the note says **why**, the module says
**how**, and neither is much use alone.

## The three buckets

### `setup/` — how a machine got the way it is

One file per topic. Steady-state: describes the intended configuration, not the
journey to it. If a step is idempotent and repeatable, it should *also* exist as
a `setup/modules/*.sh` module — link to it from `automated_by:` and the note
stops being a checklist you have to hand-execute.

Manual steps are fine here too (some things genuinely should not be automated —
editing `sudoers` unattended, say). Say so explicitly rather than leaving the
reader wondering whether a module is missing.

### `troubleshooting/` — problem journals

**Append-only, and never becomes code.** One file per problem. This is where
"tried X, got error `-5`, tried Y, rolled everything back, revisit in six
months" lives — the single most valuable and least reproducible thing here.

The temptation is always to clean these up into a tidy solution. Resist it. The
dead ends *are* the content: they are what stops you spending another evening
re-discovering that the NVIDIA driver refuses to freeze.

### `reference/` — cheatsheets

Lookup material with no machine state attached: `flatpak override` syntax,
`apt-file` invocations, `gsettings` recipes, zsh notes.

## Frontmatter

Every note in a bucket carries this. It is what makes the notes greppable by an
agent and queryable in Obsidian:

```yaml
---
title: NVIDIA hibernate on motoko
hosts: [motoko]              # or [all]
status: abandoned            # resolved | workaround | abandoned | open
revisit: 2026-12             # optional — when to look at this again
tags: [nvidia, power, kernel]
updated: 2026-07-12
automated_by: setup/modules/50-power.sh   # optional; omit if manual-only
---
```

`status` matters most on troubleshooting notes: `abandoned` tells future-you
"this is a dead end, don't re-run the experiment", which is exactly the thing a
pile of undated notes cannot tell you.

## What does NOT go here

This repo is **public on GitHub**. Before writing:

- No WiFi SSIDs (they geolocate you via wigle.net), no real disk/partition
  UUIDs, no swap offsets, no MAC addresses, no credentials.
- Use placeholders (`UUID=xxxx-xxxx`, `<SSID>`) and keep the real values in the
  gitignored `_local/` directory.
- Anything private — vserver internals, health, work, personal — belongs in the
  separate private notes repo (`~/notes`), not here. See
  [`../AGENTS.md`](../AGENTS.md#notes--system-documentation).
