#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Install or update the nvidia-power-limit script, config, and systemd unit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_SOURCE="${SCRIPT_DIR}/nvidia-power-limit.sh"
SCRIPT_TARGET="/opt/bin/nvidia-power-limit.sh"

CONFIG_SOURCE="${SCRIPT_DIR}/nvidia-power-limit.conf"
CONFIG_TARGET="/etc/nvidia-power-limit.conf"

UNIT_SOURCE="${SCRIPT_DIR}/nvidia-power-limit.service"
UNIT_TARGET="/etc/systemd/system/nvidia-power-limit.service"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: This script must be run as root.${NC}" >&2
  exit 1
fi

for f in "${SCRIPT_SOURCE}" "${CONFIG_SOURCE}" "${UNIT_SOURCE}"; do
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: Source file not found: $f${NC}" >&2
    exit 1
  fi
done

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo -e "${RED}Error: nvidia-smi not found — install the proprietary NVIDIA driver first.${NC}" >&2
  exit 1
fi

# {{{ - Script ----------------------------------------------------------------
install -d -m 0755 /opt/bin
install -m 0755 "${SCRIPT_SOURCE}" "${SCRIPT_TARGET}"
echo -e "${GREEN}Installed:${NC} ${SCRIPT_TARGET}"
# }}} - Script ----------------------------------------------------------------

# {{{ - Config ----------------------------------------------------------------
# Never clobber an existing config: it holds the tuning value the user is
# actively bisecting (250 -> 240 -> 220). Overwriting it would silently reset
# an in-progress crash test.
if [[ -f "${CONFIG_TARGET}" ]]; then
  echo -e "${YELLOW}Kept existing:${NC} ${CONFIG_TARGET} (not overwritten)"
  echo -e "  Compare with the template: diff ${CONFIG_TARGET} ${CONFIG_SOURCE}"
else
  install -m 0644 "${CONFIG_SOURCE}" "${CONFIG_TARGET}"
  echo -e "${GREEN}Installed:${NC} ${CONFIG_TARGET}"
fi
# }}} - Config ----------------------------------------------------------------

# {{{ - Unit ------------------------------------------------------------------
install -m 0644 "${UNIT_SOURCE}" "${UNIT_TARGET}"
echo -e "${GREEN}Installed:${NC} ${UNIT_TARGET}"

systemctl daemon-reload
systemctl enable --now nvidia-power-limit.service
echo -e "${GREEN}Enabled and started:${NC} nvidia-power-limit.service"
# }}} - Unit ------------------------------------------------------------------

echo
"${SCRIPT_TARGET}" --show

cat <<EOF

Next:
  Verify it survives a reboot:   systemctl status nvidia-power-limit
  Retune the cap:                \$EDITOR ${CONFIG_TARGET}
                                 systemctl restart nvidia-power-limit
  Undo the mitigation:           systemctl disable --now nvidia-power-limit
                                 ${SCRIPT_TARGET} --reset

Background: docs/troubleshooting/gpu-xid79-bus-fall-off.md
EOF
