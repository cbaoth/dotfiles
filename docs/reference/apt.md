---
title: apt & dpkg cheatsheet
hosts: [all]
status: resolved
tags: [apt, dpkg, packages]
updated: 2026-07-12
---

# apt & dpkg

## Which package owns this file?

```shell
sudo apt-get install -y apt-file
sudo apt-file update

apt-file search -F "$(which convert)"   # -F: exact match (else implicit wildcards)
apt-file search -x '\/print$'           # -x: perl regex; match paths ending in /print
```

Paths in the index have **no leading slash** (`bin/zsh`, not `/bin/zsh`) —
`apt-file` strips them for you, but it explains otherwise-baffling misses.

## Is a package installed / available?

```shell
dpkg-query -W -f='${db:Status-Status}\n' PKG   # "installed" or nothing
apt-cache show PKG >/dev/null 2>&1             # known to apt at all?
apt-mark showmanual                            # explicitly installed (not pulled in as a dep)
```

The first two are exactly what
[`setup/lib/setup-lib.sh`](../../setup/lib/setup-lib.sh) uses to decide whether
a package needs installing.

## Release info

```shell
lsb_release -sc    # codename, e.g. "questing"
lsb_release -sr    # release number, e.g. "26.04"
```

Both show up constantly in third-party repo URLs.

## Modernise sources

Converts legacy `.list` files to deb822 `.sources` (which support `Signed-By:`):

```shell
sudo apt modernize-sources -y
```

## Simulate

```shell
apt-get -s upgrade | grep -c '^Inst '   # how many packages WOULD upgrade
```

`-s` is a dry run — useful for `--dry-run` support in scripts.

## aptitude

```shell
sudo apt-get install -y aptitude
```

Better dependency-conflict resolution than apt when things get tangled.
