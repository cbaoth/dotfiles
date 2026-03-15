#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Check Ubuntu release-upgrade status and available updates.

set -euo pipefail  # Fail if any command in a pipeline fails

# cli arguments
declare _CHECK_STATUS=true  # default action, currently the only action implemented
declare -i _VERBOSE=0

_command_exists() {
  local -r cmd="${1:-}"
  local -r apt_package="${2:-}"  # optional parameter for the package that provides the command
  [[ -z "$cmd" ]] && { echo "ERROR: No command specified."; return 1; }
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: Required command '$cmd' not found."
    if [[ -n "$apt_package" ]]; then
      echo -e "Please install it using:\n  sudo apt install $apt_package"
    else
      echo "Please install it and try again."
    fi
    exit 1
  fi
}

_check_precondition() {
  # Check if the script is run with root privileges
  if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Please use sudo."
    exit 1
  fi

  # Check if the script is run on an Ubuntu system
  if ! [[ -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
    echo "ERROR: This script is intended for Ubuntu systems only."
    exit 1
  fi

  # Check if required commands are available
  _command_exists "do-release-upgrade" "ubuntu-release-upgrader-core"
  _command_exists "lsb_release" "lsb-release"
  #_command_exists "ubuntu-security-status" "update-manager-core"  # Replaced with `pro` command
  _command_exists "pro" "ubuntu-pro-client"
  _command_exists "jq" "jq"
}

_get_release_status() {
  # Check for new Ubuntu release
  local -r current_release=$(lsb_release -rs)
  local -r is_lts=$(lsb_release -a | grep "Description:.*LTS" > /dev/null && echo true || echo false)
  local -r current_date=$(date +%Y-%m-%d)
  local -r _check_dist_upgrade_output=$(do-release-upgrade -c 2>&1)
  if ${is_lts}; then
    local -r lts_str="LTS"
    #local -r eol_date=$(ubuntu-security-status | grep "Support for base system" | awk '{print $6}')
    # Ubuntu Pro is not available for non-LTS releases. So we can only check EOL status for LTS releases using `pro security-status`.
    local -r eol_date=$(pro security-status --format json | jq -r '.summary.eol_date')
  else
    local -r lts_str="non-LTS"
    local -r eol_date="n/a"
  fi
  local -r new_release=$(grep "New release" <<<"${_check_dist_upgrade_output}" | awk '{print $3}' || echo "n/a")
  [[ ${_VERBOSE} -gt 0 ]] && echo "DEBUG: Current release: ${current_release} ${lts_str}, New release: ${new_release}, EOL date: ${eol_date}, Current date: ${current_date}"

  # Check if the current release is nearing end of life
  if [[ -n "${current_date}" && "${eol_date}" != "n/a" && "${current_date}" > "${eol_date}" ]]; then
      echo "Your current Ubuntu release (${current_release}) is no longer supported. Consider upgrading."
  fi

  # Check if a new release is available
  if [[ -n "${new_release}" && "${new_release}" != "n/a" && "${new_release}" != "${current_release}" ]]; then
      echo -e "A new Ubuntu release is available:\n  ${new_release} (current: ${current_release})"
      echo -e "Consider upgrading your system:\n  do-release-upgrade"
      if ! command -v do-release-upgrade &> /dev/null; then
          echo "It seems that do-release-upgrade is missing. To install it, use:"
          echo "  sudo apt-get install -y ubuntu-release-upgrader-core"
      fi
  else
      echo "Your current Ubuntu release ${current_release} ${lts_str} is up to date."
  fi
}

_usage() {
  cat <<EOF
Usage: $(basename "$0") [ACTION|OPTIONS]

Check for Ubuntu release updates and end-of-life status.

Action:
  check           Only check for updates without suggesting upgrade (default)

Options:
  -v, --verbose   Increase verbosity (can be used multiple times)
  -h, --help      Show this help message and exit
EOF
}

_parse_args() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      check)
        _CHECK_ONLY=true
        shift
        ;;
      -v|--verbose)
        _VERBOSE=$((_VERBOSE + 1))
        shift
        ;;
      -h|--help)
        _usage
        exit 0
        ;;
      -*)
        echo "ERROR: Unknown option: $1"
        _usage
        exit 1
        ;;
      *)
        echo "ERROR: Unknown action: $1"
        _usage
        exit 1
        ;;
    esac
  else
    _CHECK_STATUS=true  # Default action is to check only
  fi
}

_main() {
  _parse_args "$@"
  _check_precondition
  if $_CHECK_STATUS; then
    echo "Checking for Ubuntu release updates..."
    _get_release_status
  fi
}

_main "$@" || exit 1

exit 0
