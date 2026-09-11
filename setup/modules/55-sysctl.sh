# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 55-sysctl: kernel tuning for the container workloads on server hosts.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Kernel sysctl tuning for containerised Redis/forking DBs"
MODULE_PROFILES=(server)
MODULE_DOC="docs/setup/kernel-tuning.md"

# A drop-in rather than an edit of /etc/sysctl.conf, for the same reason as the
# logind drop-in in 50-power.sh: the shipped file is package-managed, and a
# drop-in stays greppable as "something we changed".
declare -r SYSCTL_DROPIN="/etc/sysctl.d/99-overcommit.conf"

# Declared with its value in one statement — bin/system-setup sources modules
# from inside a function, so a bare `declare -r` after a `read` would create an
# empty *local* shadowing the global.
declare -r SYSCTL_DROPIN_CONTENT="# Managed by dotfiles: setup/modules/55-sysctl.sh
# Docs: docs/setup/kernel-tuning.md
#
# Redis forks to write its snapshot. With the default heuristic overcommit (0)
# the kernel can refuse that fork whenever the parent's RSS is large relative
# to free memory, so a background save fails even with plenty of memory free —
# Redis warns about this on every start.
#
# 1 = always overcommit. The fork is copy-on-write and touches only the pages
# that change, so the pessimistic accounting the heuristic applies is wrong for
# this workload specifically.
vm.overcommit_memory = 1"

module_run() {
  # {{{ - sysctl drop-in ------------------------------------------------------
  local -r dropin_dir="${SYSCTL_DROPIN%/*}"
  if [[ -d "${dropin_dir}" ]]; then
    st::noop "drop-in directory exists: ${dropin_dir}"
  else
    st::run "create ${dropin_dir}" -- sudo mkdir -p "${dropin_dir}"
  fi

  # st::file_content is a no-op when the content already matches, so the reload
  # below must only fire when it actually wrote something.
  local -i before="${ST_CHANGED:-0}"
  st::file_content "${SYSCTL_DROPIN}" "${SYSCTL_DROPIN_CONTENT}" 644

  if (( "${ST_CHANGED:-0}" > before )); then
    st::run "apply sysctl drop-ins" -- sudo sysctl --system
  else
    st::noop "sysctl drop-in already applied"
  fi
  # }}}

  # {{{ - verify the running kernel matches -----------------------------------
  # The file landing is not the same as the value being live: a drop-in written
  # but never applied looks identical on disk. Check the running value so a
  # re-run is honest about the machine rather than about the file.
  local current
  current="$(sysctl -n vm.overcommit_memory 2>/dev/null || echo '?')"
  if [[ "${current}" == 1 ]]; then
    st::noop "vm.overcommit_memory is live: 1"
  else
    st::war "vm.overcommit_memory is ${current}, expected 1 (reboot pending?)"
  fi
  # }}}
}
