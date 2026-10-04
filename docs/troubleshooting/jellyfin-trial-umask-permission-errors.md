---
title: Jellyfin trial — permission errors, high CPU, removed again (Plex stays)
hosts: [saito]
status: abandoned
tags: [jellyfin, plex, umask, permissions, media, nfo, evaluation]
updated: 2026-10-04
---

# Jellyfin trial: permission errors and high CPU load

**Abandoned.** Jellyfin was installed on saito (2026-10-03) to evaluate it as a
Plex alternative, then removed again. Plex stays for now.

## Symptom

- Sustained high CPU load for a long time after install.
- Journal flooded with `jellyfin.service` messages, many of them write errors.

## Cause

Libraries were created up front for (nearly) all of `/media/data/Video` and
`/media/data/Audio`, each with *Save artwork/media data into media folders* and
*Save NFO files* enabled. The `jellyfin` service user is not the login user, and
the login user's default umask is `022` (group/other have no write). So Jellyfin
had no write access to any library folder, every save failed, and it kept
rescanning and retrying across the whole collection.

Cause is deduced from the config and permissions, not from a controlled test.

## Decision: why Plex stays

- Plex lifetime license already owned.
- Setup long established and reliable.
- Jellyfin UI did not convince at first look (maybe configurable, but no time
  to invest now; no clear advantage over Plex yet).
- Revisit only if Plex changes terms in a way that hurts (privacy, pricing).

## If trying Jellyfin again

1. Start with 1-2 libraries on a **small** data set, not the whole collection.
2. Decide on write-back *before* the first scan. Either disable *Save into media
   folders* / NFO saving, or give the service write access (shared group + setgid
   directories + group-writable files), keeping the `022` umask in mind.
3. Watch `journalctl -u jellyfin` and CPU during the first scan before adding more.

## Removal

Done with a staged root script (dry run first). What it removed:

- Packages `jellyfin`, `jellyfin-server`, `jellyfin-web`, `jellyfin-ffmpeg8`
  (`apt purge`)
- `/var/lib/jellyfin` (5.2 G: 4.9 G database, 248 M metadata),
  `/var/cache/jellyfin`, `/var/log/jellyfin`, `/etc/jellyfin`,
  `/usr/share/jellyfin`, `/etc/default/jellyfin`, the stock service drop-in
- apt source `/etc/apt/sources.list.d/jellyfin.sources` and key
  `/etc/apt/keyrings/jellyfin.gpg`
- User and group `jellyfin`

No `jellyfin`-owned files were found in the media libraries. Manual by design
(one-off, root, not worth a `setup/` module).
