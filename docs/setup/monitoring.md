---
title: Monitoring (Netdata) — three hosts, one pane, ntfy alerting
hosts: [motoko, saito, 11001001]
status: open
tags: [monitoring, netdata, ntfy, alerting, streaming, motoko, saito, vserver]
updated: 2026-07-25
automated_by: setup/modules/60-netdata.sh
---

# Monitoring — Netdata across motoko, saito, vserver

**Automated (install only):** `system-setup 60-netdata` — agent install is
identical on every host. Everything below the install line (role, tuning, ntfy,
streaming) is host-specific config, deployed per host and kept out of this public
repo (secrets: stream API key, ntfy topic).

The *why* — including the 2025-10-06 backup that silently failed for nine months
— lives in the "Monitoring" section of [vserver-migration.md](vserver-migration.md).
This note is the *how* and the steady state.

## The goal in one line

See a problem at a glance without hunting, and get told when something breaks —
across all three hosts, in one place, without inventing a notification channel we
already know we'll mute.

## Decisions (locked)

| Decision | Choice | Why |
| -------- | ------ | --- |
| **Tool** | **Netdata** (Grafana later) | Per-host dashboards + hundreds of sane default alarms with near-zero config. Grafana/Prometheus is the *later* "learn as admin" track. |
| **Install form** | **Native** (kickstart/static), **not a container** | Netdata's own recommendation for host monitoring: the container needs a pile of host mounts (`/proc`, `/sys`, `docker.sock`, host `/etc`) to see the host at all, and partial mounts = partial visibility. Native still monitors Docker containers (cgroups + docker socket). Also keeps all three hosts *identical* (one module, one `edit-config` workflow). saito's earlier container attempt (now removed) is exactly the path we're not taking. |
| **Topology** | **vserver = parent, saito + motoko = children** | Forced by NAT: children initiate the stream (outbound), so the parent must be publicly reachable. saito is behind NAT + NordVPN (inbound broken); vserver has a public IP and is always on. |
| **Combined dashboard** | `netdata.<domain>` on the vserver, **behind Caddy auth** | Never expose Netdata unauthenticated — it publishes a lot. The wildcard `*.11001001.org` already resolves here, so it's just another Caddy site block. |
| **Alerting** | **ntfy, one topic per host** (`host-<name>-<rand>`) | Reuses the *already-watched* channel the restic backups use ([../../notes → saito/backup](vserver-migration.md)). Native in Netdata (`SEND_NTFY`), no custom script. A topic per host — carrying that host's netdata alarms **and** its script alerts (e.g. notes-sync) — so a noisy host (the desktop asleep) can be muted without silencing the servers, and each ping's source is unambiguous. Separate from the backup topic so backup ≠ monitoring noise. |
| **Cloud** | **No Netdata Cloud** | Self-hosted, no account, metrics stay on own infra. Streaming gives the same one-pane result. |

### Why ntfy, when the plan said "delivery is deferred / everything gets muted"

That argument predates the backups. ntfy is now **live and actually watched** —
it is the restic backup alert channel (low-priority success heartbeat +
high-priority `OnFailure`). It is the one push channel that earned trust by being
low-volume and meaningful. Monitoring reuses it on **separate, per-host topics** so
a noisy alarm storm can never bury a backup-failure ping. A shell/MOTD *pull* surface is
still wanted later (see Open items) — ntfy is the push half, not the whole answer.

## Two phases — standalone first, then combine

Deliberately incremental: each host is independently useful before any host
depends on another. This is also where we hit the same traps on each box.

### Phase 1 — standalone agent on each host (parallelizable, order-free)

Netdata runs standalone out of the box. On each host, independently:

1. Install the agent — `system-setup 60-netdata` (see the module).
2. Apply the **lean child config** (`[ml] enabled = no`, local-only dashboard).
   Anomaly ML is the biggest CPU cost — off by default, especially on saito's
   i3-3240. motoko *may* re-enable it (desktop has headroom).
3. Wire **ntfy** into `health_alarm_notify.conf` (`SEND_NTFY="YES"`,
   `DEFAULT_RECIPIENT_NTFY=https://ntfy.sh/host-<name>-<rand>`) — this host's own
   topic. Combined *alerting* lands immediately (subscribe to every host's topic),
   before the combined *dashboard* exists. On servers, `edit-config` is broken
   (see below) — edit `health_alarm_notify.conf` directly.

Result after Phase 1: three local dashboards + default alarms + per-host ntfy
streams carrying every host's alerts (and its script alerts).

> **`edit-config` caveat (servers):** on saito (and expect the same on the
> vserver) `netdata/edit-config` dies with `.: cannot open
> /usr/share/im-config/initializer` — root's `/bin/sh` env sources an im-config
> file that only ships on desktops. Bypass it: `sudo cp -n
> /usr/lib/netdata/conf.d/health_alarm_notify.conf /etc/netdata/` then edit that
> file directly. Desktops (motoko) have the file, so edit-config works there.

### Phase 2 — stream children → parent (one dashboard)

1. On the **parent** (vserver): enable receiving in `stream.conf`, generate an
   API key (`uuidgen`), keep it secret. Add the `netdata.<domain>` Caddy site
   block with basic-auth.
2. On each **child** (saito, motoko): point `stream.conf` at the parent
   (`destination`, the API key), enable sending.
3. **Dedup alarms:** once streaming, set `[health] enabled = no` on the children
   and let the **parent** evaluate health for all nodes (it has the data). Both
   evaluating = duplicate ntfy pings. This is the one gotcha of the flip from
   Phase 1.
4. Children keep their **local** dashboard (bind localhost) as a fallback for
   when the parent is down.

## Per-host roles

| Host | Role | Notes |
| ---- | ---- | ----- |
| **11001001** (vserver) | **parent** + its own metrics | Public, always on. Holds combined history; serves `netdata.<domain>` behind Caddy auth. Netdata was tried here years ago — a dangling overlay2 layer still holds `run/netdata/*.sock`; a clean install is fine. |
| **saito** (LAN server) | **child**, lean | i3-3240, little headroom → ML off, capped local retention. **Near-clean slate:** an earlier quick *containerised* netdata is only **stopped**, not gone (`docker ps -a` shows it) + its image. Remove both (`docker rm` then `docker rmi`), check for orphaned `netdata_*` volumes / a leftover compose dir, then install **native** like the others — do not revive the container. |
| **motoko** (desktop) | **child** | Not always on (a desktop being off is not an incident — tune alarm severities). conky stays for local glance; Netdata is the centralised/historical/alerting layer. The MOTD/shell pull-surface matters most here (it's where you sit). |

## The secrets, and where they live

Following the backup precedent (`~/notes/systems/saito/backup/`): templates with
`CHANGE-ME` placeholders live in the private notes repo; real values live only on
the box (root-readable config) and in KeePass. Nothing secret in this repo.

- **ntfy topics — one per host** (`host-<name>-<rand>`). Generate per host
  (`echo "host-<name>-$(openssl rand -hex 16)"`), record in KeePass, and use the
  *same* per-host topic in both that host's `health_alarm_notify.conf` (netdata)
  and its `~/.config/ntfy-send/config` (scripts). Subscribe to all on the phone.
- **stream API key** — a UUID the parent accepts and the children present.
  Generated on the parent; secret; in each host's `stream.conf`.

Per-host deploy kits + runbooks: `~/notes/systems/<host>/monitoring/`.

## Not covered (yet)

- **Grafana/Prometheus/Loki** — the "later" track, spanning both servers. Netdata
  buys time; don't front-load it.
- **Pull surface** (MOTD / shell prompt segment reading the parent's API) — the
  half of alert delivery that isn't push. Open; best designed after living with
  the boxes. Do not "solve" delivery by adding a channel that gets muted.
- **App-level checks** (Nextcloud up, Caddy cert expiry beyond Netdata's own,
  fail2ban activity via the logs collector) — Phase 2+ polish.
- **Outdated-software signal** — Netdata doesn't do this; pair with
  `unattended-upgrades` + a weekly `apt list --upgradable` surfaced somewhere,
  and the existing `lynis`.
