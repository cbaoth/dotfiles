# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 00-apt-base: Regional mirror, system upgrade, and the base package set.
#
# SC2034: MODULE_* and ST_APT_UPDATED are read by bin/system-setup, which
# sources this file — shellcheck cannot see across that boundary.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Regional apt mirror, system upgrade, base packages"
MODULE_PROFILES=(desktop server wsl)
MODULE_DOC="docs/setup/ubuntu-base.md"

# German Ubuntu mirror — noticeably faster from here than the default.
declare -r APT_MIRROR_FROM="//archive.ubuntu.com"
declare -r APT_MIRROR_TO="//de.archive.ubuntu.com"

module_run() {
  # {{{ - Regional mirror -----------------------------------------------------
  # Ubuntu 24.04+ moved sources to deb822 (.sources); older releases still use
  # sources.list. Rewrite whichever is present.
  local sources_file=""
  local -i force_refresh=0
  if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    sources_file="/etc/apt/sources.list.d/ubuntu.sources"
  elif [[ -f /etc/apt/sources.list ]]; then
    sources_file="/etc/apt/sources.list"
  fi

  if [[ -z "${sources_file}" ]]; then
    st::war "no apt sources file found — skipping mirror change"
  elif grep -q -- "${APT_MIRROR_TO}" "${sources_file}"; then
    st::noop "apt mirror already regional (${APT_MIRROR_TO})"
  elif ! grep -q -- "${APT_MIRROR_FROM}" "${sources_file}"; then
    st::noop "apt mirror is neither default nor regional — left alone"
  else
    st::run "switch apt mirror to ${APT_MIRROR_TO} in ${sources_file}" -- \
      sudo sed -i "s|${APT_MIRROR_FROM}|${APT_MIRROR_TO}|g" "${sources_file}"
    force_refresh=1   # index no longer matches the new mirror — must re-fetch
  fi
  # }}} - Regional mirror -----------------------------------------------------

  # {{{ - Upgrade -------------------------------------------------------------
  # A mirror switch must re-fetch regardless of cache age; otherwise package
  # availability is judged against the old mirror's stale index.
  if (( force_refresh )); then st::apt_update --force; else st::apt_update; fi

  # Always counts as a change: we cannot know if anything is upgradable without
  # asking, and asking is the expensive part anyway.
  local -i upgradable
  upgradable="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ' || true)"
  if (( upgradable == 0 )); then
    st::noop "no packages to upgrade"
  else
    st::run "upgrade ${upgradable} package(s)" -- \
      sudo apt-get upgrade -y --no-install-recommends
  fi
  # }}} - Upgrade -------------------------------------------------------------

  # {{{ - Packages ------------------------------------------------------------
  st::apt_install_list base

  case "$(st::guess_profile)" in
    desktop) st::apt_install_list desktop ;;
    server)  st::apt_install_list server ;;
    wsl)     st::apt_install_list wsl ;;
  esac
  # }}} - Packages ------------------------------------------------------------

  # {{{ - Editor default ------------------------------------------------------
  # Ubuntu ships nano as the system editor; vim everywhere is less surprising.
  if [[ "$(readlink -f /etc/alternatives/editor 2>/dev/null)" == "/usr/bin/vim"* ]]; then
    st::noop "vim is already the default editor"
  elif st::have_cmd vim; then
    st::run "register vim as an editor alternative" -- \
      sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100
    st::run "set vim as the default editor" -- \
      sudo update-alternatives --set editor /usr/bin/vim
  fi
  # }}} - Editor default ------------------------------------------------------
}
