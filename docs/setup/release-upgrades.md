---
title: Ubuntu release upgrades — channel per host role
hosts: [all]
status: resolved
tags: [apt, ubuntu, release-upgrade, eol, ubuntu-pro]
updated: 2026-09-28
automated_by: setup/modules/05-release-upgrades.sh
---

# Ubuntu release upgrades

**Automated:** `system-setup 05-release-upgrades`

Steady state: `/etc/update-manager/release-upgrades` carries a `Prompt=` value
chosen by the host's role, so `do-release-upgrade` only ever offers the releases
that role should be on.

| Profile   | `Prompt=` | Tracks                                  |
| --------- | --------- | --------------------------------------- |
| `desktop` | `normal`  | every release, interim ones included    |
| `server`  | `lts`     | LTS only                                |
| `wsl`     | `lts`     | LTS only (work machine — see below)     |

## Why the split

**Desktops take the interim releases.** Recent kernels and drivers matter on
current hardware, breakage has historically been rare and manageable, and when a
desktop does break there is no time pressure to fix it.

**Servers stay on LTS.** Services down while an upgrade is debugged is the whole
thing being avoided, and the old reason to chase releases on a server — getting a
current PHP/Python/runtime without backports or manual installs — is gone now
that those live in containers, independent of the host release.

`wsl` is grouped with the servers deliberately: it is a work machine, where an
interim release's churn is least welcome. Flip it in the module if that changes.

## What the interim half costs

- **No Ubuntu Pro ESM.** ESM covers LTS releases only, so an attached Pro
  account is worth nothing on an interim host. Miss the window and there are
  *zero* security updates — not reduced, none.
- **9 months, not 5 years.** An interim release EOLs roughly 9 months after
  launch, so an upgrade is due about every 9 months, and it cannot be skipped:
  upgrades are sequential (from 26.04 only 26.10 is offered; 27.04 is not
  reachable without passing through it).
- **Codename-pinned third-party repos** need editing every time (below).
- **Cross-host config skew becomes the norm**, with desktops a release ahead of
  the servers. Dotfiles written against the newer package break the LTS hosts —
  the repo has no per-host layer. Guard on the version where it matters; the
  `uutils coreutils 0.8.0` check in `lib/aliases-linux.sh` is the pattern.

## Why this is managed and not set once by hand

**A release upgrade rewrites this file.** puppet went into the 25.10 → 26.04
upgrade on `Prompt=normal` and came out on `Prompt=lts` (2026-09-28) — nobody
touched it. Left unmanaged the value drifts on precisely the event that decides
the next upgrade, which is how a desktop silently ends up parked on the LTS
channel (or, worse in the other direction, a server on the interim one).

## Knowing when a release is running out

`bin/check-release-updates` reports EOL headroom and whether a new release is
offered. It needs no root, so it is usable from a timer or a login hint:

```bash
check-release-updates          # full status
check-release-updates -q       # silent unless something needs attention
```

Exit codes are contract: `0` nothing to do, `1` status undeterminable, `2` a new
release is available or EOL is within `CRU_EOL_WARN_DAYS` (default 60) / already
passed.

EOL dates come from **distro-info-data** (`ubuntu-distro-info --days=eol`),
not from `pro security-status`. Ubuntu Pro cannot answer this: it does not cover
interim releases at all, and its JSON summary carries no `eol_date` field even on
an LTS host. The earlier implementation read that missing field, got the literal
string `"null"`, and compared dates against it — so the EOL warning could never
fire on **any** host. That is how puppet ran 81 days past EOL unnoticed.

> **Not scheduled yet.** Nothing runs this periodically — no timer, no cron, no
> module. Until that exists the check only happens when it is run by hand, which
> is the gap that caused the puppet incident rather than the script's logic.
> Tracked in [`docs/TODO.md`](../TODO.md) §7.

## The upgrade itself stays manual

`do-release-upgrade` is interactive throughout (conffile prompts, package
removals, a reboot) and must not be driven unattended or by an agent. Run it on
a console you can watch, with a way back in if the network stack changes.

Afterwards, third-party apt sources need attention — the upgrader comments all of
them out. Two kinds:

- **Codename-pinned** — must be edited to the new series, and only work if the
  publisher has actually built for it. Small Launchpad PPAs are the ones that
  lag. On puppet (2026-09-28) these were winehq, netdata, tailscale, and the
  PPAs for safeeyes, ulauncher and cryptomator.
- **Suite-pinned** (`Suites: stable` and similar) — just re-enable, nothing to
  rewrite: the browsers, vscode, mozilla, nordvpn, claude-desktop.

If `apt update` 404s on a codename-pinned repo after the upgrade, leave it
disabled rather than pointing it at an older series.

Related: [unattended-upgrades.md](unattended-upgrades.md) for the *package*
update story (a separate question — this note is only about the release itself),
and [ubuntu-base.md](ubuntu-base.md) for the apt baseline.
