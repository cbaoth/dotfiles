# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 35-tailscale: Tailscale client (WireGuard mesh VPN) via the official installer.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.
#
# Installs only. Joining the tailnet (`sudo tailscale up`) needs a browser login
# and stays manual. The tray applet (Trayscale) is a flatpak and comes from
# setup/packages/flatpak-desktop.list via 20-flatpak.

MODULE_DESC="Tailscale client (tailnet join stays manual)"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/tailscale.md"

module_run() {
  # The official installer adds Tailscale's own apt repo (signing key + sources)
  # and installs the package, so updates come through apt from then on. It also
  # enables tailscaled. Same pattern as 60-netdata.
  if st::have_cmd tailscale; then
    st::noop "tailscale already installed"
  else
    st::run_sh "install tailscale via official install.sh" \
      'curl -fsSL https://tailscale.com/install.sh | sh'
  fi

  if tailscale status >/dev/null 2>&1; then
    st::noop "already joined to a tailnet"
  else
    st::war "not joined to a tailnet yet — run: sudo tailscale up"
  fi

  # Operator: lets a non-root user change tailscaled settings (Trayscale needs
  # it). Hint only, never set here — it hands that user control over the
  # host's network routing without sudo. Fine on a single-user desktop or
  # notebook (puppet, motoko); not wanted on saito or the vserver.
  [[ "$(st::profile)" == "desktop" ]] || return 0
  if tailscale debug prefs 2>/dev/null \
       | st::grep_q -E "\"OperatorUser\": *\"${USER}\""; then
    st::noop "${USER} is already the tailscale operator"
  else
    st::war "Trayscale needs an operator — single-user desktops only, run:"
    st::war "  sudo tailscale set --operator=\$USER"
  fi
}
