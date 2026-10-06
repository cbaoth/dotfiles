---
title: Claude Code CLI and Claude Desktop
hosts: [motoko, saito, 11001001]
status: resolved
tags: [claude, anthropic, apt, gpg, cli, desktop, ai, sandbox, apparmor]
updated: 2026-10-06
automated_by: setup/modules/28-claude-code.sh, setup/modules/29-claude-desktop.sh
---

# Claude Code CLI and Claude Desktop

**Automated:**

| Module | Profiles | What |
| ------ | -------- | ---- |
| `system-setup 28-claude-code` | all | CLI via Anthropic's native installer into `~/.local/bin/claude` |
| `system-setup 29-claude-desktop` | desktop | Anthropic's apt repo + the `claude-desktop` package |

Two tools, two channels, and the split is deliberate — see below. Both are
signed by the same key: `31DDDE24 DDFAB679 F42D7BD2 BAA929FF 1A7ECACE`,
*Anthropic Claude Code Release Signing*, served from `downloads.claude.ai`.

## CLI: why the native installer and not apt

Anthropic publishes the CLI three ways — the native installer, apt/dnf/apk
repos, and npm. All three install the *same* binary. The native installer wins
here for two reasons:

1. **One setup on every host.** These dotfiles land on boxes with no root, on
   non-Debian systems, and in containers. `curl … | bash` works on all of them;
   apt works on some. A mix of "apt here, tarball there" is a second thing to
   remember at exactly the moment something is broken.
2. **It updates itself.** Native installs check for updates on startup and in
   the background. The apt, dnf, apk, Homebrew and WinGet packages do **not** —
   they move only when the machine is upgraded. For a tool shipping several
   releases a week that is the difference between current and months behind.

The cost is a pipe-to-shell, which nothing else in `setup/` does. It is
accepted because the alternative is the same vendor, the same host, and the
same signing key — trusting the apt repo but not the installer would be
theatre. The installer verifies a SHA256 from a signed manifest before running
anything it downloaded.

```bash
curl -fsSL https://claude.ai/install.sh | bash          # latest (module default)
curl -fsSL https://claude.ai/install.sh | bash -s stable # ~1 week behind, skips known-bad releases
curl -fsSL https://claude.ai/install.sh | bash -s 2.1.89 # pin a version
```

The channel is the `CLAUDE_CLI_CHANNEL` constant at the top of the module.

**Never run the installer with `sudo`.** It installs into `$HOME`, and under
sudo that is root's home — the binary lands in `/root/.local/bin` and `claude`
is then simply not found in your own shell. The installer refuses outright, and
the module runs it unprivileged.

### Layout, updates, uninstall

```text
~/.local/bin/claude                 → symlink into the versions dir
~/.local/share/claude/versions/     → the installed binaries
~/.claude/, ~/.claude.json          → settings, MCP servers, session history
```

```bash
claude --version    # confirm the install
claude doctor       # install health, settings errors, last auto-update result
claude update       # force an update now instead of waiting for the background check
```

Uninstall is `rm -f ~/.local/bin/claude && rm -rf ~/.local/share/claude`.
Configuration under `~/.claude` survives that on purpose — the VS Code
extension and the desktop app write there too.

`~/.local/bin` is put on `PATH` by `dotfiles/.common_env`, i.e. by
`dotfiles-link`, not by the setup module. On a fresh box where `system-setup`
ran first, `claude` is installed but not yet on `PATH`; run `dotfiles-link` and
start a new shell.

### Two installs at once is the failure mode

`claude` from apt and `claude` from the native installer both end up on `PATH`,
and which one runs depends on `PATH` order — so the version you run stops
matching the version you updated. The module warns when it finds an apt
`claude-code` or a global npm `@anthropic-ai/claude-code` alongside its own
install; it does not remove either, because removing a package someone
installed deliberately is a worse surprise than the warning. Keep one:

```bash
sudo apt remove claude-code                    # or
npm uninstall -g @anthropic-ai/claude-code
```

### Manual: the Bash sandbox on Ubuntu 26.04 (AppArmor)

**Not automated, on purpose:** it relaxes a distro hardening default. Done on
motoko (2026-10-06). **Deliberately skipped on servers** (saito, the vserver):
there Claude runs with the sandbox off, which is the better trade than weakening
a multi-service host's userns restriction.

The sandboxed Bash tool needs `bubblewrap` and `socat` (in `base.list`, and the
CLI module warns if missing), but on Ubuntu 26.04 that is not enough. Every
sandboxed command fails, even `echo`:

```text
apply-seccomp: write /proc/self/setgroups (nested userns is capability-restricted;
caller must provide CAP_SYS_ADMIN): Permission denied
```

Why: `kernel.apparmor_restrict_unprivileged_userns=1` (the Ubuntu default), and
the shipped `/etc/apparmor.d/bwrap-userns-restrict` confines `/usr/bin/bwrap`.
Everything bwrap starts drops into the `unpriv_bwrap` child profile, which
carries `audit deny capability`. Claude's seccomp helper runs *inside* the
sandbox and needs a nested user namespace, so the deny kills it. A deny can't be
overridden by an allow, and the helper is bundled in the `claude` binary, so
skipping the optional seccomp step is not an option either.

Anthropic's documented fix, an unconfined `/etc/apparmor.d/bwrap` profile, does
**not** work on its own: the shipped profile defines the same name `bwrap` and
stays loaded alongside it. The shipped one has to be disabled:

```bash
# 1) our profile: bwrap unconfined, allowed to create user namespaces
sudo tee /etc/apparmor.d/bwrap >/dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>
profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
EOF

# 2) disable the shipped profile persistently (survives package upgrades), unload it, load ours
sudo ln -s /etc/apparmor.d/bwrap-userns-restrict /etc/apparmor.d/disable/
sudo apparmor_parser -R /etc/apparmor.d/bwrap-userns-restrict
sudo apparmor_parser -r /etc/apparmor.d/bwrap

# 3) verify: only "bwrap (unconfined)", no unpriv_bwrap
sudo grep -E '^(bwrap|unpriv_bwrap) ' /sys/kernel/security/apparmor/profiles
```

Then, from Claude, a sandboxed `echo ok` must succeed. A write outside the
allowed paths must still fail with *Read-only file system*: that checks the
sandbox actually confines, not just that it starts.

**The trade:** Ubuntu ships that profile so bwrap can't be used as a gadget to
get capabilities in a user namespace, a known local-privilege-escalation
surface. Disabling it returns bwrap to the upstream behaviour Anthropic's docs
assume. On a single-user desktop where every local account is you, that is a
modest increase. Flatpak keeps working (it uses bwrap too), and `glycin.bwrap`
is a separate profile that stays untouched.

Rollback:

```bash
sudo rm /etc/apparmor.d/disable/bwrap-userns-restrict /etc/apparmor.d/bwrap
sudo systemctl reload apparmor
```

**Known noise, unrelated:** shell init inside the sandbox prints
`fnm ... Can't create the symlink for multishells ... Read-only file system`,
because `/run/user/<uid>` is read-only there. Commands still run; it's cosmetic.

## Desktop: apt, because there is no other Linux channel

Linux support for the desktop app is a **beta**, Debian-based only. Ubuntu
22.04+ or Debian 12+ (`libc6 >= 2.34`), amd64 or arm64 — the repo publishes
nothing else, and the module skips itself on any other architecture. On Fedora
or Arch, run the CLI instead.

The repo setup follows the usual four steps (key → sources → `Signed-By:` →
install, see [browsers.md](browsers.md#the-pattern)) with two deviations, both
forced by the package **managing its own apt entry** from its `postinst` — the
VS Code / Chrome / 1Password model, where installing the `.deb` by hand also
registers the repo so updates arrive afterwards:

- **A one-line `.list`, not a deb822 `.sources`.** `/etc/apt/sources.list.d/claude-desktop.list`
  is the filename the package writes. Use `.sources` and you get *both* files:
  one repo configured twice, and apt says so on every update.
- **Written only if absent, never rewritten.** The package claims the file with
  a marker comment on line 1 and rewrites it on every upgrade. A module that
  also rewrote it would flap against the package as soon as upstream edits that
  header, and "a re-run reports zero changes" would quietly stop being true.

The module writes the file *with* that marker, byte-identical to the package's
own version. Writing it without would be read as admin-owned and left alone —
which also drops the unattended-upgrades snippet the package ships next to it
(`/etc/apt/apt.conf.d/50claude-desktop`, scoped by `site=downloads.claude.ai`).

To opt out of the package managing apt at all, put
`CLAUDE_DESKTOP_ADD_REPO="false"` in `/etc/default/claude-desktop`. Only that
one key is read from that file.

### Recommends are not optional here

`29-claude-desktop` uses `st::apt_install_recommends`, against the rule that
package sets stay explicit. What the Recommends carry:

| Recommends | Without it |
| ---------- | ---------- |
| `libasound2t64` / `pulseaudio` | no audio |
| `libayatana-appindicator3-1` | no tray icon |
| `gnome-keyring` / `kwalletd` | the login is not stored |
| `qemu-system-x86`, `ovmf`, `virtiofsd` | Cowork reports *"Cowork requires QEMU"* |

`apt install claude-desktop` — Anthropic's documented command — installs all of
these; `--no-install-recommends` is the deviation. The QEMU stack is the
expensive one on disk: Cowork runs its agentic tasks in a VM the app hosts.

### Manual: the kvm group

**Not automated, on purpose.** Cowork also needs `/dev/vhost-vsock`, which only
`kvm` group members can open — no polkit rule grants it, and some desktops
handing you `/dev/kvm` without the group is a red herring:

```bash
sudo usermod -aG kvm "$USER"   # then log out and back in
```

A group change only takes effect on the next login, so a module running
`usermod` would report success while nothing actually worked until the next
session. Hardware virtualization must also be on in firmware, and the app
checks all of this **once at launch** — restart it after installing packages.

### Sway: the app forgets the login

Claude Desktop is Electron, so it hits the same `XDG_CURRENT_DESKTOP`
keyring problem as VS Code: Chromium does not recognise `sway`, refuses to use
libsecret, and the sign-in is not saved. `bin/claude-desktop` wraps the binary
and appends `GNOME` to the list. Full explanation, and why no `.desktop`
override is needed here: [sway.md](sway.md#claude-desktop).

### Not in the Linux beta yet

Computer Use, dictation, and the Quick Entry global hotkey on native Wayland.
Use the CLI for [voice dictation](https://code.claude.com/docs/en/voice-dictation).

## Uninstall

```bash
sudo apt remove claude-desktop     # also removes its repo entry and key
```

## References

- [`setup/modules/28-claude-code.sh`](../../setup/modules/28-claude-code.sh) — the CLI module
- [`setup/modules/29-claude-desktop.sh`](../../setup/modules/29-claude-desktop.sh) — the desktop module
- [`bin/claude-desktop`](../../bin/claude-desktop) — the Sway keyring wrapper
- [Desktop on Linux](https://code.claude.com/docs/en/desktop-linux) — upstream install instructions
- [Advanced setup](https://code.claude.com/docs/en/setup) — every CLI install channel, key verification
- [Sandboxing](https://code.claude.com/docs/en/sandboxing) — what the Bash sandbox enforces, Linux prerequisites
