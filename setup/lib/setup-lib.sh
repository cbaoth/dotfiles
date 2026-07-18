# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# setup/lib/setup-lib.sh: Shared helpers for setup modules (st:: namespace).
#
# Sourced by bin/system-setup, which then sources each module in a subshell.
# Deliberately self-contained: system-setup runs on fresh machines where
# ~/lib/commons.sh has not been linked yet (dotfiles-link may not have run).
#
# Every st::* mutation honours ST_DRY_RUN and bumps ST_CHANGED only when it
# actually changes something. A module that reports 0 changes on a re-run is
# the definition of idempotent here.

# {{{ = STATE ================================================================

# Set by bin/system-setup before sourcing a module.
declare -i ST_DRY_RUN="${ST_DRY_RUN:-0}"
declare -i ST_CHANGED=0   # mutations actually applied (or would be, in dry-run)
declare -i ST_SKIPPED=0   # no-ops: already in the desired state

# }}} = STATE ================================================================

# {{{ = LOGGING ==============================================================

# Colours degrade to empty strings on dumb/absent terminals.
if [[ -n "${TERM:-}" && "${TERM}" != *dumb* ]] && command -v tput >/dev/null 2>&1; then
  ST_C_RESET="$(tput sgr0)"
  ST_C_BOLD="$(tput bold)"
  ST_C_DIM="$(tput dim)"
  ST_C_RED="$(tput setaf 1)"
  ST_C_GREEN="$(tput setaf 2)"
  ST_C_YELLOW="$(tput setaf 3)"
  ST_C_BLUE="$(tput setaf 4)"
else
  ST_C_RESET="" ST_C_BOLD="" ST_C_DIM="" ST_C_RED="" ST_C_GREEN="" ST_C_YELLOW="" ST_C_BLUE=""
fi
declare -r ST_C_RESET ST_C_BOLD ST_C_DIM ST_C_RED ST_C_GREEN ST_C_YELLOW ST_C_BLUE

# section header, e.g. a module starting
st::hdr() {
  printf '\n%s==>%s %s%s%s\n' \
    "${ST_C_BLUE}" "${ST_C_RESET}" "${ST_C_BOLD}" "$*" "${ST_C_RESET}"
}

# something is about to change / has changed
st::msg() {
  printf '  %s+%s %s\n' "${ST_C_GREEN}" "${ST_C_RESET}" "$*"
}

# already in the desired state — the quiet, boring, good case
st::skip() {
  printf '  %s.%s %s%s%s\n' \
    "${ST_C_DIM}" "${ST_C_RESET}" "${ST_C_DIM}" "$*" "${ST_C_RESET}"
}

st::war() {
  printf '  %s!%s %s\n' "${ST_C_YELLOW}" "${ST_C_RESET}" "$*" >&2
}

st::err() {
  printf '  %sx%s %s\n' "${ST_C_RED}" "${ST_C_RESET}" "$*" >&2
}

# }}} = LOGGING ==============================================================

# {{{ = EXECUTION ============================================================

# Run a command, unless in dry-run. Counts as a change either way.
# Usage: st::run DESCRIPTION -- CMD..
st::run() {
  local desc="$1"; shift
  [[ "${1:-}" == "--" ]] && shift

  (( ST_CHANGED++ ))
  if (( ST_DRY_RUN )); then
    st::msg "${desc} ${ST_C_DIM}[dry-run: $*]${ST_C_RESET}"
    return 0
  fi
  st::msg "${desc}"
  "$@"
}

# Same, but the command is a shell string (needed for pipes/redirects/heredocs).
# Prefer st::run where possible — this one can't be checked by shellcheck.
st::run_sh() {
  local -r desc="$1"
  local -r cmd="$2"

  (( ST_CHANGED++ ))
  if (( ST_DRY_RUN )); then
    st::msg "${desc} ${ST_C_DIM}[dry-run: ${cmd}]${ST_C_RESET}"
    return 0
  fi
  st::msg "${desc}"
  bash -c "${cmd}"
}

# Record a no-op (already correct). Keeps the change counter honest.
st::noop() {
  (( ST_SKIPPED++ ))
  st::skip "$*"
}

# Grep stdin without the SIGPIPE trap.
#
# `some_cmd | grep -q PAT` is a landmine under `set -o pipefail`: grep -q exits
# the instant it matches, some_cmd gets SIGPIPE (141), and pipefail turns the
# whole pipeline non-zero — so a *successful* match reports failure. It only
# bites on producers big enough not to fit the pipe buffer (fc-list does), which
# makes it a wonderfully intermittent bug. Draining the input avoids it.
# Usage: some_cmd | st::grep_q [GREP_OPTS..] PATTERN
st::grep_q() {
  grep "$@" >/dev/null
}

# }}} = EXECUTION ============================================================

# {{{ = PACKAGE LISTS ========================================================

# Read a setup/packages/<name>.list into the named array.
# Blank lines and #-comments are stripped.
# Usage: st::read_list NAME ARRAY_NAME
#
# The internal array is _st_items, NOT the obvious 'pkgs': callers pass an array
# they declared locally, and a same-named local here would shadow the very
# variable the nameref points at (bash resolves namerefs through dynamic scope).
st::read_list() {
  local -r list_name="$1"
  local -r out_var="$2"
  local -r file="${ST_SETUP_DIR}/packages/${list_name}.list"

  if [[ ! -f "${file}" ]]; then
    st::err "package list not found: ${file}"
    return 1
  fi

  local -a _st_items=()
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"                       # strip comments
    line="${line#"${line%%[![:space:]]*}"}"  # ltrim
    line="${line%"${line##*[![:space:]]}"}"  # rtrim
    [[ -z "${line}" ]] && continue
    _st_items+=("${line}")
  done < "${file}"

  # shellcheck disable=SC2178  # nameref to the caller's array
  local -n _st_out="${out_var}"
  # shellcheck disable=SC2034
  _st_out=("${_st_items[@]}")
}

# }}} = PACKAGE LISTS ========================================================

# {{{ = APT ==================================================================

# Real packages that provide a given virtual package name (empty if not virtual).
st::apt_providers() {
  apt-cache showpkg "$1" 2>/dev/null \
    | sed -n '/^Reverse Provides:/,$p' | tail -n +2 | awk 'NF { print $1 }'
}

# Does apt have a real (installable) record for this name, as opposed to it
# being merely a virtual name that something else Provides?
st::apt_is_real() {
  apt-cache show "$1" 2>/dev/null | st::grep_q '^Filename:'
}

# Is the package installed?
#
# Virtual packages are the trap here. `exiftool` and `p7zip-full` have no real
# package record any more — they are only Provides: of libimage-exiftool-perl
# and 7zip. dpkg-query will therefore NEVER report them installed, so a naive
# check makes apt reinstall them on every single run and the "0 changed on
# re-run" contract silently dies. Worse, p7zip-full still shows as installed on
# machines that upgraded through the transitional package, so the bug only
# appears on a FRESH box — exactly where it is least visible.
st::apt_installed() {
  local -r pkg="$1"

  dpkg-query -W -f='${db:Status-Status}' "${pkg}" 2>/dev/null \
    | st::grep_q -x 'installed' && return 0

  # Not a real installed package — but if it is a virtual name, it counts as
  # installed when any of its providers is.
  local provider
  while read -r provider; do
    [[ -z "${provider}" ]] && continue
    dpkg-query -W -f='${db:Status-Status}' "${provider}" 2>/dev/null \
      | st::grep_q -x 'installed' && return 0
  done < <(st::apt_providers "${pkg}")

  return 1
}

# Could apt install this name at all — real package, or a virtual name with at
# least one provider?
st::apt_available() {
  st::apt_is_real "$1" && return 0
  [[ -n "$(st::apt_providers "$1")" ]]
}

# Install only the packages that are actually missing — this is what makes a
# re-run report zero changes instead of handing everything to apt again.
#
# Unavailable packages are warned about and skipped rather than failing the
# batch: one bad name in a list would otherwise abort the install of every
# other package alongside it, and lists are shared across profiles/releases.
# Usage: st::apt_install PKG..
st::apt_install() {
  local -a missing=() unavailable=()
  local pkg providers
  for pkg in "$@"; do
    # Nudge virtual names towards their real package. st::apt_installed copes
    # with them, but a list that says what it means is worth having.
    if ! st::apt_is_real "${pkg}"; then
      providers="$(st::apt_providers "${pkg}" | tr '\n' ' ')"
      [[ -n "${providers}" ]] \
        && st::war "'${pkg}' is a virtual package — prefer the real name: ${providers% }"
    fi

    if st::apt_installed "${pkg}"; then
      (( ST_SKIPPED++ ))
    elif ! st::apt_available "${pkg}"; then
      unavailable+=("${pkg}")
    else
      missing+=("${pkg}")
    fi
  done

  (( ${#unavailable[@]} > 0 )) \
    && st::war "not available in apt, skipped: ${unavailable[*]}"

  if (( ${#missing[@]} == 0 )); then
    st::skip "all ${#} apt packages already installed"
    return 0
  fi

  st::run "install ${#missing[@]} apt package(s): ${missing[*]}" -- \
    sudo apt-get install -y --no-install-recommends "${missing[@]}"
}

# Install every package from a setup/packages/<name>.list
st::apt_install_list() {
  local -a pkgs=()
  st::read_list "$1" pkgs || return 1
  (( ${#pkgs[@]} == 0 )) && { st::skip "package list '$1' is empty"; return 0; }
  st::apt_install "${pkgs[@]}"
}

# Refresh the apt cache: once per run, and only if it is over an hour stale.
#
# Deliberately NOT counted as a change — refreshing a cache mutates nothing on
# the system, and counting it would mean every run reports at least one change,
# destroying the "a re-run reports 0 changed" contract that the whole thing
# leans on.
declare -i ST_APT_UPDATED=0
declare -ri ST_APT_MAX_AGE=3600
# --force refreshes even on a fresh cache: use it right after changing the apt
# sources (a new mirror), where the on-disk index no longer matches reality and
# the age heuristic would wrongly declare it fresh.
st::apt_update() {
  local -i force=0
  [[ "${1:-}" == "--force" ]] && force=1

  (( ST_APT_UPDATED && ! force )) && return 0
  ST_APT_UPDATED=1

  local -r stamp="/var/lib/apt/periodic/update-success-stamp"
  local -r lists="/var/lib/apt/lists"
  local -i age=999999
  local -r newest="${stamp}"
  if [[ -e "${newest}" ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "${newest}" 2>/dev/null || echo 0) ))
  elif [[ -d "${lists}" ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "${lists}" 2>/dev/null || echo 0) ))
  fi

  if (( ! force && age < ST_APT_MAX_AGE )); then
    st::skip "apt cache is fresh (${age}s old)"
    return 0
  fi

  local -r why="$( (( force )) && printf 'forced after sources change' \
                                || printf '%ss stale' "${age}" )"
  if (( ST_DRY_RUN )); then
    st::skip "apt cache ${why} [dry-run: would apt-get update]"
    return 0
  fi
  st::skip "refreshing apt cache (${why})"
  sudo apt-get update
}

# }}} = APT ==================================================================

# {{{ = FLATPAK ==============================================================

st::flatpak_installed() {
  flatpak info "$1" >/dev/null 2>&1
}

st::flatpak_install() {
  local -a missing=()
  local app
  for app in "$@"; do
    if st::flatpak_installed "${app}"; then
      (( ST_SKIPPED++ ))
    else
      missing+=("${app}")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    st::skip "all ${#} flatpak app(s) already installed"
    return 0
  fi

  st::run "install ${#missing[@]} flatpak app(s): ${missing[*]}" -- \
    flatpak install -y flathub "${missing[@]}"
}

st::flatpak_install_list() {
  local -a apps=()
  st::read_list "$1" apps || return 1
  (( ${#apps[@]} == 0 )) && { st::skip "flatpak list '$1' is empty"; return 0; }
  st::flatpak_install "${apps[@]}"
}

# }}} = FLATPAK ==============================================================

# {{{ = FILES ================================================================

# Ensure LINE exists in FILE (appending if absent). Root-owned files get sudo.
# Usage: st::line_in_file FILE LINE
st::line_in_file() {
  local -r file="$1"
  local -r line="$2"

  if [[ -f "${file}" ]] && grep -qxF -- "${line}" "${file}" 2>/dev/null; then
    st::noop "already present in ${file}: ${line}"
    return 0
  fi

  st::run_sh "append to ${file}: ${line}" \
    "printf '%s\n' $(printf '%q' "${line}") | sudo tee -a $(printf '%q' "${file}") >/dev/null"
}

# Write CONTENT to FILE only if it differs. Avoids pointless churn on re-runs.
# Usage: st::file_content FILE CONTENT [MODE]
st::file_content() {
  local -r file="$1"
  local -r content="$2"
  local -r mode="${3:-}"

  if [[ -f "${file}" ]] && [[ "$(cat "${file}" 2>/dev/null)" == "${content}" ]]; then
    st::noop "already up to date: ${file}"
    return 0
  fi

  st::run_sh "write ${file}" \
    "printf '%s\n' $(printf '%q' "${content}") | sudo tee $(printf '%q' "${file}") >/dev/null"
  [[ -n "${mode}" ]] && st::run "chmod ${mode} ${file}" -- sudo chmod "${mode}" "${file}"
  return 0
}

# }}} = FILES ================================================================

# {{{ = PREDICATES ===========================================================

st::have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Are we inside WSL?
st::is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

# Is a graphical session / desktop profile plausible here?
st::is_desktop() {
  [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || st::have_cmd gnome-shell
}

# Guess the profile for --profile auto
st::guess_profile() {
  if st::is_wsl; then
    printf 'wsl'
  elif st::is_desktop; then
    printf 'desktop'
  else
    printf 'server'
  fi
}

# }}} = PREDICATES ===========================================================
