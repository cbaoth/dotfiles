---
title: Wine (WineHQ) and PE file inspection
hosts: [motoko, puppet]
status: resolved
tags: [wine, apt, gpg, i386, windows, pe, readpe]
updated: 2026-08-16
automated_by: setup/modules/27-wine.sh
---

# Wine (WineHQ) and PE file inspection

**Automated:** `system-setup 27-wine` (desktop profile) enables the i386
architecture, sets up the WineHQ apt repo (signing key + deb822 sources),
installs `winehq-stable` and `winetricks` **with** their Recommends, and
installs `readpe` for inspecting Windows binaries.

## Wine comes from WineHQ, not from Ubuntu

Ubuntu's `wine` package trails upstream badly and the two stacks conflict —
Ubuntu ships `wine` / `wine32` / `wine64` / `libwine`, WineHQ ships
`winehq-*` / `wine-*`. Install one, not both.

The manual equivalent of what the module does:

```shell
sudo dpkg --add-architecture i386

sudo install -d -m 0755 /etc/apt/keyrings
wget -O - https://dl.winehq.org/wine-builds/winehq.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key -

sudo wget -NP /etc/apt/sources.list.d/ \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/$(lsb_release -sc)/winehq-$(lsb_release -sc).sources"

sudo apt update && sudo apt install --install-recommends winehq-stable
```

Verify the key fingerprint is `D43F640145369C51D786DDEA76F1A20FF987672F`:

```shell
gpg -n -q --import --import-options import-show \
  /etc/apt/keyrings/winehq-archive.key | grep -A1 pub
```

### `--install-recommends` is not optional

WineHQ's Recommends carry gnutls (so HTTPS works inside Wine), SDL2, the
printing stack, and a chunk of the font handling. Installed without them, Wine
starts and then fails in ways that look like application bugs. This is why the
module calls `st::apt_install_recommends` — the only place in `setup/` that
does, and the reason that helper exists at all.

The one Recommends apt cannot satisfy is `libtiff5`, which has no candidate in
questing at all (`apt-cache policy libtiff5` → `Candidate: (none)`). Harmless,
but it does mean the install log always ends with one unmet recommend.

`winetricks` is in the same call for the same reason. Its Recommends are not
extras — they are the tool: **cabextract** unpacks the Windows CAB archives
that every DLL verb installs from, and **zenity** is its entire GUI. Without
them `winetricks corefonts` simply fails.

It `Depends: wine`, which `winehq-stable` **Provides** — so installing it does
not drag Ubuntu's wine back in. (That same Provides is why the conflict check
below cannot use `st::apt_installed`.)

### Branches

The repo carries three channels; `winehq-stable` is what the module installs.

| Package | Channel |
| ------- | ------- |
| **winehq-stable** | stable releases |
| winehq-staging | stable + the staging patchset (extra fixes, more churn) |
| winehq-devel | development snapshots |

They conflict with each other. To switch, change `WINE_BRANCH` in
`setup/modules/27-wine.sh` and remove the old package by hand first.

## i386 is no longer about Wine itself

Worth knowing, because the instructions everywhere still lead with it:

Since Wine 10's new WoW64, the WineHQ repo for **questing is amd64-only** —
`Architectures: amd64`, no `wine-stable-i386` package exists to install. Checked
against the live repo, not assumed:

```shell
curl -fsSL https://dl.winehq.org/wine-builds/ubuntu/dists/questing/Release \
  | grep Architectures     # -> Architectures: amd64
```

The module still enables i386 for two reasons that have nothing to do with the
wine packages: older releases (noble and earlier) genuinely do ship
`wine-*-i386`, and 32-bit GPU/driver libraries are what many Windows games pull
in. The cost is one extra index fetch per `apt update`.

## Release upgrades break the sources file

The repo suite *is* the distro codename, so the file is
`winehq-<codename>.sources`. After a release upgrade the old file points at a
suite that no longer resolves and **every** `apt update` fails, not just Wine's.
The module removes `winehq-*.sources` files that do not match the current
codename for exactly this reason.

WineHQ also lags Ubuntu's interim releases by a few weeks. The module checks
that `dists/<codename>/Release` actually exists before writing the sources file
and warns off rather than leaving apt broken.

## Cleaning up Ubuntu's wine — manual on purpose

If Ubuntu's wine is already installed and fights the WineHQ setup, the module
**warns and stops there**. It will not purge packages: a `wine*` glob can sweep
up far more than intended, and the right answer depends on what else is on the
box.

```shell
sudo apt-get purge 'wine*' 'wine*:i386'
sudo apt-get autopurge
```

**Read the removal list before confirming.** If something you still need is
about to go, cancel and narrow the pattern to named packages.

## Inspecting Windows binaries (.exe / .dll)

The package is **`readpe`**. `pev` is now only a transitional shim that depends
on it — installing the shim works today and rots quietly later, so the module
names the real package. (This is the same class of trap as `exiftool` and
`p7zip-full`; see [../reference/package-managers.md](../reference/package-managers.md).)

It provides `peres`, `readpe`, `pedis`, `peldd`, `pescan`, `pesec`, `pestr`,
`pehash`, `pepack`, `ofs2rva`, `rva2ofs`.

The tool names are unguessable from the task ("what version is this exe?"), so
`lib/aliases-linux.sh` wraps the useful ones under names you can actually reach
by typing `exe<TAB>` or `pe<TAB>`:

| Alias | Runs | Does |
| ----- | ---- | ---- |
| `exe-version` / `pe-version` | `peres -v` | File Version from the PE resource directory |
| `exe-info` / `pe-info` | `peres -i -s` | resource info + statistics |
| `exe-headers` / `pe-headers` | `readpe -H` | DOS / COFF / optional headers |
| `exe-extract` | `peres -X` | extract embedded resources (icons, manifests) |

**`peres -a` is deliberately not aliased.** Despite reading like "show
everything", it *also* extracts every resource into a `resources/` directory in
the current working directory. `exe-info` uses `-i -s`, which is the same
information with no files written.

## Related

- [`setup/modules/27-wine.sh`](../../setup/modules/27-wine.sh) — the module
- `ps-wine` in `lib/functions.sh` — list Wine processes with Windows paths
  resolved back to Linux paths via each process's `WINEPREFIX`
- `winer` alias — `wine start /unix`, to open a Linux path from Wine
