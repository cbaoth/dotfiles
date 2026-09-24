---
title: SSH — key-only access
hosts: [all]
status: resolved
tags: [ssh, sshd, hardening, ufw, firewall, pubkey]
updated: 2026-09-23
automated_by: setup/modules/56-sshd.sh
---

# SSH — key-only access

**Automated:** `system-setup 56-sshd` writes the authentication baseline on any
host that has an sshd, validates it, and reloads the service. It deliberately
**never installs** `openssh-server` — enabling remote access is a per-host
decision, not a side effect of running `system-setup`. Hosts without sshd report
a clean no-op.

The firewall half is *not* automated — see [Exposure](#exposure) below.

## The two-file model

Everything lives in `/etc/ssh/sshd_config.d/`. The shipped `sshd_config` is left
pristine, because it is a package conffile: editing it earns a merge prompt on
every openssh upgrade, and the edit is invisible to anyone grepping for "what
did we change".

| File | Maintained by | Contents |
| ---- | ------------- | -------- |
| `01-local.conf` | by hand, per host | `Port`, `AllowUsers`, `AllowAgentForwarding`, `X11Forwarding`, `ListenAddress` |
| `10-hardening.conf` | the module | authentication policy, identical everywhere |

### Why the low number is the *override*

This reads backwards if you expect drop-ins to work like `sysctl.d` or
`systemd`, where a later file wins. sshd is the opposite:

> **sshd keeps the FIRST value it sees for a keyword.**

`Include /etc/ssh/sshd_config.d/*.conf` is the first line of `sshd_config`, the
glob expands in sort order, so **within the drop-in directory the lowest number
wins** — and it also wins over everything further down the main file. Hence the
host-specific file sorts *before* the managed baseline.

The practical consequence: a stray `05-something.conf` silently beats the
baseline, and it will not warn you. The module's last step reads back
`sshd -T` for exactly this reason (see [Verification](#verification)).

### The split: policy vs. topology

The line is *authentication policy* (identical on every host, safe to manage
centrally) against *exposure and topology* (where the host sits, who reaches
it — never knowable from a generic module):

- `AllowUsers` is **not** in the baseline on purpose — see
  [below](#allowusers-seeded-not-assumed).
- `X11Forwarding` likewise: wanted on a box you run GUI tools on over `ssh -X`,
  off on anything public-facing.
- `Port` is per-host, and a non-default port is obscurity, not security — it
  cuts log noise from untargeted scanners and nothing else.

## `AllowUsers`: seeded, not assumed

It is host-specific (a server with a backup-pull account needs it wider) and a
wrong value locks you out, so it stays out of the managed baseline. But leaving
it as a commented-out suggestion means the common case — one human account —
silently ends up unrestricted, so the module seeds it into `01-local.conf` at
creation, in this order of preference:

1. **Something else already sets `AllowUsers`/`AllowGroups`** (the main config,
   a bootstrap script's drop-in) → seed nothing; that file owns the decision.
2. **The baseline being replaced has one** → carry it over verbatim. A host
   hardened by hand before this module keeps its list there, and that list may
   be *wider* than the caller — narrowing it silently would break precisely the
   unattended jobs nobody notices until the next restore.
3. **Otherwise, the invoking account**, if it is a regular login account
   (uid ≥ `UID_MIN`, not `nobody`).
4. **Root or a service account** → seed nothing and warn. Restricting SSH to
   root would be worse than not restricting it at all.

The account in case 3 is the one the lockout guard has already proven can log in
by key — a stronger warrant than "an account by this name exists". On these
hosts that is always `cbaoth`, but nothing hardcodes the name.

Cases 3 and 4 both **warn**, rather than one being silent. A restriction you
believe is in place and is not is worse than none, because you stop checking.
And every run prints the *effective* value read back from `sshd -T`, not merely
"a restriction exists":

```
. effective: allowusers cbaoth
```

Worst case this is wrong, the account does not exist and the host refuses the
connection — recoverable from any console (Contabo's VNC recovery boot, a TTY on
a desktop). That trade is only acceptable *because* SSH is enabled from day one
on remote hosts: a box being hardened months into its life is, by construction,
one you are standing in front of.

## What the baseline enforces

`PubkeyAuthentication yes`, `PasswordAuthentication no`,
`KbdInteractiveAuthentication no`, `PermitEmptyPasswords no`,
`PermitRootLogin no`, `MaxAuthTries 3`, and:

```
AuthenticationMethods publickey
```

That last one is the belt-and-braces line and the reason this is worth having as
a managed file at all. `PasswordAuthentication no` is one keyword among many
that can re-enable a password path — GSSAPI and keyboard-interactive each have
their own. `AuthenticationMethods publickey` forecloses all of them at once, and
survives a distro upgrade dropping a new `60-cloudimg-settings.conf` into the
directory.

## The lockout guard

`AuthenticationMethods publickey` on a host with no authorized key is a locked
door with the key thrown away, and on a remote box it is unrecoverable without
console access. So the module refuses to write anything until the invoking
account has a non-empty `~/.ssh/authorized_keys` (or `authorized_keys2`, which
is a protocol-1-era leftover but still in OpenSSH's default
`AuthorizedKeysFile` — prefer the canonical name).

Install the client key *first*, then run the module:

```bash
# on the client
cat ~/.ssh/id_ed25519.pub
# on the target, paste into:
vim ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
```

`ssh-copy-id` is not an option once password auth is off — which is the usual
order-of-operations trap when rebuilding a host.

## Verification

Two separate questions, and the file on disk only answers the first one.

```bash
sudo sshd -t                    # does the whole config parse?
sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractive|authenticationmethods|permitrootlogin|allowusers)'
```

`sshd -t` must run against the **whole** config. `sshd -t -f <dropin>` checks the
fragment in isolation and will happily pass a config that cannot start.

A reload is genuinely required, not a formality: `ssh.socket` triggers a
**long-running** `ssh.service`, which parses the config once at startup and
hands each connection a copy of what it parsed then. A drop-in written and never
reloaded looks correct on disk while the host still accepts passwords. The
module reloads whenever it changed the file; by hand:

```bash
sudo systemctl reload ssh
```

To prove it from outside, ask the running server what it offers — no sudo, no
password prompt, works against any host:

```bash
ssh -o BatchMode=yes -o PubkeyAuthentication=no -v <host> true 2>&1 |
  grep 'Authentications that can continue'
# want: publickey
```

## Exposure

Deliberately **not** in the module: the rules are host-specific, and the client
addresses are not something this public repo should carry. Real values live in
`~/notes/systems/<host>/ssh.md`.

The shape, for a host that should only be reachable from named devices on one
interface:

```bash
sudo ufw allow in on <iface> proto tcp from <client-ip> to any port 22 \
  comment 'ssh: <device>'
```

Two things worth keeping:

- **Scope the rule to the interface** (`in on <iface>`), not just the source
  address. A host with several networks — wifi, a point-to-point link, a VPN —
  would otherwise honour a spoofed source address arriving on any of them.
- **Order matters, and ufw is first-match-wins.** An existing broad
  `ALLOW IN <subnet>` rule already covers port 22; a narrower deny has to be
  `ufw insert`ed above it, not appended.

Tailscale needs no rule: its `ts-input` chain handles only loopback and
anti-spoof cases and does not blanket-accept tailnet traffic, so ufw's default
deny applies to `100.64.0.0/10` like anything else.

## Per-host state

| Host | sshd | Notes |
| ---- | ---- | ----- |
| motoko | key-only | desktop; reachable from the wifi LAN only, see `~/notes/systems/motoko/ssh.md` |
| saito | key-only | LAN server |
| 11001001 | key-only | public-facing: non-default port, `AllowAgentForwarding no`, `X11Forwarding no`, extra service account, fail2ban. See [security-vserver.md](security-vserver.md) |

### Adopting it on a host that was configured by hand

The module overwrites an existing `10-hardening.conf`, which is where a
hand-hardened host keeps its `AllowUsers` — case 2 above carries that line into
`01-local.conf` in the same run, so nothing widens. Read the warning it prints
and confirm the list is the one you meant; everything else in the generated
template is commented out and inert.

The vserver predates this module — its drop-in is written by
`bootstrap-new-server.sh` (in the private notes repo) and is named
`01-hardening.conf`. It already sorts first, so adopting the module there means
renaming it to `01-local.conf`, dropping the lines the baseline now provides,
and keeping only the host-specific ones. Update the bootstrap script in the same
change or the next rebuild reintroduces the old file.

## See also

- [security.md](security.md) — PAM, FIDO2/U2F, KeePassXC, the rest of motoko's
  posture
- [security-vserver.md](security-vserver.md) — fail2ban, lynis, the public-facing host
