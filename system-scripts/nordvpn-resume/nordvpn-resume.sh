#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# nordvpn-resume: Repair a NordVPN tunnel that comes back broken after resume.
#
# nordvpnd reconnects on its own about a second after wifi comes back, and the
# GUI then reports "Connected", but DNS through the tunnel is broken (thousands
# of resolved DNSSEC failures a minute) until a fresh `nordvpn connect`. This
# script waits for the physical link and nordvpnd's own reconnect, checks the
# tunnel actually works, and reconnects only if it does not.
#
# Run by nordvpn-resume.service after every resume. Background: README.adoc.

set -o errexit
set -o pipefail
set -o nounset
set -o errtrace
(( ${DEBUG_LVL:-0} >= 2 )) && set -o xtrace

# The nordvpn CLI dies with "cannot get user home dir" without $HOME, and
# systemd sets none for a service without User=.
export HOME="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"

# Never die silently: errexit alone left an empty journal on the first run.
trap 'p_err "aborted: line ${LINENO}: ${BASH_COMMAND} (exit $?)"' ERR

# {{{ = CONSTANTS =============================================================

# Fallback when `nordvpn status` names no country (it normally does, and the
# reconnect reuses it, so this rarely matters).
declare -r DEFAULT_SERVER="luxembourg"

declare -ri LINK_TIMEOUT=120      # s to wait for a physical default route
declare -ri SETTLE_TIMEOUT=30     # s to wait for nordvpnd to report Connected
declare -ri CHECK_TRIES=4         # health checks before declaring it broken
declare -ri CHECK_INTERVAL=5      # s between health checks
declare -ri MAX_RECONNECTS=3

# Names that resolve cleanly via Nord's DNS when the tunnel is healthy. Avoid
# nordvpn.com: it fails DNSSEC validation there even when everything works.
declare -ra PROBE_NAMES=(github.com wikipedia.org debian.org kernel.org)
declare -ri PROBE_MIN_OK=3
declare -r PROBE_URL="https://www.cloudflare.com/cdn-cgi/trace"

# }}} = CONSTANTS =============================================================

# {{{ = FUNCTIONS =============================================================

p_msg() { printf '%s\n' "$*"; }
p_err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: nordvpn-resume [--check|--force|--help]

  (none)    Wait for link and nordvpnd, reconnect only if the tunnel is broken
  --check   Report tunnel health and exit (0 healthy, 1 broken); no changes
  --force   Wait for link, then reconnect unconditionally
EOF
}

vpn_field() {
  local out
  if ! out="$(nordvpn status 2>&1)"; then
    p_err "nordvpn status failed: ${out}"
    return 0
  fi
  sed -n "s/^${1}: //p" <<<"${out}" | head -n1
}

wait_for() {
  local -i timeout="$1" elapsed=0
  shift
  until "$@"; do
    (( elapsed >= timeout )) && return 1
    sleep 2
    elapsed+=2
  done
}

# A default route in the main table on a non-tunnel device. nordvpnd routes
# via policy rules, so the physical default route is unaffected by the VPN.
has_physical_route() {
  ip -4 route show default | grep -qvE 'dev (qtun|nordlynx|nordtun|tun[0-9]+)'
}

vpn_connected() { [[ "$(vpn_field Status)" == "Connected" ]]; }

tunnel_healthy() {
  local name
  local -i ok=0
  for name in "${PROBE_NAMES[@]}"; do
    timeout 5 resolvectl query --cache=no --legend=no "${name}" &>/dev/null \
      && ok+=1
  done
  if (( ok < PROBE_MIN_OK )); then
    p_msg "health: DNS ${ok}/${#PROBE_NAMES[@]} names resolved"
    return 1
  fi
  if ! curl -sS -m 8 -o /dev/null "${PROBE_URL}" 2>/dev/null; then
    p_msg "health: DNS ok, but HTTPS probe failed"
    return 1
  fi
  p_msg "health: ok (DNS ${ok}/${#PROBE_NAMES[@]}, HTTPS ok)"
}

tunnel_healthy_retry() {
  local -i i
  for (( i = 1; i <= CHECK_TRIES; i++ )); do
    tunnel_healthy && return 0
    (( i < CHECK_TRIES )) && sleep "${CHECK_INTERVAL}"
  done
  return 1
}

reconnect() {
  local target
  target="$(vpn_field Country)"
  target="${target:-${DEFAULT_SERVER}}"
  p_msg "reconnecting: nordvpn connect ${target}"
  nordvpn connect "${target}" || p_err "nordvpn connect exited $?"
  wait_for "${SETTLE_TIMEOUT}" vpn_connected \
    || p_err "nordvpnd not Connected ${SETTLE_TIMEOUT}s after reconnect"
}

# }}} = FUNCTIONS =============================================================

# {{{ = MAIN ==================================================================

main() {
  local mode="auto" status
  local -i attempt

  case "${1:-}" in
    "")         ;;
    --check)    mode="check" ;;
    --force)    mode="force" ;;
    -h|--help)  usage; return 0 ;;
    *)          usage >&2; return 2 ;;
  esac

  if [[ "${mode}" == "check" ]]; then
    p_msg "status: $(vpn_field Status) ($(vpn_field Hostname))"
    if tunnel_healthy; then return 0; fi
    return 1
  fi

  # Disconnected after resume means it was off before sleep: leave it off.
  # (nordvpnd keeps Connected/Connecting across sleep when it was on.)
  status="$(vpn_field Status)"
  if [[ "${status}" == "Disconnected" && "${mode}" != "force" ]]; then
    p_msg "VPN was disconnected before sleep; nothing to do"
    return 0
  fi

  p_msg "waiting for a physical default route (max ${LINK_TIMEOUT}s)"
  if ! wait_for "${LINK_TIMEOUT}" has_physical_route; then
    p_err "no physical default route after ${LINK_TIMEOUT}s; giving up"
    return 1
  fi
  p_msg "link up: $(ip -4 route show default | head -n1)"

  if [[ "${mode}" == "auto" ]]; then
    p_msg "waiting for nordvpnd's own reconnect (max ${SETTLE_TIMEOUT}s)"
    wait_for "${SETTLE_TIMEOUT}" vpn_connected \
      || p_msg "nordvpnd still '$(vpn_field Status)'"
    if vpn_connected && tunnel_healthy_retry; then
      p_msg "tunnel healthy without intervention ($(vpn_field Hostname))"
      return 0
    fi
  fi

  for (( attempt = 1; attempt <= MAX_RECONNECTS; attempt++ )); do
    p_msg "attempt ${attempt}/${MAX_RECONNECTS}"
    reconnect
    if tunnel_healthy_retry; then
      p_msg "tunnel healthy after reconnect ($(vpn_field Hostname))"
      return 0
    fi
  done

  p_err "tunnel still broken after ${MAX_RECONNECTS} reconnects"
  return 1
}

main "$@" || exit $?

# }}} = MAIN ==================================================================
