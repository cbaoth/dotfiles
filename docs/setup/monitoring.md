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
| **Topology** | **vserver = parent, saito + motoko = children** | Children initiate the stream (outbound). vserver is the always-on aggregator. |
| **Stream transport** | **Tailscale** (WireGuard mesh) | Children stream to the parent over the tailnet — private, encrypted, no public netdata port, no reverse-proxy nuance. Solves NAT traversal (saito) and key management for free. saito has NordVPN disabled (it captured the tailnet route); motoko streams only while its NordVPN is off (a dashboard gap, never an alerting gap — see below). |
| **Combined dashboard** | Over the **tailnet** (`http://<parent-fqdn>:19999`), no public exposure | 19999 is gated by ufw to `tailscale0`; view it with Tailscale on your phone/laptop. Strictly more private than a public vhost. A `netdata.<domain>` + Caddy basic-auth vhost stays **optional**, only for non-tailnet devices. **Use the parent's MagicDNS FQDN, not a numeric short name** — see the gotcha below. |
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
3. Wire **ntfy** with **`ntfy-setup`** (bin/) — one command per host: it
   generates/reuses this host's topic (`host-<name>-<rand>`), writes
   `~/.config/ntfy-send/config` (owned by you even under sudo), and sets
   `DEFAULT_RECIPIENT_NTFY` in every consumer config (netdata's
   `health_alarm_notify.conf`; extend `CONSUMER_CONFIGS` for more). It replaces
   the first match, drops redundant duplicates, and seeds from the stock config —
   sidestepping the broken `edit-config` (below). The per-host topic is the single
   source of truth in `ntfy-send/config`. **Still a one-time toggle:** set
   `SEND_NTFY="YES"` + `SEND_EMAIL="NO"` in `health_alarm_notify.conf` (netdata
   defaults `SEND_NTFY=YES`, so usually only `SEND_EMAIL=NO` is needed).
   Combined *alerting* lands immediately (subscribe to every host's topic), before
   the combined *dashboard* exists.

Result after Phase 1: three local dashboards + default alarms + per-host ntfy
streams carrying every host's alerts (and its script alerts).

> **`edit-config` caveat (servers):** on saito (and expect the same on the
> vserver) `netdata/edit-config` dies with `.: cannot open
> /usr/share/im-config/initializer` — root's `/bin/sh` env sources an im-config
> file that only ships on desktops. Bypass it: `sudo cp -n
> /usr/lib/netdata/conf.d/health_alarm_notify.conf /etc/netdata/` then edit that
> file directly. Desktops (motoko) have the file, so edit-config works there.

### Phase 2 — stream children → parent over Tailscale (one dashboard)

Full runbook + config templates: `~/notes/systems/11001001/monitoring/`.

1. On the **parent** (vserver): install netdata + `ntfy-setup` (it is also a
   child, with its own alarms); apply `netdata.conf.parent` (19999 tailnet-only,
   not localhost); `ufw allow in on tailscale0 to any port 19999`; generate an
   API key (`uuidgen`); enable receiving in `stream.conf`.
2. On each **child** (saito, motoko): `stream.conf` → `destination =
   <parent-fqdn>:19999` (the tailnet MagicDNS FQDN — **not** a bare numeric name;
   see gotcha), the same API key, enable sending. No TLS (tailnet is already
   encrypted).

> **Gotcha — numeric hostnames parse as integer IPs.** The parent's short name
> `11001001` is read as a 32-bit integer IP (`= 0.167.220.169`) by browsers *and*
> netdata's resolver, so `destination = 11001001:19999` / `http://11001001:19999`
> silently hit the wrong address, and even the raw tailnet IP failed for streaming.
> Always use the full MagicDNS FQDN (`11001001.bone-shade.ts.net`). Same reason the
> box's hostname is `11001001.org`.
3. **Dedup — but keep child health LOCAL.** The parent is told *not* to evaluate
   streamed children (`stream.conf: health enabled by default = no`); children keep
   `[health] enabled = yes`. Children self-alarm to their own ntfy topics, which
   are **tunnel-independent** (ntfy is outbound HTTPS, not over the tailnet). So no
   duplicates *and* alerts fire even if the tailnet is down — the opposite of the
   textbook "parent evaluates, children silent" flip, chosen because the transport
   can drop (NordVPN on motoko, blocked networks) and alerting must not depend on it.
4. Children keep their **local** dashboard (bind localhost) as a fallback.

Losing the parent or the tailnet loses the **combined view**, never the **alerting**.

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
