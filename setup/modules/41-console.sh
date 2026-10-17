# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 41-console: kmscon on tty3-6 (Nerd Font, truecolor), stock getty on tty1-2.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="kmscon with FiraMono Nerd Font on tty3-6, stock getty on tty1-2"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/console.md"

# {{{ - Font -----------------------------------------------------------------
# One release archive (~3 MB), pinned and checksummed, rather than 40-fonts'
# clone of the whole nerd-fonts repo: kmscon runs as root, so the font must be
# installed system-wide, and ~/.local/share/fonts is invisible to it.
# Bumping: new tag + the archive's line from the release's SHA-256.txt.
declare -r NF_VERSION="v3.5.1"
declare -r NF_ARCHIVE="FiraMono.tar.xz"
declare -r NF_SHA256="e3112075b65d9a900ef6ca562c30f1b5eb1d1a928e97de7469962ac8c45e93d6"
declare -r NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/${NF_ARCHIVE}"
declare -r NF_DIR="/usr/local/share/fonts/nerd-fonts/FiraMono"
declare -r NF_STAMP="${NF_DIR}/.version"
# The "Mono" variant: icons squeezed into one cell. The plain variant draws them
# wider, which overlaps the next cell on a strict grid like kmscon's.
declare -ra NF_FILES=(FiraMonoNerdFontMono-Regular.otf
                      FiraMonoNerdFontMono-Medium.otf
                      FiraMonoNerdFontMono-Bold.otf)
# }}} - Font -----------------------------------------------------------------

# {{{ - kmscon ---------------------------------------------------------------
declare -r KMSCON_CONF="/etc/kmscon/kmscon.conf"
declare -r KMSCON_FONT_SIZE_DEFAULT=14
# Per-host overrides, e.g. [saito]=12. Ctrl+Shift+Plus/Minus zooms at runtime.
declare -rA KMSCON_FONT_SIZE_BY_HOST=()
# term: kmscon's built-in default is "linux", which would make the TTY prompt
# fallback (TERM=linux, see ~/.zshrc and ~/.tmux.conf) fire inside kmscon too.
# xterm-256color is also the one name every ssh target has terminfo for.
declare -r KMSCON_TERM="xterm-256color"
# }}} - kmscon ---------------------------------------------------------------

# {{{ - VT layout ------------------------------------------------------------
# tty1 is where sway is started from (bin/sway-start), and a compositor on a
# kmscon VT fights kmscon for DRM master. tty2 stays stock as a safety net for
# the case kmscon itself misbehaves (its unit only falls back to getty when
# kmscon fails to *start*, not when it starts and renders garbage).
declare -ra GETTY_VTS=(tty1 tty2)
declare -ra KMSCON_VTS=(tty3 tty4 tty5 tty6)

# The kmscon package enables itself on tty1 and aliases autovt@ to kmscon, so
# logind would spawn it on every VT on demand. Instead every VT is enabled
# statically and logind spawns nothing: an on-demand getty on a kmscon VT (or
# the reverse) would stop the running one via the units' Conflicts=.
declare -r LOGIND_DROPIN="/etc/systemd/logind.conf.d/60-console-vts.conf"
declare -r LOGIND_DROPIN_CONTENT="# Managed by dotfiles: setup/modules/41-console.sh
# Docs: docs/setup/console.md
#
# Every VT's login unit is enabled statically (getty on tty1-2, kmscon on
# tty3-6), so logind must not spawn autovt@ units on VT switch: those would
# conflict with, and stop, whatever already runs on that VT.
[Login]
NAutoVTs=0
ReserveVT=0"
# }}} - VT layout ------------------------------------------------------------

# Set KEY=VALUE in kmscon.conf: replace an active KEY= line, else append.
# The package's file is all comments, so this leaves upstream's text intact.
_console::conf_set() {
  local -r key="$1"
  local -r value="$2"

  if grep -qxF -- "${key}=${value}" "${KMSCON_CONF}" 2>/dev/null; then
    st::noop "${KMSCON_CONF}: ${key}=${value}"
  elif grep -qE "^${key}=" "${KMSCON_CONF}" 2>/dev/null; then
    st::run "set ${key}=${value} in ${KMSCON_CONF}" -- \
      sudo sed -i "s|^${key}=.*|${key}=${value}|" "${KMSCON_CONF}"
  else
    st::line_in_file "${KMSCON_CONF}" "${key}=${value}"
  fi
}

# Ensure UNIT is (state=enabled) or is not (state=disabled) statically enabled.
# Never --now: starting kmscon on a VT stops the getty there (Conflicts=), and
# with it any session logged in on that VT. The layout applies at next boot.
_console::unit_state() {
  local -r unit="$1"
  local -r want="$2"
  local is
  is="$(systemctl is-enabled "${unit}" 2>/dev/null)" || true

  if [[ "${want}" == "enabled" && "${is}" == "enabled" ]] \
     || [[ "${want}" == "disabled" && "${is}" != "enabled" ]]; then
    st::noop "${unit} ${want}"
  elif [[ "${want}" == "enabled" ]]; then
    st::run "enable ${unit} (from next boot)" -- sudo systemctl enable "${unit}"
  else
    st::run "disable ${unit}" -- sudo systemctl disable "${unit}"
  fi
}

module_run() {
  # A VM (the vserver) or container has no console anyone sits in front of.
  local virt
  if virt="$(systemd-detect-virt 2>/dev/null)"; then
    st::noop "virtualized (${virt}) — no physical console, skipping"
    return 0
  fi

  if ! st::apt_available kmscon; then
    st::war "kmscon not available in apt on this release — skipping"
    return 0
  fi
  st::apt_install kmscon

  # {{{ - Font ----------------------------------------------------------------
  local f installed=true
  [[ "$(cat "${NF_STAMP}" 2>/dev/null)" == "${NF_VERSION}" ]] || installed=false
  for f in "${NF_FILES[@]}"; do
    [[ -f "${NF_DIR}/${f}" ]] || installed=false
  done

  if ${installed}; then
    st::noop "FiraMono Nerd Font Mono ${NF_VERSION} installed in ${NF_DIR}"
  elif ! st::have_cmd curl; then
    st::war "curl not found — skipping font (run '00-apt-base' first, or install curl)"
  else
    # pipefail + -e: a failed download or checksum must not install anything.
    st::run_sh "install FiraMono Nerd Font Mono ${NF_VERSION} to ${NF_DIR}" "
      set -euo pipefail
      tmp=\"\$(mktemp -d)\"
      trap 'rm -rf \"\${tmp}\"' EXIT
      curl -fsSL -o \"\${tmp}/${NF_ARCHIVE}\" '${NF_URL}'
      printf '%s  %s\n' '${NF_SHA256}' \"\${tmp}/${NF_ARCHIVE}\" | sha256sum -c --quiet -
      tar -xJf \"\${tmp}/${NF_ARCHIVE}\" -C \"\${tmp}\" ${NF_FILES[*]} LICENSE
      sudo install -d -m 0755 '${NF_DIR}'
      cd \"\${tmp}\" && sudo install -m 0644 ${NF_FILES[*]} LICENSE '${NF_DIR}/'
      printf '%s\n' '${NF_VERSION}' | sudo tee '${NF_STAMP}' >/dev/null
      sudo fc-cache -f '${NF_DIR}'"
  fi
  # }}} - Font ----------------------------------------------------------------

  # {{{ - kmscon.conf ---------------------------------------------------------
  # Read at kmscon start: each console picks changes up on its next login
  # prompt. Restarting the units would kill sessions on them, so we don't.
  local -r host="$(hostname -s)"
  _console::conf_set font-name "FiraMono Nerd Font Mono"
  _console::conf_set font-size "${KMSCON_FONT_SIZE_BY_HOST[${host}]:-${KMSCON_FONT_SIZE_DEFAULT}}"
  _console::conf_set term "${KMSCON_TERM}"
  # }}} - kmscon.conf ---------------------------------------------------------

  # {{{ - logind: no on-demand VTs ----------------------------------------------
  local -r dropin_dir="${LOGIND_DROPIN%/*}"
  if [[ -d "${dropin_dir}" ]]; then
    st::noop "drop-in directory exists: ${dropin_dir}"
  else
    st::run "create ${dropin_dir}" -- sudo mkdir -p "${dropin_dir}"
  fi

  local -i before="${ST_CHANGED:-0}"
  st::file_content "${LOGIND_DROPIN}" "${LOGIND_DROPIN_CONTENT}" 644
  if (( "${ST_CHANGED:-0}" > before )); then
    # reload, never restart: restarting systemd-logind tears down the session.
    st::run "reload systemd-logind" -- sudo systemctl reload systemd-logind
  else
    st::noop "logind VT policy already applied"
  fi
  # }}} - logind: no on-demand VTs ----------------------------------------------

  # {{{ - VT layout -------------------------------------------------------------
  before="${ST_CHANGED:-0}"
  local vt
  for vt in "${GETTY_VTS[@]}"; do
    _console::unit_state "kmsconvt@${vt}.service" disabled
    _console::unit_state "getty@${vt}.service" enabled
  done
  for vt in "${KMSCON_VTS[@]}"; do
    _console::unit_state "getty@${vt}.service" disabled
    _console::unit_state "kmsconvt@${vt}.service" enabled
  done

  # The package's template alias (autovt@ -> kmsconvt@). Unused with
  # NAutoVTs=0, but removed so autovt@ means getty again, as shipped by systemd.
  # In a dry run the disable above has not happened, so this may report it too.
  local -r autovt_alias="/etc/systemd/system/autovt@.service"
  if [[ -L "${autovt_alias}" && "$(readlink "${autovt_alias}")" == *kmsconvt@.service ]]; then
    st::run "remove kmscon alias ${autovt_alias}" -- sudo rm "${autovt_alias}"
    st::run "reload systemd units" -- sudo systemctl daemon-reload
  else
    st::noop "autovt@.service is not aliased to kmscon"
  fi

  (( "${ST_CHANGED:-0}" > before )) \
    && st::war "VT layout changed: takes effect at next boot (running consoles are left alone)"
  # }}} - VT layout -------------------------------------------------------------
  return 0
}
