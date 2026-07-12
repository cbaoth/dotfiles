---
title: Which package manager? (apt / flatpak / snap / AppImage / nix / uv)
hosts: [all]
status: resolved
tags: [apt, flatpak, snap, appimage, nix, packaging, decisions]
updated: 2026-07-12
---

# Which package manager?

Six package managers coexist on motoko (apt, flatpak, snap, AppImage, nix,
pip/uv) and it feels like a mess. It mostly isn't — but only if there is a rule.
This is the rule, so that the same three apps stop getting re-litigated every
six months.

## The one question that decides it

> **Does anything else have to invoke it *by name*?**

A flatpak is **not on `$PATH`**. It is `flatpak run org.foo.Bar`. So a script, a
shell alias, an `xdg-open` handler, or another app spawning it as a subprocess
**cannot reach it**.

That single fact resolves almost every case here, and it is the thing that gets
forgotten — the app works fine when you click it, so the breakage shows up later,
somewhere else, and looks unrelated.

| If… | Then |
| --- | ---- |
| A script, alias, or another app invokes it | **apt** |
| It integrates with the system (drivers, PAM, systemd, native messaging) | **apt** |
| It is a self-contained GUI app you only ever click | **flatpak** |
| The flatpak is meaningfully newer *and* nothing invokes it | **flatpak** |
| Nothing else works | AppImage / snap / nix, in that order of reluctance |

## Worked examples (the ones that actually bit)

### mpv → **apt**, non-negotiable

[`bin/mpv-find`](../../bin/mpv-find) pipes into `xargs -0 -n 10000 mpv`, and the
`@MPV` global alias in [`.zsh.d/aliases.zsh`](../../dotfiles/.zsh.d/aliases.zsh)
does the same. Both need a real binary on `$PATH`. The flatpak breaks both, and
it breaks them *quietly* — mpv still launches when you double-click a file.

A past switch to the flatpak was reverted for exactly this reason. It is recorded
here so it does not happen a third time.

### KeePassXC → **flatpak**

Counter-intuitive, and the opposite of what the old notes claimed.

The old note said "apt, because the browser extension needs it". That conflated
two different things:

- A **sandboxed browser** cannot do native messaging to KeePassXC. *True.*
- A **sandboxed KeePassXC** cannot serve a native browser. *False.*

Keep the browsers native and the flatpak KeePassXC works fine — which is what
motoko actually runs today. And the flatpak tracks upstream much more closely
(2.7.12 vs apt's 2.7.10), which matters, because the browser extension
**complains when KeePassXC is too old**. So the version freshness that flatpak
gives you is the thing that *fixes* the browser integration, not what breaks it.

### Browsers → **apt**

Because of the above: a sandboxed browser cannot reach KeePassXC. The one
exception is `ungoogled-chromium` (flatpak), which is not doing password
integration anyway.

### Cryptomator → **apt (PPA)**

Currently installed from `ppa:sebastian-stenzel/cryptomator` (`1.19.3-0ppa1`).
The flatpak exists and is the same version.

**Do not "clean up" `/etc/apt/sources.list.d/sebastian-stenzel-ubuntu-cryptomator-*.sources`.**
It looks like a leftover. It is not — it is what feeds the installed package. Remove
it and Cryptomator silently stops receiving updates.

If it ever *does* move to flatpak, it will need explicit `--filesystem` overrides
to reach mounts, plus `user_allow_other` in `/etc/fuse.conf` — see
[flatpak.md](flatpak.md). Upstream also offers an AppImage, AUR, and nix builds.

### ffmpeg → **neither**

Static GPL builds via [`bin/ffmpeg-install`](../../bin/ffmpeg-install). The apt
build is older and lacks filters (`rubberband`). And it must be on `$PATH`,
because everything shells out to it.

## The other four

**snap** — keep to a minimum. Currently `libreoffice`, `shellcheck`, `waveterm`.
Snap is where things land when Ubuntu forces it (Firefox — hence the Mozilla apt
repo in [../setup/browsers.md](../setup/browsers.md)).

**AppImage** — a few in `~/Applications/`. Managed by
[Gear Lever](https://flathub.org/apps/it.mijorus.gearlever), which is what
creates the desktop entries and metadata AppImages otherwise lack. Needs
`libfuse2t64`.

**nix** — installed, barely used. Hermes lives here (see the notes repo,
`projects/06-future-ideas.md`).

**pip / uv** — Python only, and **uv**, not pip. Never install into the system
python; use `uv` or a venv.

## Virtual packages — the trap that eats idempotency

Some familiar names are no longer real packages. They are **virtual names** that
a renamed package `Provides:`.

| You type | Actually installs | Real package |
| -------- | ----------------- | ------------ |
| `exiftool` | ✔ works | `libimage-exiftool-perl` |
| `p7zip-full` | ✔ works | `7zip` |

`apt-get install exiftool` works fine, so this looks harmless. It is not — because
**`dpkg-query` will never report a virtual name as installed.** Any script that
checks "is X installed?" by name gets `not-installed` forever, reinstalls it every
run, and reports a change every time.

`p7zip-full` is the vicious case: it still shows as installed on a machine that
*upgraded* through the transitional package, so the bug is invisible here and
only surfaces on a **fresh box** — the one place you least want to be debugging.

[`setup/lib/setup-lib.sh`](../../setup/lib/setup-lib.sh) handles this
(`st::apt_installed` falls back to checking the providers) *and* warns you to use
the real name. But the fix is to write the real name in the list.

To check any name:

```bash
apt-cache show <pkg> | grep '^Filename:'    # nothing → it is virtual
apt-cache showpkg <pkg>                     # "Reverse Provides:" → the real package
```

Or, with the `afsn` shell function (`apt-file search` by binary name):

```bash
afsn exiftool     # → libimage-exiftool-perl: /usr/bin/exiftool
```

## Auditing what you actually have

The single most useful command when this feels out of hand:

```bash
apt-mark showmanual          # explicitly installed apt packages (not deps)
flatpak list --app           # flatpaks
snap list                    # snaps
ls ~/Applications/           # AppImages
nix profile list             # nix
uv tool list                 # uv-installed CLI tools
```

`apt-mark showmanual` is the one to reach for: it hides the thousands of
dependencies and shows only what *you* asked for — usually a much shorter and
more manageable list than expected.

## See also

- [../setup/flatpak.md](../setup/flatpak.md) — flatpak setup and app quirks
- [flatpak.md](flatpak.md) — override/permission syntax
- [../setup/browsers.md](../setup/browsers.md) — third-party apt repos
