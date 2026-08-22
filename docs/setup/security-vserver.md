---
title: Vserver security — fail2ban, audit tooling, what replaced the old crontab
hosts: [11001001]
status: active
tags: [security, fail2ban, lynis, openvas, gvm, docker, caddy, netdata, vserver]
updated: 2026-08-23
---

# Vserver security posture

Companion to [security.md](security.md), which is desktop-scoped (motoko:
KeePassXC, FIDO2, PAM). This one covers the public-facing box.

Deploy kits with the actual config live in the private notes repo —
`~/notes/systems/11001001/fail2ban/` and `.../monitoring/`. This file is the
*why* and the decisions; sanitized, no host specifics beyond the public names.

## The measured threat, 2026-08-22

Worth writing down because it is not what the old setup was defending against.

| Signal | Measurement |
| ------ | ----------- |
| SSH brute force | 54 fail2ban bans in 34 days. SSH is on a non-standard port, which removes most of it. |
| Web login brute force | **One** failed Forgejo login in 21 days. Not a thing. |
| Vulnerability scanning | **9,745 requests from 248 distinct IPs in 21 days** against Forgejo alone — a distributed PHP-webshell sweep, almost entirely out of Microsoft Azure ranges. |

The conclusion that drove everything below: **the exposure here is scanning
volume and stale software, not credential attacks.**

## fail2ban

One jail (`sshd`) before this; now `sshd` + two Caddy HTTP jails + `recidive`.
Full reasoning: `~/notes/systems/11001001/fail2ban/README.md`. Two points worth
repeating in the public repo because they generalise:

**Stock HTTP jails need access logs, and there were none.** Every
`apache-*`/`nginx-*`/`botsearch` filter parses a web server access log. The
Caddyfile had no `log` directive at all. SilverBullet makes this sharper — it
logs *nothing* per request, so the reverse proxy is the only place its traffic
can be seen or blocked.

**Docker-published ports bypass fail2ban the same way they bypass ufw.**
fail2ban's stock nftables action hooks `input`; traffic to a published container
port is DNAT'd in `prerouting` and traverses `forward`, never touching `input`.
The HTTP jails would have banned into a chain that scanner traffic never passes
through — bans logged, counters rising, scanner still served. Fixed by moving
the chain to `prerouting` priority `-300`. The `sshd` jail was never affected
because sshd is a host process.

> If you add a jail for anything behind Docker, verify enforcement, not just
> that the ban was logged:
> `sudo nft list chain inet f2b-table f2b-chain` must say `hook prerouting`.

**A monitoring probe that matches a jail's filter is a bug, even when
`ignoreip` catches it.** Deploying the above immediately filled
`/var/log/fail2ban.log` with `Ignore <docker-gateway> by ip` — the Netdata
httpcheck job was probing the catch-all and getting the same 404 the jail bans
on. The ban was correctly suppressed; the *log write* was not, at ~17k lines a
day. `ignoreip` is a safety net, not a mechanism. Fixed by giving the probe its
own `remote_ip`-restricted `/healthz` route marked `log_skip`, so it never
reaches the log or the filter.

## Audit tooling: what to install and what not to

### rkhunter / chkrootkit — no

Built for file-replacing rootkits on bare metal. The attack surface here is four
containers behind one proxy; a realistic compromise is a container escape or a
stolen token, neither of which these look for. Their output is dominated by
false positives, which is exactly why the previous cron install went unread.
Reinstalling a tool in order to not read it again is a net negative.

### lynis — yes, but by hand

Genuinely useful as a hardening checklist. Its value is concentrated in the
*first* run; as a weekly cron it produces an unread 300-line report — the same
failure as above.

```bash
sudo lynis audit system
```

Work the suggestions into `setup/` modules and this note, then re-run
quarterly by hand. **Do not wire it to ntfy** — a hardening index drifting ±2
points is not an alert.

#### First run, 2026-08-22 — index 67, 267 tests, 5 warnings, 46 suggestions

Read the raw output with the OpenVAS caveat in mind: it was run *before* that
stack was removed, so **4 of the 5 warnings are Greenbone leftovers**
(world-readable `/etc/postgresql/18/*.conf`, `/etc/redis/redis-openvas.conf`)
and several suggestions (`DBS-1884/1886` Redis, `PKGS-7308` RPM) exist only
because of it. Re-run after the purge for a clean baseline; the index should
rise on its own.

**Re-run 2026-08-23, after the purge: index 68 (was 67), 263 tests, 4 warnings
(was 5), 41 suggestions (was 46).** The Redis and RPM findings are gone, and
`Intrusion software [V]` now registers — lynis detects the fail2ban work. Three
of the four remaining warnings are *still* PostgreSQL, because PostgreSQL is
still installed (see above); they should disappear once it is actually removed.
The fourth is the pending reboot.

A 1-point move for that much work is the right calibration lesson: the index is
a coarse gauge, not a scoreboard, which is exactly why it does not belong on
ntfy.

The remaining warning is real and unrelated: **reboot required since
2026-08-21** for `linux-image-7.0.0-30-generic` (running -29). Netdata's
`system_post_update_reboot_status` is already WARNING on it.

Worth doing, roughly in order of value-per-effort:

| Item | Note |
| ---- | ---- |
| Reboot for the kernel | pending 2 days; a kernel CVE fix you are not running is the single most concrete finding here |
| `NETW-3200` — blacklist `dccp`, `sctp`, `rds`, `tipc` | unused on this box, historically CVE-rich, one modprobe blacklist file |
| `AUTH-9328` — umask `027` in `/etc/login.defs` | one line |
| `SSH-7408` — `LogLevel VERBOSE` | logs key fingerprints; the difference between "someone logged in" and "*which key* logged in" after an incident |
| `SSH-7408` — `MaxSessions 2`, `ClientAliveCountMax 2` | single-user box, harmless |
| `PKGS-7346` — purge 6 removed-but-not-purged packages | cheap, and more will accumulate after the Greenbone purge |
| `PKGS-7370` — `debsums` | the useful fraction of what rkhunter claimed to do |
| `LOGG-2154` — remote logging | real: logs on a compromised host are not evidence. saito is the natural receiver. Bigger project, not a quick win |

Deliberately **not** doing:

- `SSH-7408 AllowTcpForwarding NO` — would break `ssh -L` tunnels. Tailscale
  covers most of that need, but this is a workflow change, not a free win.
- `HRDN-7230` malware scanner — same reasoning as rkhunter above.
- `FILE-6310` separate `/home` and `/var` partitions — single-disk VPS.
- `USB-1000` USB storage — it is a KVM guest.
- `ACCT-9628` auditd — high log volume for a box this size; revisit only if
  there is ever an incident to investigate.
- `DEB-0880` "copy jail.conf to jail.local" — already satisfied differently and
  better: all local fail2ban config lives in `jail.d/*.local`, which lynis does
  not detect. Ignore this one permanently.

### OpenVAS / Greenbone (GVM) — no; purge it

`apt install openvas` on Ubuntu is a metapackage for Greenbone. Note first that
the commonly-quoted `openvas-setup` / `openvas-start` / `openvas-scan` commands
are **Kali wrapper scripts and do not exist on Ubuntu** — the flow here is
`gvm-setup`, `gvm-check-setup`, `gvm-start`, then the GSA web UI.

It is the wrong tool for this box:

- It is a *network* scanner built to assess fleets of hosts you have no login
  on. You have root here — you can read the versions directly. Scanning yourself
  from yourself is its weakest mode.
- It cannot see inside containers, which is where the actual staleness lives.
- Its verdict depends on a multi-GB feed that must be kept current; a stale feed
  produces confident false negatives, which is worse than no scanner.

And the footprint is not small. Verified on install:

| Pulled in | Consequence |
| --------- | ----------- |
| **PostgreSQL 18** | full host DBMS, listening on 5432, enabled at boot |
| **redis-server 8** | second host DBMS on 6379, enabled at boot |
| `gvmd`, `gsad`, `ospd-openvas`, `notus-scanner` | four daemons, all enabled; `gvmd` restart-looping until `gvm-setup` creates its DB |

That contradicts the "no shared host DBMS" rule that put Forgejo on SQLite in
the first place, and duplicates the containerised redis Nextcloud already runs.

```bash
sudo apt purge --autoremove --dry-run gvm   # review the list first
sudo apt purge --autoremove gvm
```

**It removed 296 packages and still did not finish the job.** Three classes of
leftover survived, all verified on 2026-08-23:

1. **PostgreSQL 18 is still installed and still listening on 5432**, including
   the Greenbone extension `postgresql-18-pg-gvm`. All four packages are marked
   `auto` with nothing installed depending on them, yet a second
   `apt autoremove --purge` reports "0 to remove". They need naming explicitly.
2. **An orphaned systemd unit was still running**: `redis-server@openvas.service`,
   started 21:17, still alive after its package was purged and its unit file
   deleted — systemd keeps a removed unit loaded until told otherwise. (Do not
   confuse it with the *other* `redis-server` in `pgrep`: that one is
   `nextcloud-redis-1`, a container process visible in the host PID namespace,
   and must be left alone.)
3. **Directories dpkg refused to remove** because they were non-empty:
   `/var/log/gvm` (624K), `/var/log/notus-scanner`, `/var/lib/gvm`,
   `/var/lib/openvas`, `/etc/openvas`, `/run/redis-openvas`, plus
   `/etc/postgresql` and `/var/lib/postgresql`. Users `_gvm`, `redis` and
   `postgres` also remain.

The general lesson: `apt purge --autoremove <metapackage>` is a good first pass,
not a complete uninstall. Verify with `ss -tlnp`, `pgrep`, and a look at
`/var/lib` + `/etc` before believing a stack is gone.

If an external view is ever wanted, `nmap` + `testssl.sh` from another host
gives most of the value at none of the footprint. For container CVEs
specifically, `trivy image <ref>` is the right tool — and note it answers a
different question from `docker-image-check` (known CVEs vs. "is a newer tag
out"); the latter is the cheaper, more actionable signal week to week.

## What replaced the old (pre-rebuild) crontab

| Old cron job | Now |
| ------------ | --- |
| `dbbackup` pgsql/mysql | `nextcloud-db-dump.timer`, `forgejo-dump.timer` |
| `backup full/inc` + cleanup | restic pull from saito |
| `diskreport-mail 85/95` | Netdata `disk_space_usage`, `disk_fill_rate`, `out_of_disk_space_time` → ntfy — predictive, not just threshold |
| `logrotate-simple` per user | dropped; no user-level services. **The gap moved**: Docker's `json-file` driver had no size cap, so `/etc/docker/daemon.json` now sets `max-size`/`max-file` |
| `freshclam` / clamav | dropped — was for inbound mail scanning; there is no inbound mail |
| nextcloud cron `*/5` | `nextcloud-cron-1` container |
| `occ preview:pre-generate` | **was missing** — `previewgenerator` was enabled with nothing driving it. Now `nextcloud-preview-pregenerate.timer` |
| `nextcloud-maintenance.sh` | already ported to Docker in the rebuild but never scheduled. Now `nextcloud-maintenance.timer`, monthly |
| `journalctl --vacuum-size=500M` | unnecessary — journald's own cap applies (61.9 MB in use). Do not re-add |
| `certbot renew` | Caddy auto-ACME; renewal *failure* now caught by the `x509check` collector |
| `apt-update.sh` hourly | `apt-daily.timer` + `unattended-upgrades` |
| `rkhunter`, `lynis` weekly | see above |
| `fail2ban-summary-mail.sh` | Netdata health rules on the `go.d/fail2ban` charts → ntfy. The mail path is dead anyway: `postfix.service` is failed and the outbound relay was never finished |

## Notes on this host are a read-only replica

`~/notes` here pulls, never pushes. `notes-pull.timer` (hourly,
`notes-sync --pull-only`) instead of `notes-sync.timer`; the fine-grained
GitHub token is **Contents+Metadata read-only** and lives in a repo-scoped git
credential helper at `~/.config/git/notes-credentials` (mode 600), so it is
never offered to any other remote.

The reasoning is the credential, not the content — full version in `AGENTS.md`
under *`~/notes` sync: exactly one mode per host*. Short form: a push token here
would escalate one compromised host into every host's documentation being
readable *and writable*, and those notes get read back as instructions. Read
exposure is much cheaper: a shell on this box is already in the `docker` group,
which is root-equivalent.

Corollary: **do not author notes on this host.** Edits stay uncommitted on
purpose so they show up as drift, and `--pull-only` warns every run if local
commits exist. When something must be written here, push it by hand with an
interactively-supplied token.

## Open

- [x] Run `lynis audit system` — done 2026-08-22, index 67; see above.
- [x] Re-run lynis after the Greenbone purge — done 2026-08-23, index 68.
- [ ] Finish the Greenbone removal (PostgreSQL, the orphaned redis unit, the
      leftover directories and users) — see the OpenVAS section above, then
      re-run lynis a third time; 3 of its 4 warnings should vanish.
- [ ] Reboot for `linux-image-7.0.0-30-generic` (pending since 2026-08-21).
- [ ] Decide on `system-scripts/fail2ban-summary-mail` — superseded; remove?
- [ ] `postfix.service` has been failed since 2026-08-11: it binds the Docker
      bridge address (`inet_interfaces`) but starts before Docker creates the
      bridge. Either order it after `docker.service` with a wait, or drop the
      bridge address. Nothing currently depends on it.
- [ ] `cloud-init-main.service` is also failed — benign on a long-running
      rebuild, but it is noise in the new systemd-unit alarm; confirm and either
      fix or silence that one unit explicitly.
- [ ] No external reachability check — every probe runs on the host, so a
      firewall change that black-holes 443 would leave all monitoring green.
