---
title: Web browsers
hosts: [motoko]
status: resolved
tags: [browser, apt, gpg, firefox, vivaldi, brave]
updated: 2026-07-12
---

# Web browsers

**Not automated.** Each browser means a third-party apt repo plus a signing key,
and the exact incantation drifts every release. A stale automated version would
silently install from an unverified source — worse than doing it by hand. When
these stabilise, they can move into a `setup/modules/` module.

**Browsers come from apt, not flatpak.** A **sandboxed browser** cannot do native
messaging to KeePassXC, so password integration breaks outright.

Note the asymmetry, which is easy to get backwards: it is the *browser* that must
be native, not KeePassXC. KeePassXC itself runs perfectly well as a flatpak (and
does, here) — see
[../reference/package-managers.md](../reference/package-managers.md).

## The pattern

Every one of these is the same four steps, and it is worth recognising rather
than memorising:

1. Fetch the vendor's signing key into `/usr/share/keyrings/` (or
   `/etc/apt/keyrings/`) — **dearmored** (`gpg --dearmor`), not ASCII.
2. Write a deb822 `.sources` file into `/etc/apt/sources.list.d/`.
3. Point `Signed-By:` at the key from step 1. *This is the step that matters* —
   without it the repo is trusted globally rather than only for its own packages.
4. `apt-get update && apt-get install <browser>`.

## Firefox

Ubuntu ships Firefox as a snap. The Mozilla apt repo gives you the real thing:

```shell
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
  | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
```

Verify the fingerprint is `35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3`:

```shell
gpg -n -q --import --import-options import-show \
  /etc/apt/keyrings/packages.mozilla.org.asc | grep -A1 pub
```

```shell
sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
```

Pin it above the Ubuntu snap-transitional package, or apt will keep preferring
Ubuntu's:

```shell
sudo tee /etc/apt/preferences.d/mozilla > /dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

sudo apt-get update && sudo apt-get install firefox
```

## Vivaldi / Brave / Chrome / Edge

All follow the pattern above. The vendor `.deb` usually installs its own repo,
but often writes a legacy `.list` file without `Signed-By:` — fix it:

```shell
# example: Vivaldi
curl -L https://repo.vivaldi.com/stable/linux_signing_key.pub \
  | gpg --dearmor | sudo tee /usr/share/keyrings/vivaldi-keyring.gpg >/dev/null
# then add Signed-By: /usr/share/keyrings/vivaldi-keyring.gpg
# to /etc/apt/sources.list.d/vivaldi.sources
```

`sudo apt modernize-sources -y` converts legacy `.list` files to deb822
`.sources`, which is worth doing once and then keeping.

## ungoogled-chromium

The exception — flatpak is fine here, since it is not doing KeePassXC
integration. Already in
[`setup/packages/flatpak-desktop.list`](../../setup/packages/flatpak-desktop.list).

## Tor

```shell
sudo apt-get install -y torbrowser-launcher
torbrowser-launcher    # fetches and runs the current version
```

Broken install? `rm -rf ~/.local/share/torbrowser` and relaunch.
