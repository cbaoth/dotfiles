#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Install or update the nordvpn-resume script and systemd unit, and remove the
# old system-sleep hook it replaces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_SOURCE="${SCRIPT_DIR}/nordvpn-resume.sh"
SCRIPT_TARGET="/opt/bin/nordvpn-resume.sh"

UNIT_SOURCE="${SCRIPT_DIR}/nordvpn-resume.service"
UNIT_TARGET="/etc/systemd/system/nordvpn-resume.service"

# Never ran: systemd only scans /usr/lib/systemd/system-sleep/ (see README).
OLD_HOOK="/etc/systemd/system-sleep/nordvpn-reconnect"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: This script must be run as root.${NC}" >&2
  exit 1
fi

for f in "${SCRIPT_SOURCE}" "${UNIT_SOURCE}"; do
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: Source file not found: $f${NC}" >&2
    exit 1
  fi
done

if ! command -v nordvpn >/dev/null 2>&1; then
  echo -e "${RED}Error: nordvpn CLI not found.${NC}" >&2
  exit 1
fi

# {{{ - Script ----------------------------------------------------------------
install -d -m 0755 /opt/bin
install -m 0755 "${SCRIPT_SOURCE}" "${SCRIPT_TARGET}"
echo -e "${GREEN}Installed:${NC} ${SCRIPT_TARGET}"
# }}} - Script ----------------------------------------------------------------

# {{{ - Unit ------------------------------------------------------------------
install -m 0644 "${UNIT_SOURCE}" "${UNIT_TARGET}"
echo -e "${GREEN}Installed:${NC} ${UNIT_TARGET}"

systemctl daemon-reload
# enable only, no --now: the unit is meant to run after a resume, not now
systemctl enable nordvpn-resume.service
echo -e "${GREEN}Enabled:${NC} nordvpn-resume.service"
# }}} - Unit ------------------------------------------------------------------

# {{{ - Old hook --------------------------------------------------------------
if [[ -e "${OLD_HOOK}" ]]; then
  rm -f "${OLD_HOOK}"
  echo -e "${YELLOW}Removed:${NC} ${OLD_HOOK} (dead system-sleep hook)"
fi
# }}} - Old hook --------------------------------------------------------------

echo
"${SCRIPT_TARGET}" --check || true

cat <<EOF

Next:
  After the next resume:   journalctl -u nordvpn-resume -b
  Health check any time:   sudo ${SCRIPT_TARGET} --check
  Undo:                    systemctl disable nordvpn-resume
EOF
