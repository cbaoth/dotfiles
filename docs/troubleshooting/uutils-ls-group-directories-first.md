---
title: ls sorting broken with --group-directories-first (uutils coreutils 0.8.0)
hosts: [motoko]
status: mitigated
tags: [ls, coreutils, uutils, ubuntu-26.04, aliases, sorting]
updated: 2026-08-16
revisit: 2026-11-01
automated_by: lib/aliases-linux.sh
---

# ls sorting broken with `--group-directories-first` (uutils 0.8.0)

**Mitigated** by a version-gated guard in [`lib/aliases-linux.sh`](../../lib/aliases-linux.sh)
that drops the flag only on the known-buggy version. Root cause is an upstream
bug already fixed; the guard self-heals once Canonical ships the fix.

## Symptom

Every `ls` alias (`ls`, `ll`, `ls.`, `ll.`, `lss`, `llt`, `lst`) sorted
incorrectly on Ubuntu 26.04. Directories were still grouped first, but entries
were **not sorted within the group** — for any sort mode:

```
# name sort — directories grouped but not alphabetical within the group
$ LC_COLLATE=C ls --color=never --group-directories-first -1 ~/
Temp
jd2
Applications
wdc-share
ComfyUI
...
```

```
# time sort (-t) — order is wrong
$ LC_COLLATE=C ls --group-directories-first -l -t ~/ | tail
... Dec 26  2025 notes.txt
... May 16 16:21 get-pip.py       <- out of order
... Jun 14 21:15 ai_meta.log
```

## Cause

Confirmed bug in **uutils coreutils 0.8.0** (the coreutils implementation
Ubuntu 26.04 ships as `/usr/bin/ls`, symlinked to `../lib/cargo/bin/coreutils/ls`).
`--group-directories-first` breaks sorting even with an explicit `--sort=name`
or `-t`. Not a quirk of the aliases, `LC_COLLATE`, or `--time-style=long-iso`
(all ruled out during testing).

```
$ /usr/bin/ls --version
ls (uutils coreutils) 0.8.0
```

## What ruled things out

- Removing `--time-style=long-iso` — bug persisted (it was a false suspect).
- Removing every flag *except* `--group-directories-first` — bug persisted.
- Removing `--group-directories-first` — sorting correct. That is the trigger.
- Testing was done with `\ls` (backslash) to bypass the `ls` alias, since the
  `ll`/`llt`/… aliases expand `ls` to the alias and silently re-add flags.

## Upstream status

- Issue: <https://github.com/uutils/coreutils/issues/12393> (closed)
- Also reported: <https://github.com/uutils/coreutils/issues/1872>
- Fix: commit `5a25c70c1` (merged pre-May 2026, i.e. after 0.8.0 was cut)
  <https://github.com/uutils/coreutils/commit/5a25c70c1>
- Ubuntu 26.04 still shipped 0.8.0 as of 2026-08-16 — waiting on a package bump.

## Fix / mitigation

Version-gated guard in `lib/aliases-linux.sh` — drop the flag **only** on
`0.8.0`, so GNU-coreutils hosts and any future patched uutils keep grouping:

```bash
_ls_group_dirs="--group-directories-first"
if command ls --version 2>/dev/null | grep -qF '(uutils coreutils) 0.8.0'; then
  _ls_group_dirs=""
fi
LS_CMD="LC_COLLATE=C ls --color=auto ${_ls_group_dirs} --time-style=long-iso"
unset _ls_group_dirs
```

Costs one `ls --version` exec per interactive shell. Self-heals: when the
package is upgraded the grep stops matching and grouping returns automatically —
**nothing to revert**. On the next upgrade, verify with:

```bash
command ls --version           # expect a version > 0.8.0
echo "$LS_CMD"                 # expect --group-directories-first present again
```

If the fix ever lands *inside* a still-`0.8.0`-labelled build (unlikely), tighten
the grep or just remove the guard.
