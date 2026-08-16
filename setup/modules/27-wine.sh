# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 27-wine: Wine from the WineHQ apt repo, plus PE file inspection tools.
#
# Wine comes from WineHQ, NOT from Ubuntu's archive — Ubuntu's `wine` package
# trails upstream by a year or more and the two conflict. See
# docs/setup/wine.md for the (deliberately manual) cleanup if Ubuntu's wine is
# already installed.
#
# The repo suite is the distro codename, so the sources filename changes on a
# release upgrade; stale files for other codenames are cleaned up here, because
# leaving one behind breaks every subsequent `apt update`.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Wine from the WineHQ apt repo, plus PE inspection tools (readpe)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/wine.md"

# Release branch to install: stable | staging | devel. The repo carries all
# three; switching means changing this and removing the old winehq-* package
# by hand (they conflict).
declare -r WINE_BRANCH="stable"

# Overridable so the stale-cleanup logic below can be exercised against a temp
# directory instead of the real /etc — that path only ever runs on a release
# upgrade, which is precisely when an untested bug would be most expensive.
declare -r WINE_SOURCES_DIR="${WINE_SOURCES_DIR:-/etc/apt/sources.list.d}"

declare -r WINE_KEY_URL="https://dl.winehq.org/wine-builds/winehq.key"
declare -r WINE_KEY_FILE="/etc/apt/keyrings/winehq-archive.key"
declare -r WINE_KEY_FP="D43F640145369C51D786DDEA76F1A20FF987672F"

# Ubuntu's own wine packages. WineHQ ships winehq-* / wine-* and never these,
# so any of them being installed means the two stacks are fighting.
declare -ra WINE_DISTRO_PKGS=(wine wine32 wine64 libwine)

# {{{ = Helpers =============================================================

# Distro codename, e.g. 'questing'. lsb_release is not guaranteed on a fresh
# minimal install, so os-release is the fallback rather than the other way.
wine_codename() {
  local codename=""

  if st::have_cmd lsb_release; then
    codename="$(lsb_release -sc 2>/dev/null)"
  fi
  if [[ -z "${codename}" && -r /etc/os-release ]]; then
    # shellcheck disable=SC1091  # os-release is data, not a tracked source file
    codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
  fi

  printf '%s' "${codename}"
}

# WineHQ publishes separate trees for 'ubuntu' and 'debian'; derive which from
# ID_LIKE so Mint/Pop and friends land in the right one.
wine_distro() {
  local id="" id_like=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    # shellcheck disable=SC1091
    id_like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
  fi

  case "${id} ${id_like}" in
    *ubuntu*) printf 'ubuntu' ;;
    *debian*) printf 'debian' ;;
    *)        printf '' ;;
  esac
}

# Does the repo actually publish this suite? WineHQ supports a fixed set of
# releases and lags behind Ubuntu's interim ones by weeks. Writing a sources
# file for a suite that does not exist breaks `apt update` system-wide, which
# is a far worse outcome than not having wine, so this is checked before the
# file is written rather than discovered afterwards.
wine_repo_has_suite() {
  local -r base_url="$1" suite="$2"
  # No -S: a missing suite is an expected outcome here, and curl's raw 404
  # would print ahead of the warning this function exists to produce.
  curl -fsL --max-time 15 -o /dev/null "${base_url}/dists/${suite}/Release"
}

# Remove winehq-<other-codename>.sources left behind by a release upgrade.
wine_clean_stale_sources() {
  local -r keep="$1"
  local file name

  for file in "${WINE_SOURCES_DIR}"/winehq-*.sources; do
    [[ -f "${file}" ]] || continue
    name="$(basename "${file}" .sources)"
    [[ "${name}" == "winehq-${keep}" ]] && continue
    st::run "remove stale WineHQ sources: ${name}" -- sudo rm -f "${file}"
  done
}

# Warn (never act) if Ubuntu's wine is installed alongside WineHQ's.
#
# st::apt_installed is deliberately NOT used here. It resolves virtual names
# through Provides, and winehq-stable itself declares `Provides: wine, wine64`
# — so it reports Ubuntu's wine as installed on a machine where the WineHQ
# setup is perfectly correct. Only a real dpkg entry counts as a conflict.
wine_warn_distro_packages() {
  local -a found=()
  local pkg

  for pkg in "${WINE_DISTRO_PKGS[@]}"; do
    dpkg-query -W -f='${db:Status-Status}' "${pkg}" 2>/dev/null \
      | st::grep_q -x 'installed' && found+=("${pkg}")
  done

  (( ${#found[@]} == 0 )) && return 0

  st::war "Ubuntu's own wine packages are installed: ${found[*]}"
  st::war "they conflict with WineHQ — see docs/setup/wine.md for the manual purge"
}

# }}} = Helpers =============================================================

# {{{ = Repo ================================================================

wine_setup_key() {
  if [[ -f "${WINE_KEY_FILE}" ]]; then
    st::noop "signing key already present: ${WINE_KEY_FILE}"
  else
    # Dearmored on purpose: upstream serves ASCII armor, and apt only accepts
    # that under a .asc name. The sources file (upstream's own) points at
    # .key, so the binary form is the one that actually verifies.
    st::run "install WineHQ signing key" -- \
      sudo sh -c "install -d -m 0755 '$(dirname "${WINE_KEY_FILE}")' && \
        curl -fsSL '${WINE_KEY_URL}' | gpg --dearmor -o '${WINE_KEY_FILE}'"
  fi

  # Fingerprint check is advisory — a mismatch is worth shouting about but is
  # not this module's call to resolve.
  if [[ -f "${WINE_KEY_FILE}" ]] && ! (( ST_DRY_RUN )); then
    local fp
    fp="$(gpg -n -q --import --import-options import-show "${WINE_KEY_FILE}" 2>/dev/null \
          | awk '/^pub/{getline; gsub(/^ +| +$/,""); print; exit}')"
    if [[ -n "${fp}" && "${fp}" != "${WINE_KEY_FP}" ]]; then
      st::war "WineHQ key fingerprint mismatch! Expected ${WINE_KEY_FP}, got: ${fp}"
    fi
  fi
}

wine_setup_sources() {
  local -r base_url="$1" codename="$2"
  local -r sources_file="${WINE_SOURCES_DIR}/winehq-${codename}.sources"
  local -i changed_before=${ST_CHANGED}

  # Byte-identical to the file upstream serves at
  # <base_url>/dists/<codename>/winehq-<codename>.sources, kept inline so the
  # module does not depend on a wget of a file into a system directory.
  local sources_content
  read -r -d '' sources_content <<EOF || true
Types: deb
URIs: ${base_url}
Suites: ${codename}
Components: main
Architectures: amd64
Signed-By: ${WINE_KEY_FILE}
EOF

  if [[ ! -f "${sources_file}" ]] && ! wine_repo_has_suite "${base_url}" "${codename}"; then
    st::war "WineHQ publishes no repo for '${codename}' yet — skipping wine setup"
    return 1
  fi

  st::file_content "${sources_file}" "${sources_content}"
  wine_clean_stale_sources "${codename}"

  (( ST_CHANGED > changed_before )) && st::apt_update --force
  return 0
}

# }}} = Repo ================================================================

module_run() {
  local codename distro base_url

  codename="$(wine_codename)"
  distro="$(wine_distro)"

  if [[ -z "${codename}" || -z "${distro}" ]]; then
    st::war "not a Debian/Ubuntu system (codename='${codename}', distro='${distro}') — skipping"
    return 0
  fi
  base_url="https://dl.winehq.org/wine-builds/${distro}"

  # i386 for the 32-bit libraries. Note that this is NOT about wine itself any
  # more: since Wine 10's new WoW64 the questing repo is amd64-only, so the
  # winehq packages need no i386 at all. It stays because older releases DO
  # ship wine-*-i386, and because 32-bit GPU/driver libs are what many Windows
  # games actually pull in. Cost is one extra index per apt update.
  st::dpkg_add_architecture i386

  wine_setup_key
  wine_setup_sources "${base_url}" "${codename}" || return 0

  # --install-recommends is upstream's documented requirement, not a nicety:
  # without it wine comes up missing gnutls (no HTTPS), SDL2, and fonts.
  #
  # winetricks rides along for the same reason — its Recommends ARE the tool:
  # cabextract (unpacking the Windows CABs that every DLL verb installs from)
  # and zenity (its entire GUI). It Depends on `wine`, which winehq-stable
  # Provides, so this does not drag Ubuntu's wine back in.
  st::apt_install_recommends "winehq-${WINE_BRANCH}" winetricks

  wine_warn_distro_packages

  # PE inspection: peres/readpe read version and resource info out of Windows
  # .exe/.dll files. The package is 'readpe' — `pev` is only a transitional
  # shim for it now, and naming the shim is how a list rots quietly.
  # Aliases: exe-version / exe-info / exe-headers (lib/aliases-linux.sh).
  st::apt_install readpe
}
