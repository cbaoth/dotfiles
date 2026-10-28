---
title: Plex Media Server apt repo (saito)
hosts: [saito]
status: resolved
tags: [plex, apt, media]
updated: 2026-10-28
automated_by: setup/modules/36-plex.sh
---

# Plex Media Server apt repo

**Automated:** `system-setup 36-plex`. Saito-only — the vserver (11001001)
runs no Plex instance, so the module no-ops there even though both share the
`server` profile.

## What broke (2026-10-28)

`apt update` started failing with:

```
E: The repository 'https://downloads.plex.tv/repo/deb public Release' no
   longer has a Release file.
```

Plex retired the old repo/key (`downloads.plex.tv/repo/deb`,
deb822 file `/etc/apt/sources.list.d/plexmediaserver.sources`) at PMS
v1.43.0 in favor of a new one, with no transition period — the old repo just
started 404ing. The fix was Plex's own installer:

```bash
curl -LsSf https://repo.plex.tv/scripts/setupRepo.sh | sudo bash
```

(answer `y` to remove the old repo file, set up the new one, and upgrade
Plex). That script always prompts interactively (reads from `/dev/tty`), so
it cannot be the automation itself — the module reimplements its Debian path
without the prompts.

## Current state (what the module enforces)

- Signing key: `/usr/share/keyrings/plexmediaserver.v2.gpg` (Ed25519,
  fingerprint `6EFFEB478A6559D75C7C4FE706C521790B9CFFDE`, subkey
  `B406F0897A39A570804260540A05F1E6E7AFD573` — verify against
  <https://downloads.plex.tv/plex-keys/PlexSign.v2.key> if ever in doubt).
- Repo file: `/etc/apt/sources.list.d/plex.list`:
  ```
  deb [signed-by=/usr/share/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb/ public main
  ```
- Package: `plexmediaserver`, apt-managed from then on (not a container).

On each run the module checks for exactly that file/key pair; if either is
missing or stale it clears out any `/etc/apt/sources.list.d/plex*` leftovers
first (covers both the old `.list` and `.sources` naming) and rewrites them,
so a future repo migration surfaces as a normal `apt update` failure fixable
by re-running `system-setup`, not a dead end requiring a web search.

## Note

Plex's own support article for this (`setupRepo.sh`, manual steps per distro)
lives at <https://support.plex.tv> if the repo moves again and the module
needs updating — the key path and repo URL above are what Plex's installer
itself writes, which differs from what their support article's manual
DEB-based steps describe (`/etc/apt/keyrings/...` vs. the actual
`/usr/share/keyrings/...`).
