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

# One release archive per family (~3 MB each), pinned and checksummed, instead of
# cloning the whole nerd-fonts repo (~8 GB). Same version as 41-console.
# Bumping: new tag + each archive's line from the release's SHA-256.txt.
declare -r NF_VERSION="v3.5.1"
declare -rA NF_SHA256=(
  [FiraCode]="68e3bd6164864b8b514605bc34e3a87ac401c8c48682fcce6478c70263340207"
  [FiraMono]="e3112075b65d9a900ef6ca562c30f1b5eb1d1a928e97de7469962ac8c45e93d6"
)
declare -r NF_URL_BASE="https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}"
declare -r NF_DIR="${HOME}/.local/share/fonts/NerdFonts"

declare -r MONOSPACE_FONT="FiraMono Nerd Font 10"

module_run() {
  # {{{ - Install fonts -------------------------------------------------------
  # fc-list is the source of truth: the fonts may have been installed by any
  # means (a previous run, manual), and we only care that they are there.
  # The pattern is the plain family: 41-console's system-wide "... Nerd Font
  # Mono" must not make this look installed.
  local family
  for family in FiraCode FiraMono; do
    if fc-list : family 2>/dev/null | st::grep_q -E "^${family} Nerd Font(,|\$)"; then
      st::noop "${family} Nerd Font already installed"
    elif ! st::have_cmd curl; then
      st::war "curl not found — skipping ${family} (run '00-apt-base' first)"
    else
      # Skip *Propo* (proportional icons, useless as a monospace font).
      # pipefail + -e: a failed download or checksum must not install anything.
      st::run_sh "install ${family} Nerd Font ${NF_VERSION} to ${NF_DIR}/${family}" "
        set -euo pipefail
        tmp=\"\$(mktemp -d)\"
        trap 'rm -rf \"\${tmp}\"' EXIT
        curl -fsSL -o \"\${tmp}/${family}.tar.xz\" '${NF_URL_BASE}/${family}.tar.xz'
        printf '%s  %s\n' '${NF_SHA256[${family}]}' \"\${tmp}/${family}.tar.xz\" | sha256sum -c --quiet -
        mkdir -p '${NF_DIR}/${family}'
        tar -xJf \"\${tmp}/${family}.tar.xz\" -C '${NF_DIR}/${family}' \\
          --exclude='*Propo*' --wildcards '*.[ot]tf' LICENSE
        fc-cache -f '${NF_DIR}/${family}'"
    fi
  done
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
