---
title: Vserver rebuild & migration plan (Contabo VPS → Ubuntu 26.04 LTS)
hosts: [vserver]
status: open
tags: [migration, vserver, contabo, ubuntu, docker, monitoring, planning]
updated: 2026-07-18
---

# Vserver rebuild & migration plan

A from-scratch reinstall of the Contabo VPS (`11001001.org`), moving off the
current hand-grown Debian install to a clean, mostly-reproducible Ubuntu box with
**monitoring that actually gets looked at** and only the services still in use.

> **Sensitive current-state inventory** (IPs, DB names, ports, credential
> pointers, and the "run these on the old box" checklist) is in the gitignored
> `_local/vserver-inventory.md` — this repo is public, so real values stay there.
> This file is the sanitized plan.

## Execution log / status (for a session picking this up cold)

**As of 2026-07-18 ~17:15 — Phase 1 complete. Fresh Ubuntu 26.04 box is
hardened and ready; next is Phase 2 (Docker/Caddy/Netdata/msmtp) + Phase 3
restore, driven by Claude Code on the box.**

Phase 1 done (2026-07-18):
- Reinstalled Ubuntu 26.04 LTS via Contabo panel; escaped the VNC console fast
  by pulling the saito key onto root with `curl https://github.com/cbaoth.keys`
  (no key-typing into VNC).
- `bootstrap-new-server.sh` ran but **died at step 3** — the Ubuntu cloud image
  ships a `ubuntu` user at **uid/gid 1000**, colliding with the script's
  `--uid 1000`. Recovered by **renaming** the stock user instead of creating a
  new one: `usermod -l cbaoth ubuntu` → `passwd` → `groupmod -n cbaoth ubuntu`
  → `usermod -d /home/cbaoth -m cbaoth` → `chfn -f "…"` → `chsh -s /bin/zsh`.
  Also removed the now-dangling `/etc/sudoers.d/90-cloud-init-users` (it granted
  the old `ubuntu` NOPASSWD) — cbaoth uses password sudo via the `sudo` group,
  as intended.
- Re-ran the (idempotent) bootstrap: sshd hardened to **key-only on 8090, root
  off**; `ufw` deny-in (8090/80/443); fail2ban; unattended-upgrades; dotfiles
  deployed; Node LTS + Claude Code installed. Contabo **panel firewall** active
  as the out-of-host layer (temp port-22 rule to be deleted once 8090 is proven).
- Rebooted onto the pending kernel; `claude` runs as cbaoth in `~/dotfiles`.

Two script bugs found & fixed (so the next rebuild is clean):
- **`system-setup` mirror switch didn't force an apt refresh** — `00-apt-base`
  set `ST_APT_UPDATED=0`, but `st::apt_update` had no force path and skipped the
  update because the fresh image's cache was <1 h old. Availability was then
  judged against the *old* mirror's index, so `btop`/`ripgrep`/`containerd`/
  `runc`/`docker-buildx` looked "not available" and `docker.io` couldn't resolve
  deps. A manual `sudo apt update` fixed the run; the durable fix adds
  `st::apt_update --force` on any sources change (commit alongside this doc).
- **`bootstrap-new-server.sh` step 7 aborted `system-setup`** — it's invoked
  inside a `sudo -u cbaoth bash <<EOSU` heredoc, so the interactive "Continue?"
  prompt read from the heredoc and aborted. Fix: pass `--yes` there. (Script
  lives in gitignored `_local/`; fix applied on saito only.)
- **nvm installed to the wrong dir and polluted `.zshrc`** — the installer
  defaults to `~/.nvm` and appends source lines to `.zshrc`, but `.common_env`
  already sources nvm from `~/.config/nvm` (for both bash and zsh), and `.zshrc`
  is a symlink into the repo — so the append dirtied the working tree *and* left
  nvm unsourced (wrong dir). Fix: install with `NVM_DIR=~/.config/nvm
  PROFILE=/dev/null`. On the live box, undo with: `cd ~/dotfiles && git restore
  dotfiles/.zshrc`, then `mkdir -p ~/.config && mv ~/.nvm ~/.config/nvm` (the
  whole tree relocates cleanly — Node + the global `claude-code` come with it),
  then restart the shell/claude session so `.common_env` picks it up.

**As of 2026-07-18 ~14:35 — data is staged, box is frozen, ready to reinstall.**

Done:
- **Bulk + delta pull complete**, staged on **saito** at
  `/media/backup/vserver-migration/2026-07-18/`:
  `nextcloud/` 164 G (data minus regenerable previews/updater),
  `home/` 44 G (all users), `db-mysql/` 39 G (fresh `owncloud` dump taken 13:20
  *after* Apache stop → consistent), `db-postgres/` 140 K, `etc/` 80 M
  (pi-hole excluded), `opt/` 141 M.
- Everything else (`/var/www` sites, full `/etc` with correct ownership) is in the
  **nightly tar mirror** `/media/backup/11001001.org/` (last good full 2026-07-06
  + weekly incrementals). NB the 2025-10-06 full silently failed — see Monitoring.
- **Cutover freeze:** Apache stopped 12:37; Nextcloud `maintenance:mode --on`.
- **Verified:** the actual KeePass `.kdbx` opens from the staged copy; `owncloud`
  dump is a valid MariaDB dump.
- **Safety:** Tor is a local-only SOCKS client (no `ORPort`, 0 circuits) — not a
  relay; Squid is ACL-locked to localhost. **Finding:** no host packet filter was
  ever active (`iptables INPUT` empty) — services self-protected, but the new box
  must have ufw + the Contabo panel firewall from the start.
- **Contabo snapshot** `debian-migration` taken 2026-07-18 14:02 (auto-del 17.08).
- Plan pushed to GitHub; scripts + `vserver-inventory.md` copied to saito
  (`~/dotfiles/_local/` and `_local/11001001.org/`).

Staging caveats:
- Staged files are **cbaoth-owned** (pulled as cbaoth) — fine: Nextcloud data gets
  `chown -R www-data:www-data` on restore; `/etc` with real ownership comes from
  the tar mirror, not the staged `etc/`.
- The `/var/www` sites were **not** freshly staged (a `www_sites` vs `www-sites`
  typo); they're static + in the tar mirror. Re-run `--phase www-sites` only if a
  fresh copy is wanted.

**Next (new session):** reinstall Ubuntu 26.04 LTS via Contabo panel → run
`bootstrap-new-server.sh` (on saito: `~/dotfiles/_local/vserver-migration/`; scp
or paste to the fresh box; **read it first — it touches sshd**) → then Phase 2
(Docker, Caddy, Netdata, msmtp) and Phase 3 restore. Restore is saito→new-vserver
(reverse rsync + chown + DB import); no restore script exists yet.

## Why now

- Storage was bumped 800 GB → **1.2 TB SSD**; the extra space is not in any
  filesystem yet — a reinstall lays out the full disk cleanly.
- The box has accreted a decade of half-used services, dead configs, and
  unmonitored cruft (mail server retired, FTP backup dead, game-stat DBs, an
  ancient iptables script from the OpenBSD era). A rebuild is cheaper than an audit.
- Debian was a one-off experiment last reinstall; going back to Ubuntu removes the
  per-distro friction with the other Ubuntu hosts (motoko, saito).

## Decisions (locked)

| Decision | Choice | Rationale |
| -------- | ------ | --------- |
| **OS image** | **Ubuntu 26.04 LTS** | Latest LTS, on Contabo's image list; 5-yr support, conservative, no upgrade treadmill on a mostly-unattended server. |
| **Monitoring** | **Netdata now, Grafana later** | At-a-glance dashboards + sane default alarms with near-zero config today; grow into Grafana/Prometheus as an admin once the basics are covered. |
| **Web/TLS** | **Caddy** | Automatic HTTPS (retires certbot), tiny config, clean reverse proxy in front of the containerised apps. |
| **Service deployment** | **Docker Compose per service** | Isolation, trivial volume backup + migration, keeps the host clean and reasoned-about. Docker already used on motoko/saito. |
| **Distro family** | Ubuntu (not switching) | Least friction with the other hosts; no compelling reason to jump to Fedora/Alma/Arch for this role. |

## Service disposition

Decide the keep/replace/drop list **before** the reinstall so we don't rebuild
cruft. (Real DB/service names → `_local/vserver-inventory.md`.)

| Current (confirmed running) | Verdict | New form |
| --------------------------- | ------- | -------- |
| **Nextcloud** 31.0.9 (Apache + MariaDB `owncloud`, 239 G data) | **KEEP** | Nextcloud in Docker Compose behind Caddy. Restore DB dump + `data/`. DB engine → see DBMS section. |
| **MariaDB** (many old schemas) | **SLIM** | Only Nextcloud (+ any wiki DB actually migrated); drop game-stat/blog/analytics DBs. Runs as the Nextcloud stack's own container, not a shared host service. |
| **PostgreSQL** (3 host clusters + gitea's container) | **DROP host clusters** | Not a shared host DBMS on the new box. Check the 3 clusters' contents first (likely dead Piped/Wallabag/experiments); each new app brings its own pg container. |
| **Apache** (11 vhosts) | **REPLACE → Caddy** | Reverse proxy + static file serving; auto-HTTPS. |
| **certbot** (18 certs, many dead) | **DROP** | Caddy does ACME. Dead certs (piped*, wallabag, mail, local) are cert cruft — gone. |
| **wiki.11001001.org** (yavin) + **rpwiki** (MediaWiki) | **MIGRATE → SilverBullet** | Extract relevant content; retire. `wiki` has a known skipped-schema SQL error on one special page. |
| **`maenner`** wiki (small, friends' events) | **MIGRATE or COLD-STORE** | Not a blocker/decision-driver. Migrate to SilverBullet (scoped friend access) *or* keep as read-only export / a small MediaWiki container later. Data is small (352 M). |
| **gitea** (1 small repo, own pg container) | **DROP** | Repo already exists on the local dev machine (small React prototype). No Forgejo needed now; add later only if self-hosted git is wanted again. |
| **FTP (port 21)** + **`backup2ftp`** | **DROP** | Obsolete/insecure; dead Hetzner-era backup. |
| **OpenVPN** (running udp 1194) | **DROP for now** | Not actually used. If home-network access is wanted later: SSH port-forwarding / cloud / **WireGuard** — and consider hosting it on **saito** (24/7) or an old **RPi**, not this VPS. |
| **Pi-hole** (running, **DNS world-exposed :53**) | **DROP from VPS** | Filter-DNS is a valid *future* project but must NOT be a public open resolver. Better home: saito or an RPi on the LAN. **Bonus find:** `/etc/pihole` is **7.5 G** — its FTL query database. That is why `/etc` is 7.6 G and every *full* backup drags an 8 G `etc.tar` of DNS logs for a service that was never really used. Dropping it makes `/etc` ~100 M. |
| **Squid** (**open proxy :3128**) | **DROP** | Open forward proxy = abuse risk; no current use. |
| **Tor** daemon | **DROP** unless there's a known purpose | Running unmonitored; confirm it isn't a relay/exit before wiping. |
| **TeamSpeak 3** | **DROP** | Unused for years; Discord etc. cover it. |
| **Full mail stack** (postfix/dovecot/rspamd/spamassassin/clamav/roundcube/sieve) | **DROP inbound** | Replace with **outbound-only** relay (msmtp) for notifications. Removes a huge, exposed, unmonitored attack surface. |
| **`blacklist.py`** / **`goaccess.sh`** | **DROP** | Superseded by fail2ban / monitoring. |
| **`backup` / `dbbackup`** | **KEEP** | Maintained in `system-scripts/`; adapt targets + add saito/S3 offsite. |
| **blog.kredinger.de** (friend, last post 2015), **herrzinter/chrisi** (brother, already 403/disabled), **med-plan-assistant** (own test deploy of the gitea repo) | **BACKUP, don't restore now** | All dormant. Archive with the rest; restore only on request (probably never). `med-plan-assistant` = the small React prototype deployed via `scp` (browser-storage only, no sensitive data) → see "Prototype deploys" below. |

## Database choice

**The premise changes under Docker-Compose-per-service: there is no shared host
DBMS.** Each stack ships and owns its own database container (its own volume,
backed up the same way regardless of engine). So "pick one DBMS to maintain"
mostly dissolves — you maintain *compose files*, not a central database server.
Nextcloud's "we recommend MySQL/MariaDB" is advice for a shared install; it does
not force the whole host's choice.

**Recommendation:**

- **PostgreSQL as the house standard** for anything new/future. It's the modern
  default and most self-hosted tools you'd add are postgres-first (Forgejo,
  Immich, Paperless-ngx, Miniflux, Wallabag, …). Better concurrency, JSON, and
  stricter SQL than MySQL.
- **Keep Nextcloud on MariaDB** by restoring the existing dump — do **not**
  convert. MySQL→Postgres conversion for Nextcloud is exactly the fiddly,
  error-prone step in the guides you linked; it buys little (Nextcloud runs great
  on MariaDB) and risks a lot on 239 G / years of app state. Nextcloud's MariaDB
  lives inside the Nextcloud compose stack — it is not a second thing to babysit.
- Net: **Postgres everywhere new, MariaDB only inside Nextcloud.** Under
  per-service containers the "mixing" cost is near zero (uniform volume/dump
  backups, encapsulated in compose). If you want absolute purity later, convert
  Nextcloud once — with a verified backup — but it's optional, not upfront work.
- **Do you even need Nextcloud's DB tuning?** The speed bump you remember was
  most likely **APCu + Redis caching + cron mode**, not the DB engine. Re-enable
  those (memcache.local = APCu, memcache.distributed/locking = Redis, background
  jobs = cron) and the DB choice is not the performance lever.

→ *Open:* keep Nextcloud MariaDB (recommended) vs. convert to Postgres for a
single-engine host.

## SSH port

**Keep the existing non-standard port** (`<SSH_PORT>` — real value in
`_local/vserver-inventory.md`; deliberately not published here, since this repo
names the domain and publishing the port would undo the point of it).

Rationale stands: it dodges the constant bot noise aimed at 22, fail2ban handles
the rest, and — practically — some work/other networks block outbound SSH to
hoster IP ranges (Contabo) on 22 but allow the high port. No good reason to
change; carry it over. (gitea's separate SSH port goes away with gitea.)

**`AllowAgentForwarding no`** (as on the old box). OpenSSH defaults it to `yes`,
so the bootstrap sets it back off explicitly. On an internet-facing host a
forwarded agent is a standing risk: whoever controls the box while you're
connected can use your keys as you. Instead:

- **Git on the box:** a **dedicated ed25519 key generated on the vserver**, added
  to GitHub (deploy key for read-only; account key if push is needed). No agent
  forwarding, no PATs typed into the shell — set this up early so repo pulls work.
- **Reaching another host through it:** `ProxyJump` (`ssh -J`), not `ssh -A` —
  auth stays end-to-end; the jump host never sees your keys.

(saito is a different calculus: LAN-only and trusted, so `-A` there is fine.)

## Users & home directories

Only **`cbaoth`** is recreated. Everyone else is **backed up but not restored**
(recreate on explicit request only — not expected). All are old mail/file-share
users from the retired services; last activity in parentheses:

| Home | Who / what | Action |
| ---- | ---------- | ------ |
| `cbaoth` | you | **recreate** (also: prune old `Maildir` backups, `#bak/`, 2005–2013 mail archives — `/home` is 44 G and the cruft is yours) |
| `alpha` | old basic-auth file share (2019) | backup only |
| `hans` | friend's father, mail (2022) | backup only |
| `herrzinter` | brother, mail (2022) | backup only |
| `rohal` | friend, mail — **still received mail until 2025-08**; also nests `kredinger/` game-server junk (in `nobackup/`, already excluded) | backup only |
| `thyrathea` | friend's wife, mail (2023) | backup only |
| `linotp` | abandoned LinOTP (OTP server) experiment, empty | drop (nothing to back up) |
| `docker` | system user, empty home | drop |

**Nextcloud accounts** — resolved via `occ user:lastseen`:

| Account | Last login | Action |
| ------- | ---------- | ------ |
| `cbaoth` | today | keep — **already admin**, so no separate admin account is needed at all |
| `galadriel` (mother) | **yesterday — active user** | keep + restore; see cutover note in Backup strategy |
| `herrzinter` (brother) | 2025-08-24 (11 mo) | asked him (Signal, pending). **Back it up regardless** — 11 G is noise against 165 G. His answer only decides *restore*, which can wait until after the wipe; don't let it block. |
| `admin` | 2023-10-31 | **drop** — stale privileged account, no 2FA, unwatched, and redundant since `cbaoth` already holds admin |
| `rohal` | 2019-08-02 (7 yr) | archive, don't restore |
| `wilf` (father) | 2017-08-29 (9 yr) | delete |

Dropping the unused `admin` account is the security win here: a privileged login
nobody has touched in 2.7 years, without 2FA, is exactly the account an attacker
wants. The new instance should have no generic `admin` — `cbaoth` holds it.

The retired mail service means these `Maildir/` trees are the *only* copy of
years of people's mail — make sure they land in the archive intact before wipe.

## Prototype deploys (replaces the gitea use-case)

gitea is dropped, but keep the *capability* it served: push a small build to a
web-reachable path from VS Code / a script (like `med-plan-assistant`'s
`deploy.sh`, which just `scp`s `dist/` to `/var/www/med-plan-assistant`).

Lightweight replacement, no gitea needed:
- A `deploy` target dir (e.g. `/srv/apps/<name>`) served by **Caddy**
  (`file_server`, optional basic-auth or an allowlist), deployed via `scp`/`rsync`
  over SSH (`<SSH_PORT>`). Phone/friend access via a subdomain behind Caddy's TLS.
- If self-hosted git is ever wanted again → **Forgejo** container (its own pg).
  Not now.

## Target architecture

```
Internet
   │  (Contabo panel firewall: allow 22/80/443 + chosen extras)
   ▼
[ nftables/ufw + fail2ban ]  ── host firewall, deny-in default
   ▼
[ Caddy ]  ── automatic HTTPS, single reverse proxy
   ├── nextcloud.<domain>   → Nextcloud container stack (app + MariaDB + Redis)
   ├── git.<domain>         → Forgejo container
   ├── notes.<domain>       → SilverBullet container
   ├── (maennerwiki)        → MediaWiki container [if kept]
   └── static dummy sites   → Caddy file_server
[ Netdata ]  ── metrics + alarms (host + containers), notifications → mail/ntfy
[ msmtp ]    ── outbound-only relay for cron/monitoring notifications
[ backup ]   ── system tar + DB dumps → local /backup → offsite (saito + optional S3)
```

Everything user-facing sits behind Caddy on 80/443. Application ports stay bound
to `127.0.0.1`/the Docker network and are never exposed directly.

## Filesystem / storage

**Resolved:** the 1.2 TB **is** provisioned at the hypervisor — `sda` reports
1.2 T. It's the *partition* that still ends at ~800 G (`sda2` = 799 G, 60 % full),
leaving **~400 GB unpartitioned free space** on the current install. Nothing to
chase with Contabo; a reinstall will lay out the full disk.

(Side effect: that ~400 GB of free space is available *right now* — usable as a
local staging area during migration if the offsite pull needs a buffer. Growing
the live partition with `growpart`+`resize2fs` would also work, but is pointless
on a box we're about to wipe.)

### Install method — free standard image, not the paid ISO

Contabo only offers custom partitioning via **manual ISO install (~€27.50 one-off)**
or a remote rescue-system debootstrap (free but fiddly/risky on a headless VPS).
**Not worth it here:** the only real thing that buys is LVM or LUKS, and —

- **LUKS** we already ruled out (see below).
- **LVM** would be nice-to-have, but its main payoff (a `/backup` LV that can't
  fill root) is covered more cheaply by **offsite-first backups + Netdata disk
  alarms**, and Contabo already provides hypervisor snapshots.

→ **Use the free standard Ubuntu 26.04 image** (single ext4 root, like the current
box). Skip the ISO unless a future need (e.g. FDE) actually justifies the €27.50.

### Layout on the single root

- **Filesystem: ext4**, single root spanning the full 1.2 TB (matches how the box
  already is; zero friction).
- Guard the "backup fills root" risk without LVM by: (a) keeping **local `/backup`
  small — it's staging only**, real retention lives offsite on saito; (b) Netdata
  **disk alarms at 80 % / 90 %**; (c) watching `/var/lib/docker` (all app state +
  Nextcloud data volume) the same way.
- **Swap:** small swap file (2–4 G) or zram; 30 G RAM means swap is a safety net,
  not a workhorse. Low `swappiness`.
- If the reinstall happens to expose the extra ~400 GB as *separate* space rather
  than one grown root, mount it at `/backup` — but don't count on it.

### LUKS: no (with one nuance)

**Full-disk LUKS on this VPS is not worth it:**

- *Auto-unlock* (key in initramfs/on disk) is security theater — Contabo controls
  the disk **and** the RAM; a key readable at boot is readable by the operator.
  It protects against a threat (physical disk theft) that doesn't apply to a VPS.
- *Manual unlock on boot* (type a passphrase via VNC, or SSH into
  dropbear-initramfs) genuinely protects the data at rest, but kills unattended
  operation: every reboot — kernel updates, `unattended-upgrades`, Contabo
  maintenance, a crash at 3 a.m. — hangs until you manually unlock. For a
  headless 24/7 box that should self-recover, that availability cost is too high.

**Instead, encrypt at the data level where it matters** — consistent with the
motoko plan ([security.md](security.md)): put the genuinely sensitive subset
(health, personal, `med-plan-assistant`?) in a **Cryptomator** / gocryptfs vault
inside Nextcloud, or use Nextcloud's client-side E2EE. That way the crown jewels
are encrypted with a key the hypervisor never sees, without holding the whole
server's boot hostage.

→ **To verify on first boot:** `lsblk -f`, `df -hT`, and whether the extra
~400 GB is present / needs `growpart` + `resize2fs` (or LVM extend).

## Migration strategy — data safety first

**Nothing is wiped until restore is proven.** Order:

1. **Freeze & capture** the old box (final DB dumps, config export, sizes).
2. **Stage all data on saito** (`/backup/vserver-migration/<date>/`), plus a
   Contabo **snapshot** as a last-resort full rollback.
3. Only then **reinstall** to Ubuntu 26.04.
4. Restore into the new architecture, service by service, verifying each.
5. Cut DNS over once each service is confirmed on the new box.

See `_local/vserver-inventory.md` for the exact copy list and the commands to run
on the old box.

---

## Phase 0 — before touching the box (on old box + saito)

- [x] Ran the info block — findings in `_local/vserver-inventory.md`.
- [x] Storage: 1.2 TB confirmed provisioned (only the partition is short).
- [x] Owner/keep decisions resolved — see the ledger at the bottom.
- [ ] **Tell `galadriel` (mother) about the downtime window** — she's an active
      daily user, not a dormant account. Confirm when done.
- [ ] **Ask the brother** whether his Nextcloud account (11 G, last login
      2025-08-24) still matters, before dropping it.
- [ ] Safety check: confirm **Tor** was never a relay/exit before wiping.
- [ ] Take a **Contabo snapshot** (safety net; note the 30-day expiry).
- [ ] Note current DNS records (A/AAAA/MX/reverse) for all three domains.
- [ ] **Run the staging pull** — `_local/vserver-migration/stage-from-vserver.sh`,
      executed **on saito** (saito is behind NAT; only it can initiate). Takes
      final DB dumps remotely, then pulls `/etc`, `/home`, `/var/www`, `/opt`.
- [ ] Verify the staged copy (the script writes a manifest + sizes) — **nothing
      gets wiped until a restore is proven**.
- [ ] Preserve the sensitive inventory off-box: `_local/` is gitignored and lives
      on the box being wiped. It sits inside `/home`, so the pull covers it —
      but confirm it landed.
- [ ] Consider mirroring the crown jewels (Nextcloud data, DB dumps) to **S3/cloud**.

## Phase 1 — fresh install → bootstrap to Claude Code

The goal of this phase: a **minimal, secured** box that we can then drive the
detailed setup from (with Claude Code). Stop when Claude Code is installed.

1. **Reinstall** via Contabo panel → Ubuntu 26.04 LTS. Set hostname, note the
   root password. (Have VNC ready in case SSH misbehaves.)
2. **Base hardening — automated:** run
   `_local/vserver-migration/bootstrap-new-server.sh` (copy it to the fresh box;
   it has no repo dependency, by design). It does, in lockout-safe order:
   full-upgrade → create `cbaoth` + install your SSH pubkey → **verify key login
   works** → only *then* harden sshd (custom port, no root, no passwords) → ufw
   (deny-in; SSH + 80/443) → fail2ban → unattended-upgrades → base tools.
   - Run it in `tmux`, **keep the root session open**, and follow its prompts —
     it deliberately stops and makes you prove key login before it can lock you out.
   - Also enable the **Contabo panel firewall** as an out-of-host second layer.
   - See [unattended-upgrades.md](unattended-upgrades.md).
3. **Repo bootstrap** (same flow as [ubuntu-base.md](ubuntu-base.md)):
   ```bash
   sudo apt-get update && sudo apt-get install -y git
   git clone https://github.com/cbaoth/dotfiles.git ~/dotfiles
   ~/dotfiles/bin/system-setup --profile server   # zsh, git, base tools
   ~/dotfiles/tools/link.sh                        # deploy dotfiles
   chsh -s /bin/zsh
   ```
4. **Install Node + Claude Code** (Node LTS via the repo's method / nvm), then
   authenticate. **→ hand off to Claude Code for Phase 2+.**

At this point the box is: patched, firewalled, key-only SSH, brute-force
protected, auto-patching, with the dotfiles + tooling deployed. Safe to continue.

## Phase 2 — core platform (with Claude Code)

- [ ] Install Docker (`system-setup 30-docker`) — see [docker.md](docker.md).
- [ ] Deploy **Caddy** (container or apt) as the single reverse proxy; wire up
      automatic HTTPS for the three domains. Retire certbot for good.
      - ⚠️ **The zone has a wildcard `*.11001001.org` A/AAAA pointing here**, so
        *every* subdomain reaches the box (verified: `randomtest.11001001.org`
        resolves to it). Therefore: configure Caddy with **explicit site blocks
        only, and do NOT enable `on_demand_tls`** — with a wildcard record, on-demand
        issuance lets any stranger trigger cert requests for arbitrary names and
        burn the Let's Encrypt rate limit (50 certs/week per registered domain).
      - Add a catch-all block that closes/404s unmatched hosts.
      - Bonus: the wildcard means the dead subdomains (`piped*`, `wallabag`,
        `mail`, `local`) still resolve — they'll simply hit the catch-all.
- [ ] Deploy **Netdata** (host + cgroup/container collectors). Configure alarms
      (disk %, load, RAM, service-down, cert-expiry) and a notification channel.
- [ ] Set up **msmtp** outbound relay so cron + Netdata + fail2ban can mail alerts
      to the outlook.com inbox (see Mail).

## Phase 3 — services & data restore

- [ ] **Nextcloud** stack (app + MariaDB + Redis) in Compose; restore the DB dump
      and `data/` from saito; run `occ maintenance:repair` + integrity checks;
      point Caddy at it; verify sync + logins.
- [ ] **Forgejo** container; import the git repo(s) from the old gitea.
- [ ] **SilverBullet** container; migrate the relevant MediaWiki content into it.
- [ ] `maennerwiki` — migrate to SilverBullet (scoped friend access) **or** stand
      up a single MediaWiki container, per the Phase 0 decision.
- [ ] Static dummy sites for `cbaoth.de` / `xurim.de` via Caddy `file_server`.
- [ ] Re-point DNS (A/AAAA) per service; re-check reverse DNS for mail sender.

## Phase 4 — backup, monitoring polish, hardening

- [ ] Adapt `backup` / `dbbackup` to the new layout; **add offsite**: push to
      saito (rsync/SFTP over the existing setup) and optionally **S3/cloud** or
      the **Contabo auto-backup add-on (<€2/mo)** for the crown jewels.
- [ ] Verify a **restore drill** (dump → fresh container) actually works.
- [ ] Netdata alarm review; add app-level checks (Nextcloud, Forgejo up).
- [ ] Security pass: `lynis audit system` (keep, it was already run weekly),
      review fail2ban jails, confirm nothing but 80/443/SSH is exposed.
- [ ] Document the final steady state as proper `docs/setup/` notes + extract any
      idempotent bits into `setup/` modules (per the repo's note/module rule).

## Monitoring — the actual goal

### Exhibit A: the backup that silently didn't happen

On **2025-10-06** the full backup failed completely — all 11 tars errored with
`Cannot open: No such file or directory` because the target dir was never
created. **Nobody noticed for nine months.** `cronic` dutifully mailed the
failure; local mail hasn't been read since the mail server was retired.

Two latent bugs in `backup` made it worse: `mkdir -p "${targetdir}"` is
**unchecked**, so the script carried on producing nothing; and `full()` writes
`$FULLDATE` **regardless of tar success**, so the following incrementals pointed
at a full backup that did not exist.

This is the whole argument in one incident: the problem was never a lack of
backups, it was that **nothing tells you when they break**. Fix the telling, and
prefer tools that fail loudly and self-verify (restic `check`) over a script that
exits 0 while writing nothing.

### The tool

The point is *seeing problems at a glance without hunting*. Start with **Netdata**:

- Single binary/container, auto-discovers system + Docker container metrics.
- Ships with hundreds of sane default **alarms** (disk filling, RAM, load, a
  service dying, TLS cert nearing expiry) — the "tell me before it's on fire" layer.
- One dashboard per host; notifications to email/ntfy/Discord.
- **Covers the stated must-haves:** disk usage, service/network health, notable
  fail2ban/log activity (via the logs collector), cert expiry.

**Outdated-software / vulnerability signal** (Netdata doesn't do this): pair with
- `unattended-upgrades` (auto security patches) +
- `apt list --upgradable` surfaced as a weekly notification, and/or
- periodic `lynis` (already in use) and optionally `debsecan`/`trivy` for the
  container images.

### Multi-host: one pane of glass, self-hosted

Netdata is already installed on saito (and unused). To get **all hosts in one
place** without Netdata Cloud, use **parent/child streaming**: children stream
metrics to a parent, and the parent's dashboard shows every node.

**Topology is forced by the same NAT/VPN fact as the backups:** children initiate
the connection, so the parent must be reachable *from* the children. saito is
behind NAT with NordVPN breaking inbound → saito cannot be the parent.

→ **vserver = parent** (the only publicly-reachable, always-on box).
→ **saito + motoko = children**, streaming outbound (unaffected by NordVPN).

- Dashboard at `netdata.<domain>` **behind Caddy with auth** — ⚠️ never expose
  Netdata unauthenticated; it publishes a *lot* about the system. The wildcard
  DNS already points here, so this is just a Caddy site block.
- Each child keeps its own local dashboard too, so if the parent dies you can
  still inspect a node directly.
- Prefer this over **Netdata Cloud**: no account, no third party, metrics stay on
  own infrastructure. (Cloud is the easier path if streaming proves annoying.)
- motoko already has conky for local glanceable info; Netdata is the
  *centralised + historical + alerting* layer, not a replacement.

### Delivery: an unsolved problem — deliberately deferred

**Push notifications will not work here, and that is a settled fact, not a
preference to be engineered around.** Notifications are off everywhere by design
(only the meds app and incoming calls get through); messengers get checked every
other day; email has hundreds of unread and is opened mainly for MFA codes;
Discord maybe every other month. Any alert routed to those channels is an alert
that gets muted — which is *worse* than none, because it manufactures a feeling
of coverage while the next 2025-10-06 goes unseen.

So the useful direction is **pull surfaces placed where attention already goes**,
not push into channels that are pre-muted:

- Shell startup is the highest-frequency surface (terminal, constantly) — a MOTD
  / login summary / prompt segment is *unavoidable* rather than merely available.
- Browser start page · sway keybinding · shell alias (`xdg-open`) · pinned tab —
  redundant placement is good design here, not clutter.
- Possibly a **digest at a receptive time**, rather than interrupt-on-event.

→ **Open, and explicitly NOT a blocker.** Netdata collects and alarms regardless;
delivery is a separate decision, best made after living with the box. Do not let
it hold up the build. Do not "solve" it by picking a channel that will be muted.

**Later → Grafana:** once the basics are steady, add Prometheus + node_exporter +
Loki (logs) and build Grafana dashboards — this is the "learn Grafana as admin"
track, and it should span **both vserver and saito** so there's one pane of glass.
Don't front-load it; Netdata buys time.

## Mail (notifications only)

No inbound mail server. Just enough outbound to get alerts out:

- **Decided: start simple.** **msmtp** as a lightweight sendmail replacement,
  relaying through an **existing SMTP account**. No domain reputation to manage,
  no inbound surface — alerts just work.

**The existing DNS makes this decision, and it's stricter than assumed.** The zone
already publishes (verified by `dig`):

- `_dmarc` → **`v=DMARC1; p=reject;`** — the harshest possible policy.
- SPF → `v=spf1 include:_smtp.udag.de ~all` — authorizes **only the registrar's**
  SMTP servers.
- MX → `mx00/mx01.udag.de` — inbound mail goes to united-domains (then forwards
  to outlook). **The vserver never needs port 25.**

Consequence: a naive `msmtp` sending *directly* as `something@11001001.org` would
fail SPF, carry no DKIM, and be **rejected outright** (`p=reject`) by outlook and
everyone else. So: do **not** send as the domain from the box without a plan.

**The good news — "proper domain mail" later is far easier than it looked.** No
mail server, no reputation fight, no DNS surgery: just point msmtp at
**united-domains' submission server** with the domain's own credentials. That
host is *already* in SPF, so SPF passes, DMARC aligns, and mail from
`system@11001001.org` is accepted. Worth doing whenever convenient — it's a
config line, not a project.

→ *Open:* does the udag plan include SMTP submission credentials? If yes, that's
the endgame for mail here and the "later" item basically evaporates.
- Wire cron (`cronic`), Netdata, fail2ban summaries into it → land in the
  outlook.com inbox.
- **saito needs the same** notification path (likely domain-less / relay-account
  based) so both hosts share one alert format/destination. → see saito follow-up.

## Backup strategy (rethought — don't just copy the old scheme)

> **Already in place:** saito pulls `/backup` from the vserver nightly (02:00,
> `/opt/bin/backup-11001001` → `/media/backup/11001001.org/`), authenticated by a
> tightly-scoped sudoers rule. It is **verified working** — the mirrored files
> match the vserver byte-for-byte. So the pull model isn't a proposal; it's the
> status quo, and it works. What follows refines *what* gets backed up and how
> it's retained.
>
> **The one real gap:** `/etc/backup-exclude` excludes `var/www/nextcloud/data`,
> so the **~239 G of Nextcloud data is in no backup and not on saito**. That is
> the single most important thing to stage before the wipe.

### Nextcloud data: back it up — to saito only, never locally

**Decided.** The old "users carry their own backup risk" stance was a workaround
for a disk-space constraint that no longer exists. But the stronger argument is
that a *local* backup on this box would be near-worthless regardless: single
disk, no RAID, so a disk/VPS failure kills live data and backup together. It
would only guard against accidental deletion — which Nextcloud's trash +
versioning already covers — while eating 239 G of the 1.2 TB.

- **Live data on the vserver, backup on saito** (25 TB RAID5 + external USB).
  rsync moves only deltas after the first sync.
- **This is what frees the quota headroom**: OS+services ~50 G + data ~160 G +
  small staging leaves **~900 G** — enough to pull personal data and mobile photo
  backups back off OneDrive.
- Back up **data + DB dump + `config.php`** — *not* the app code (the container
  image is re-pullable).

**Don't back up (or migrate) the regenerable ~75 G:**

| Path | Size | Why skip |
| ---- | ---- | -------- |
| `appdata_*/preview/` | bulk of **67 G** | Preview thumbnails — regenerable, and the daily `preview:pre-generate` cron rebuilds them. *Keep the rest of `appdata_*`* (`identityproof/` holds instance keys; some apps store real state there). |
| `updater-*/` | **8.2 G** | Old app-version backups from the updater. Safe to delete outright. |
| `*.log`, `audit.log*` | ~294 M | Rotate/leave. |

Set `trashbin_retention_obligation` + `versions_retention_obligation` — both live
*inside* `data/`, so unbounded they'd dominate the backup with deleted files.

**Consistency:** file-level rsync of a live `data/` can drift slightly from the
DB. At 2 am with 2–4 users this is low-risk (Nextcloud writes files whole rather
than editing in place) and `occ files:scan` repairs drift. Not worth
maintenance-mode gymnastics at this scale.

### Transfer budget — the restore is the long pole, not the pull

Measured from the existing pull log (`17,436,921 bytes/sec`), not guessed:

| Leg | Constraint | Rate | 165 G takes |
| --- | ---------- | ---- | ----------- |
| vserver → saito (**pull**) | vserver uplink / observed | ~17.4 MB/s (~139 Mbit) | **~2.7 h** |
| saito → new vserver (**restore**) | **saito's ~54 Mbit upload** | ~6.75 MB/s | **~6.8 h** |

The home connection's *download* (~556–850 Mbit) never binds. The **upload does**,
and only on the restore leg — which is easy to overlook because the backup
direction makes upload look irrelevant. Both legs are unattended; just budget the
weekend for ~7 h of restore, not ~3 h.

> The existing `backup-11001001` uses `rsync -avz`. The `-z` wastes CPU
> compressing already-gzipped `.tar`/`.gz` files — likely why it sits at 17 MB/s
> rather than nearer the link. The staging script omits `-z` on purpose.

If the restore leg ever becomes painful (bigger data after the OneDrive move), a
datacenter-side intermediary — Hetzner Storage Box (~€3.81/mo, SFTP/rsync, no
traffic fees), S3, or B2 — makes both legs DC-to-DC and fast. Overkill for a
one-off; relevant if this repeats.

### Cutover: bulk pull early, short consistent delta at the end

Downtime tolerance is generous (a weekend), so this is *not* about minimising
downtime — it's about **de-risking**. Running the bulk pull while the box is still
live costs nothing and proves the sudoers path, throughput and disk space work
*before* the box is down and committed.

1. **Bulk pull now**, box live and in use (~2.7 h, unattended).
2. **Cutover window:** `occ maintenance:mode --on` → delta sync (minutes — rsync
   only moves changes) → final DB dump *in the same window* so files and DB agree
   → Contabo snapshot → wipe.

Same script both times; it's resumable and re-running skips completed work.

**Weekend minimum viable:** Caddy + Docker + Nextcloud back online. Everything
else (SilverBullet, monitoring polish, wiki migration) can follow at leisure.

### There is a real, active second user — plan the cutover around her

`galadriel` (mother) last logged in **the day before this was written** — she is
an active, roughly-daily user with **50 G**. This is not a museum piece to be
migrated at leisure:

- **Give her advance notice** of the downtime window, and tell her when it's done.
- **The 165 G pull is not one-shot.** Her data changes between staging and
  cutover. Do it in two passes:
  1. **Bulk pull now** — hours, while the box stays live and in use.
  2. **Final delta sync at cutover** — minutes, because rsync only moves what
     changed. Then wipe.
  The staging script is resumable and re-running skips completed work, so pass 2
  is just running it again.
- Take the **final DB dump in the same window as the delta sync**, so files and
  DB agree.

Restore scope: `cbaoth` 101 G + `galadriel` 50 G ≈ **151 G** (+11 G if the
brother's account is kept — ask him).

### Stop tarring things that can't be restored from a tar

The current `backup` script tars `/var/lib` wholesale → **`var+lib.tar` is 15.8 G**,
and it includes **`/var/lib/mysql` while MariaDB is running**. A tar of a live
InnoDB data directory is inconsistent and cannot be trusted to restore — the
*real* DB backup is the nightly `dbbackup` dumps. Same story for
`/var/lib/docker`: images are re-pullable and container layers are ephemeral;
only named **volumes** matter.

→ On the new box, exclude `/var/lib/mysql` and `/var/lib/docker` from file-level
backup; rely on DB dumps + volume backups + compose files. (restic makes this
natural.)

**saito pulls. The vserver never pushes.**

*Correction to an earlier claim:* this is **not** because saito is unreachable —
it is reachable in principle, via dynamic DNS (`<DDNS_HOST>`, CNAMEd from a
subdomain) plus a router port-forward. The real reasons are:

1. **Security (the durable reason):** a pull model means a compromised vserver
   has **no credentials and no delete power** over the backups. Push-based
   backups are what ransomware eats.
2. **Practical (today):** saito runs the **NordVPN client on auto-connect**, which
   breaks inbound port-forwarding — verified from the vserver: saito's forwarded
   SSH port times out while the VPN is up. See the saito section for why, and the fix.

Pull sidesteps the VPN routing problem entirely (outbound connections from saito
are unaffected), *and* is the safer design. So it stands either way — but on
merit, not on a false "it's impossible".

### Replace tar full/incremental with restic

The current scheme (monthly full + weekly incremental tar, `find -mtime +40 -delete`)
is doing a lot of work for a mediocre result: 156 G of archives on the box itself,
no dedup, no verification, and restoring one file means finding the right full +
replaying incrementals.

**Recommended: [restic](https://restic.net/)** — incremental-forever, deduplicating,
encrypted, with real retention policies and integrity checks. It collapses the
full/inc distinction entirely.

| Role | Job |
| ---- | --- |
| **vserver** | Only produces small local state: nightly **`dbbackup` dumps** + a config export into a *small, capped* `/backup` staging dir. **No more giant tar archives on the box** (reclaims ~156 G). |
| **saito** | cron: `rsync` pull (Nextcloud data, `/home`, `/etc`, `/var/www`, staging dumps) → `restic backup` into its repo on the external USB `/backup` disk → `restic forget --prune` (e.g. `--keep-daily 7 --keep-weekly 4 --keep-monthly 12`) → periodic `restic check`. |
| **offsite tier** | `restic copy` the crown jewels (Nextcloud data + DB dumps) to **S3/cloud**. Restic's dedup+encryption makes this cheap and safe on untrusted storage. |

This keeps `dbbackup` (still useful) and retires the `backup` tar script's role on
this host — a rare case where the modern tool is genuinely simpler, not just newer.

### Contabo auto-backup add-on (<€2/mo)

**Complements, doesn't replace.** It's a hypervisor-level *image* backup: great for
"the box is dead, roll it back", useless for "restore one file from three months
ago" — which is exactly what restic gives you. Cheap enough to be worth it as a
disaster tier **if** the details check out. Verify before booking:

- [ ] Frequency + retention (how many, how long)?
- [ ] Restore granularity (full image only, presumably) and restore time?
- [ ] Does it consume your 1.2 TB quota or is it separate storage?
- [ ] Any hidden per-restore cost or bandwidth limits?

## Firewall

Replace the ancient `rc.firewall` iptables script:

- **Host:** `ufw` (default deny-in / allow-out) or `nftables` directly. Open only
  SSH + 80/443, plus any explicitly-decided service port. Docker's own iptables
  integration handles container publishing — don't hand-roll FORWARD rules.
- **Edge:** enable the **Contabo panel firewall** as a second, out-of-host layer
  (blocks even if the host firewall is misconfigured during setup).
- **fail2ban** for SSH (and Caddy/Nextcloud auth logs) — replaces `blacklist.py`.
- The old `rc.firewall` (in `_local/`) is kept only as a reference for which ports
  were historically open; it is **not** carried over.

## Related: saito needs the same treatment

`saito` (LAN server / NAS, [../reference/hardware-saito.md](../reference/hardware-saito.md))
should get the **same monitoring + notification tooling** so both hosts share one
format and (ideally) one dashboard:

- [ ] Netdata on saito (+ later, join the same Grafana/Prometheus).
- [ ] Same msmtp/notification path (domain-less / relay-account) for alerts.
- [ ] saito is the **offsite backup target** for the vserver (`/backup/vserver-migration/`
      now; ongoing rsync/SFTP after cutover), plus optional S3 for the crown jewels.
- [ ] Consider doing the monitoring + notification setup on **both hosts in
      parallel** — it's the same work twice and they share the alert destination.
- [ ] **Give saito's own backups a dedicated subdir** (e.g. `/media/backup/saito/`).
      They currently sit at the root of `/media/backup/`, directly beside the
      `11001001.org/` mirror and assorted other archives — which already caused a
      false "the mirror is corrupt!" scare when the wrong path was compared.
      Cheap fix, removes a whole class of confusion.
- [ ] Investigate on saito: `backup.err` on the vserver is **23 M** — worth a look
      at what has been erroring nightly and for how long.

### saito: NordVPN breaks inbound port-forwarding

Verified from the vserver: saito's forwarded SSH port times out while NordVPN is
connected (auto-connect is on). Not a firewall problem — **asymmetric routing**:

> An inbound connection arrives on saito's LAN interface (router DNAT, which
> preserves the *original public* source IP). saito's reply consults the routing
> table, finds NordVPN's tunnel as the default route, and sends the reply out the
> VPN with the wrong source address. It never gets back. The connection hangs.

This is why a LAN-subnet allowlist (`nordvpn allowlist add subnet <LAN_SUBNET>`)
does **not** fix it on its own — the source IP isn't on the LAN.

Options, roughly in order of preference:

1. **Don't need inbound at all** — the backup design has saito *initiating*
   (outbound is unaffected by the VPN). Costs nothing, fixes it by construction.
   ← current plan.
2. **Scope NordVPN to what actually needs it** (a container/app), rather than
   system-wide on a machine whose job is serving. A blunt system-wide VPN on a
   NAS is the root cause here.
3. **Policy routing with connmark** — the "proper" fix if inbound is ever
   required: mark connections arriving on the LAN interface, restore the mark on
   replies, and route marked traffic via the LAN gateway instead of the tunnel
   (`iptables -t mangle` CONNMARK + `ip rule fwmark … table …`). Works, but is
   fiddly and can break on NordVPN client updates.

→ Only worth solving if a use-case appears (e.g. reaching saito's services
remotely). For backups: not needed.

## Open questions / to confirm

**Resolved:** OpenVPN → drop (maybe saito/RPi later) · TeamSpeak / squid / Tor /
pi-hole → drop (all past-use, none current) · gitea → drop (repo is local) ·
SSH port → keep the existing non-standard port · **Nextcloud → stays on MariaDB,
no conversion** (matches upstream's recommendation; conversion buys nothing) ·
LUKS → no · **install → free standard image, single ext4 root (no paid ISO, no
LVM)** · **storage → 1.2 TB confirmed provisioned; only the partition is short** ·
the 3 postgres clusters + all extra sites/home-dirs → backup, don't restore ·
users → only `cbaoth` recreated · **`maenner` wiki → migrate to SilverBullet**
(later stage / separate mini-project, not a setup blocker) · **backup → saito
pulls; restic; retire the tar full/inc scheme** · **mail → start simple
(relay account), revisit proper domain mail later**.

**Still open:**

- [ ] Safety check before wipe: confirm **Tor** was never configured as a
      relay/exit (abuse liability), and that nothing still actively needs the
      old services.
- [ ] Archive the nostalgic bits explicitly: `~/www/php/sport/` + a dump of its
      tiny postgres DB (bodyweight/muscle tracker) — for the archive, not restore.
- [ ] **Contabo auto-backup add-on** — check the details listed above, then decide.
- [ ] Offsite S3/cloud tier for the crown jewels — which provider/bucket.
- [ ] SilverBullet: does it support scoped accounts for a few friends (decides
      whether `maenner` fully migrates or keeps a read-only export)?
