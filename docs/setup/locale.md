---
title: Locales — en_US language, en_DK formats
hosts: [all]
status: resolved
tags: [locale, i18n, dates]
updated: 2026-07-12
automated_by: setup/modules/10-locale.sh
---

# Locales

**Automated:** `system-setup 10-locale`

## The trick: en_DK

`LANG=en_US.UTF-8` for the interface language, but every `LC_*` format variable
set to **`en_DK.UTF-8`**.

`en_DK` is the one widely-available locale that gives **ISO-8601 dates**
(`2026-07-12`), 24-hour time, metric units, and A4 paper — while keeping
everything else in English. `en_GB` and `en_AU` get you metric and 24h but still
produce `12/07/2026`, which is ambiguous by design.

This is why timestamps across this repo's scripts are ISO-8601 without anyone
having to force it per-script.

| Variable | Value |
| -------- | ----- |
| `LANG` | `en_US.UTF-8` |
| `LC_NUMERIC`, `LC_TIME`, `LC_MONETARY`, `LC_PAPER`, `LC_NAME`, `LC_ADDRESS`, `LC_TELEPHONE`, `LC_MEASUREMENT`, `LC_IDENTIFICATION` | `en_DK.UTF-8` |

Changes take effect on next login.

## If it goes wrong

`update-locale` sometimes refuses to run when the existing files have invalid
content. In that case, overwrite `/etc/default/locale` (and `/etc/locale.conf`
on systemd-heavy setups) directly, then re-run the module.

Interactive fallbacks, in ascending order of desperation:

```shell
sudo dpkg-reconfigure locales   # menu: select locales to generate, then default
sudo vim /etc/locale.gen        # uncomment as needed, then:
sudo locale-gen
```

`~/.pam_environment` is **deprecated** — do not use it, it is silently ignored on
current Ubuntu.

## Verify

```shell
locale                # what is actually in effect
date                  # should print an ISO-8601-ish date
locale -a | grep -i dk
```
