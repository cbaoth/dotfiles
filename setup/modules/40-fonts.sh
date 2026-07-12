# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 40-fonts: Nerd Fonts (FiraCode, FiraMono) + system monospace default.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Nerd Fonts (FiraCode, FiraMono) + default monospace font"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/fonts.md"

declare -r NERD_FONTS_REPO="https://github.com/ryanoasis/nerd-fonts.git"
declare -r NERD_FONTS_DIR="${HOME}/git/nerd-fonts"
declare -ra NERD_FONTS=(FiraCode FiraMono)

declare -r MONOSPACE_FONT="FiraMono Nerd Font 10"

module_run() {
  # {{{ - Install fonts -------------------------------------------------------
  # fc-list is the source of truth: the fonts may have been installed by any
  # means (apt, manual, a previous run), and we only care that they are there.
  if fc-list 2>/dev/null | st::grep_q -i 'FiraMono Nerd Font'; then
    st::noop "Nerd Fonts already installed (${NERD_FONTS[*]})"
  else
    if [[ -d "${NERD_FONTS_DIR}/.git" ]]; then
      st::noop "nerd-fonts already cloned to ${NERD_FONTS_DIR}"
    else
      st::run "shallow-clone nerd-fonts to ${NERD_FONTS_DIR}" -- \
        git clone --depth 1 "${NERD_FONTS_REPO}" "${NERD_FONTS_DIR}"
    fi

    # The repo is ~8 GB at full depth; --depth 1 plus a targeted install keeps
    # this tolerable. install.sh is idempotent on its own.
    st::run "install Nerd Fonts: ${NERD_FONTS[*]}" -- \
      bash -c "cd '${NERD_FONTS_DIR}' && ./install.sh ${NERD_FONTS[*]}"
  fi
  # }}} - Install fonts -------------------------------------------------------

  # {{{ - System monospace default --------------------------------------------
  if ! st::have_cmd gsettings; then
    st::noop "gsettings not available — skipping monospace font default"
    return 0
  fi

  local current
  current="$(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null | tr -d "'")"
  if [[ "${current}" == "${MONOSPACE_FONT}" ]]; then
    st::noop "monospace font already set to ${MONOSPACE_FONT}"
  else
    st::run "set default monospace font to ${MONOSPACE_FONT}" -- \
      gsettings set org.gnome.desktop.interface monospace-font-name "${MONOSPACE_FONT}"
  fi
  # }}} - System monospace default --------------------------------------------
}
