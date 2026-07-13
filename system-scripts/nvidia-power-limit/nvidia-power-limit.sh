#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# nvidia-power-limit: Apply a persistent GPU power cap (Xid 79 mitigation).
#
# `nvidia-smi -pl` is a runtime setting in the driver only — it is NOT written
# to hardware and does NOT survive a reboot. Hence this unit: it re-applies the
# cap on every boot so the mitigation cannot silently evaporate the next time
# the machine restarts (which is exactly how a crash test gets invalidated).
#
# Background: docs/troubleshooting/gpu-xid79-bus-fall-off.md

set -o errexit
set -o pipefail
set -o nounset
(( ${DEBUG_LVL:-0} >= 2 )) && set -o xtrace

# {{{ = CONSTANTS =============================================================

declare -r CONFIG_FILE="${NVIDIA_POWER_LIMIT_CONFIG:-/etc/nvidia-power-limit.conf}"

# Fallbacks if the config is missing (stock default for an RTX 4070 Ti is 285 W;
# 250 W is the documented starting point for the mitigation).
declare -i NVIDIA_POWER_LIMIT_W=250
declare -i NVIDIA_GPU_INDEX=0

# }}} = CONSTANTS =============================================================

# {{{ = FUNCTIONS =============================================================

p_msg() { printf '%s\n' "$*"; }
p_err() { printf 'ERROR: %s\n' "$*" >&2; }
p_war() { printf 'WARNING: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: nvidia-power-limit [--show|--reset|--help]

Applies the GPU power cap from ${CONFIG_FILE}. Run without arguments by the
nvidia-power-limit.service unit at every boot.

Options:
  --show     Print the current and configured limits; change nothing
  --reset    Restore the GPU's stock default limit (undo the mitigation)
  --help     This help

Why this exists: \`nvidia-smi -pl\` does not persist across reboots.
Background: docs/troubleshooting/gpu-xid79-bus-fall-off.md
EOF
}

# Query a single nvidia-smi field for our GPU, stripped of units.
gpu_query() {
  nvidia-smi --id="${NVIDIA_GPU_INDEX}" \
             --query-gpu="$1" --format=csv,noheader,nounits 2>/dev/null \
    | tr -d ' '
}

show() {
  printf 'GPU %s: %s\n' "${NVIDIA_GPU_INDEX}" "$(gpu_query name)"
  printf '  current limit : %s W\n' "$(gpu_query power.limit)"
  printf '  stock default : %s W\n' "$(gpu_query power.default_limit)"
  printf '  allowed range : %s - %s W\n' \
    "$(gpu_query power.min_limit)" "$(gpu_query power.max_limit)"
  printf '  configured    : %s W  (%s)\n' "${NVIDIA_POWER_LIMIT_W}" "${CONFIG_FILE}"
}

# }}} = FUNCTIONS =============================================================

# {{{ = MAIN ==================================================================

main() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    p_err "nvidia-smi not found — is the proprietary NVIDIA driver installed?"
    exit 1
  fi

  # shellcheck source=nvidia-power-limit.conf
  if [[ -r "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
  else
    p_war "config not found: ${CONFIG_FILE} — using built-in default ${NVIDIA_POWER_LIMIT_W} W"
  fi

  case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    --show|-s) show; exit 0 ;;
    --reset)
      local -r default_w="$(gpu_query power.default_limit)"
      p_msg "restoring stock power limit: ${default_w} W"
      nvidia-smi --id="${NVIDIA_GPU_INDEX}" --power-limit="${default_w}"
      exit 0
      ;;
    "") ;;  # normal operation
    *)  p_err "unknown option: $1"; usage >&2; exit 1 ;;
  esac

  # Refuse a value the card will not accept, rather than letting nvidia-smi
  # fail cryptically at boot where nobody is watching.
  local -i min_w max_w
  min_w="$(gpu_query power.min_limit | cut -d. -f1)"
  max_w="$(gpu_query power.max_limit | cut -d. -f1)"
  if (( NVIDIA_POWER_LIMIT_W < min_w || NVIDIA_POWER_LIMIT_W > max_w )); then
    p_err "configured limit ${NVIDIA_POWER_LIMIT_W} W is outside the card's range (${min_w}-${max_w} W)"
    exit 1
  fi

  # A cap set to the stock default is a no-op wearing a cap's clothes. Worse, it
  # makes re-arming silently fail: `systemctl enable --now` would report "nothing
  # to do" while the user believes a cap is active. Say so loudly.
  local -i default_i
  default_i="$(gpu_query power.default_limit | cut -d. -f1)"
  if (( NVIDIA_POWER_LIMIT_W == default_i )); then
    p_war "configured limit (${NVIDIA_POWER_LIMIT_W} W) IS the stock default — this caps nothing."
    p_war "To run uncapped, disable the service instead of setting the stock value:"
    p_war "  sudo systemctl disable --now nvidia-power-limit"
    p_war "Leave ${CONFIG_FILE} armed at the value you would want if you needed it."
  fi

  local -r current_w="$(gpu_query power.limit | cut -d. -f1)"
  if [[ "${current_w}" == "${NVIDIA_POWER_LIMIT_W}" ]]; then
    p_msg "power limit already ${NVIDIA_POWER_LIMIT_W} W, nothing to do"
    exit 0
  fi

  p_msg "setting power limit: ${current_w} W -> ${NVIDIA_POWER_LIMIT_W} W"
  nvidia-smi --id="${NVIDIA_GPU_INDEX}" --power-limit="${NVIDIA_POWER_LIMIT_W}"
}

main "$@"

# }}} = MAIN ==================================================================
