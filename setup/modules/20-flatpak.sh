# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 20-flatpak: Flatpak, the Flathub remote, and the desktop app set.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Flatpak + Flathub remote + desktop apps"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/flatpak.md"

declare -r FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# Host-specific filesystem overrides: apps that need to reach the NAS shares.
# Flatpak sandboxes deny this by default — see docs/reference/flatpak.md.
declare -r NAS_PATH="/srv/saito"
declare -ra NAS_APPS=(
  org.gimp.GIMP
  com.xnview.XnViewMP
  org.darktable.Darktable
  org.kde.krita
  org.videolan.VLC
  io.github.quodlibet.QuodLibet
  io.github.quodlibet.ExFalso
)
# mpv is not listed: it is the apt build (see setup/packages/desktop.list), so
# it is unsandboxed and reaches the NAS without an override.

# Dark-theme overrides: non-libadwaita GTK flatpaks that ignore the desktop
# color-scheme portal and render light on a dark desktop. Forced to the bundled
# dark Adwaita theme below. Add the app-id here when a new one turns up light.
declare -ra GTK_DARK_APPS=(
  io.github.slgobinath.SafeEyes
)

module_run() {
  st::apt_install flatpak gnome-software-plugin-flatpak

  # {{{ - Flathub remote ------------------------------------------------------
  if flatpak remotes --columns=name 2>/dev/null | st::grep_q -x 'flathub'; then
    st::noop "flathub remote already configured"
  else
    st::run "add the flathub remote" -- \
      flatpak remote-add --if-not-exists flathub "${FLATHUB_URL}"
  fi
  # }}} - Flathub remote ------------------------------------------------------

  # {{{ - Apps ----------------------------------------------------------------
  st::flatpak_install_list flatpak-desktop
  # }}} - Apps ----------------------------------------------------------------

  # {{{ - Dark-theme overrides ------------------------------------------------
  # --user + per-app keeps the blast radius on GTK_DARK_APPS: a global
  # GTK_THEME would degrade every other sandboxed app (cf. the XnViewMP
  # QT_QPA_PLATFORM note in docs/setup/flatpak.md). Adwaita:dark ships in the
  # GTK runtime, so it is always present inside the sandbox.
  local dark_app
  for dark_app in "${GTK_DARK_APPS[@]}"; do
    if ! st::flatpak_installed "${dark_app}"; then
      continue   # not installed here, nothing to theme
    fi
    if flatpak info --show-permissions "${dark_app}" 2>/dev/null \
         | st::grep_q -F 'GTK_THEME=Adwaita:dark'; then
      st::noop "${dark_app} already forced to dark theme"
    else
      st::run "force dark GTK theme for ${dark_app}" -- \
        flatpak override --user --env=GTK_THEME=Adwaita:dark "${dark_app}"
    fi
  done
  # }}} - Dark-theme overrides ------------------------------------------------

  # {{{ - NAS access overrides ------------------------------------------------
  # Only meaningful where the NAS is actually mounted; on a laptop or a fresh
  # box without the shares this is a no-op rather than a lie.
  if [[ ! -d "${NAS_PATH}" ]]; then
    st::noop "${NAS_PATH} not present — skipping NAS flatpak overrides"
    return 0
  fi

  local app
  for app in "${NAS_APPS[@]}"; do
    if ! st::flatpak_installed "${app}"; then
      continue   # not installed here, nothing to grant
    fi
    if flatpak info --show-permissions "${app}" 2>/dev/null \
         | st::grep_q -F "${NAS_PATH}"; then
      st::noop "${app} already has access to ${NAS_PATH}"
    else
      st::run "grant ${app} access to ${NAS_PATH}" -- \
        sudo flatpak override --filesystem="${NAS_PATH}" "${app}"
    fi
  done
  # }}} - NAS access overrides ------------------------------------------------
}
