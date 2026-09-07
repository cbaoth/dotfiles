# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 29-claude-desktop: Claude Desktop (Linux beta) from Anthropic's apt repo.
#
# The counterpart to 28-claude-code: the desktop app is apt-managed (there is
# no other Linux channel), the CLI is not. Same signing key for both —
# 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE, Anthropic Claude Code Release
# Signing — served from downloads.claude.ai.
#
# Two deliberate deviations from how 25-browsers sets up a repo, both forced by
# the package managing its OWN apt entry from its postinst (the VS Code /
# Chrome model):
#
#   1. A one-line `.list`, not a deb822 `.sources`. The filename is what the
#      package looks for; write claude-desktop.sources instead and postinst
#      adds claude-desktop.list next to it — two entries for one repo, and apt
#      warns about it on every update.
#   2. Written only when absent, never rewritten. The package claims the file
#      by a marker on line 1 (kept below, byte-identical) and rewrites it on
#      every upgrade; a module that also rewrote it would flap against the
#      package the moment upstream edits that header. Bootstrapping it here and
#      handing ownership over is what keeps a re-run at zero changes.
#
# Writing it with the marker rather than without also matters: an unmarked file
# is treated as admin-owned and left alone, which would silently drop the
# unattended-upgrades snippet postinst ships alongside it
# (/etc/apt/apt.conf.d/50claude-desktop).
#
# Sway users: the app cannot see the keyring under a bare XDG_CURRENT_DESKTOP=
# sway and forgets the login on every start — bin/claude-desktop wraps it. See
# docs/setup/sway.md.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Claude Desktop from Anthropic's apt repo (Linux beta)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/claude.md"

declare -r CD_KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
declare -r CD_KEY_FILE="/usr/share/keyrings/claude-desktop-archive-keyring.asc"
declare -r CD_KEY_FP="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

declare -r CD_SOURCES_FILE="/etc/apt/sources.list.d/claude-desktop.list"

# The repo publishes amd64 and arm64 only; arch= keeps a multiarch box (i386 is
# enabled here for wine) from warning about a missing index on every update.
declare -ra CD_ARCHS=(amd64 arm64)

# Byte-identical to what the package's postinst writes, marker line included —
# that is the whole point, see the header.
declare -r CD_SOURCES_CONTENT='### Managed by the claude-desktop package.
### Set CLAUDE_DESKTOP_ADD_REPO="true"|"false" in /etc/default/claude-desktop
### to force this entry on or off; remove this file too when opting out.
deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main'

# {{{ = Repo ================================================================

# The key is served ASCII-armored and referenced as .asc, so it is stored as
# served — dearmoring it would leave apt unable to read the name it is pointed
# at. (25-browsers dearmors for repos whose Signed-By ends in .gpg; the suffix
# has to match the encoding.)
cd_setup_key() {
  if [[ -f "${CD_KEY_FILE}" ]]; then
    st::noop "signing key already present: ${CD_KEY_FILE}"
  else
    st::run "install Claude Desktop signing key" -- \
      sudo sh -c "install -d -m 0755 '$(dirname "${CD_KEY_FILE}")' && \
        curl -fsSL '${CD_KEY_URL}' -o '${CD_KEY_FILE}' && \
        chmod 0644 '${CD_KEY_FILE}'"
  fi

  # Advisory, as everywhere else here: a mismatch is worth shouting about but
  # is not this module's call to resolve.
  if [[ -f "${CD_KEY_FILE}" ]] && ! (( ST_DRY_RUN )); then
    local fp
    fp="$(gpg -n -q --import --import-options import-show "${CD_KEY_FILE}" 2>/dev/null \
          | awk '/^pub/{getline; gsub(/^ +| +$/,""); print; exit}')"
    if [[ -n "${fp}" && "${fp}" != "${CD_KEY_FP}" ]]; then
      st::war "Claude Desktop key fingerprint mismatch! Expected ${CD_KEY_FP}, got: ${fp}"
    fi
  fi
}

cd_setup_sources() {
  if [[ -f "${CD_SOURCES_FILE}" ]]; then
    st::noop "apt sources already present: ${CD_SOURCES_FILE}"
    return 0
  fi

  st::run_sh "write ${CD_SOURCES_FILE}" \
    "printf '%s\n' $(printf '%q' "${CD_SOURCES_CONTENT}") \
      | sudo tee $(printf '%q' "${CD_SOURCES_FILE}") >/dev/null \
      && sudo chmod 0644 $(printf '%q' "${CD_SOURCES_FILE}")"

  # The index for a repo apt has never seen does not exist yet, so the age
  # heuristic in st::apt_update would wrongly call the cache fresh.
  st::apt_update --force
}

# }}} = Repo ================================================================

module_run() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null)"

  if [[ ! " ${CD_ARCHS[*]} " == *" ${arch} "* ]]; then
    st::war "Claude Desktop publishes no package for '${arch:-unknown}' — skipping"
    return 0
  fi

  cd_setup_key
  cd_setup_sources

  # Recommends, unlike the default everywhere else in setup/: here they are the
  # difference between the app working and half-working. They carry the audio
  # stack, the tray icon (libayatana-appindicator), the keyring integration the
  # login is stored in, and QEMU + OVMF + virtiofsd, which is the VM that the
  # Cowork tab runs its tasks in. `apt install claude-desktop` — Anthropic's
  # documented command — pulls them too; --no-install-recommends is the
  # deviation, not this.
  #
  # Cowork additionally needs the user in the 'kvm' group (for
  # /dev/vhost-vsock, which no polkit rule grants). That is left manual on
  # purpose: a group change only takes effect after a re-login, so a module
  # that ran usermod would report success while nothing worked until the next
  # session. docs/setup/claude.md has the one-liner.
  st::apt_install_recommends claude-desktop
}
