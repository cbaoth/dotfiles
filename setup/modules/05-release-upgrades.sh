# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 05-release-upgrades: which Ubuntu releases do-release-upgrade offers here.
#
# SC2034: MODULE_* are read by bin/system-setup, which sources this file, and
# the linter cannot see across that boundary.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Release-upgrade channel (Prompt=) by profile"
MODULE_PROFILES=(desktop server wsl)
MODULE_DOC="docs/setup/release-upgrades.md"

declare -r RELUP_FILE="/etc/update-manager/release-upgrades"

# The release channel each profile tracks.
#
#   normal - every release, interim ones included (9 months of support each)
#   lts    - LTS releases only (5 years, plus ESM via Ubuntu Pro)
#
# Desktops take the interim releases: current kernels and drivers for recent
# hardware are worth the 9-month cadence, and breakage there happens under no
# time pressure. Servers stay on LTS — services down while you debug an upgrade
# is the thing being avoided, and containers have removed the old reason to
# chase runtime versions on a server.
#
# WSL is grouped with the servers on purpose: it is a work machine, where an
# interim release's churn is the least welcome. Flip it to 'normal' if that
# stops being true.
declare -rA RELUP_PROMPT_BY_PROFILE=(
  [desktop]="normal"
  [server]="lts"
  [wsl]="lts"
)

# The Prompt= value currently in effect, empty if the key is absent. Only a real
# setting may match: the shipped file documents every valid value in a comment
# block directly above it, so anchoring on '#'-free lines is the whole point.
_relup_current_prompt() {
  sed -n 's/^[[:space:]]*Prompt[[:space:]]*=[[:space:]]*\([^[:space:]#]*\).*/\1/p' \
    "${RELUP_FILE}" 2>/dev/null | tail -n1
}

module_run() {
  if [[ ! -f "${RELUP_FILE}" ]]; then
    st::war "${RELUP_FILE} not found — is ubuntu-release-upgrader-core installed?"
    return 0
  fi

  local profile
  profile="$(st::profile)"
  local -r profile

  local -r want="${RELUP_PROMPT_BY_PROFILE[${profile}]:-}"
  if [[ -z "${want}" ]]; then
    st::war "no release channel defined for profile '${profile}' — ${RELUP_FILE} left alone"
    return 0
  fi

  local current
  current="$(_relup_current_prompt)"
  local -r current

  if [[ "${current}" == "${want}" ]]; then
    st::noop "release channel already Prompt=${want} (profile: ${profile})"
    return 0
  fi

  # Why this is managed rather than set once by hand: a release upgrade rewrites
  # this file. puppet went into the 25.10 -> 26.04 upgrade on 'normal' and came
  # out on 'lts' (2026-09-28), which would have silently parked a desktop on the
  # LTS channel. Unmanaged, the value drifts on exactly the event that matters.
  if [[ -z "${current}" ]]; then
    st::line_in_file "${RELUP_FILE}" "Prompt=${want}"
  else
    st::run "release channel: Prompt=${current} -> ${want} (profile: ${profile})" -- \
      sudo sed -i "s/^[[:space:]]*Prompt[[:space:]]*=.*/Prompt=${want}/" "${RELUP_FILE}"
  fi
}
