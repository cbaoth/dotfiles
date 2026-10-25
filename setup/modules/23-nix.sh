# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 23-nix: upstream Nix (multi-user, from apt) plus the per-profile nix packages.
#
# Why apt (nix-setup-systemd) and not an upstream installer: it is the upstream
# Nix source, fully open source, managed and updated by apt like everything
# else, and removable with `apt purge` -- no curl|sh, nothing appended to the
# shell rc files. It runs nix-daemon via systemd and creates /nix via
# tmpfiles.d. The Determinate Nix distribution used before (2026) is replaced
# because its daemon (determinate-nixd) is closed source; docs/setup/nix.md.
#
# Nix is installed only where it is used: the package set is data in
# setup/packages/nix-<profile>.list (flake refs, e.g. nixpkgs#foo). A profile
# without such a list skips the module entirely, so a server gets no /nix.
#
# Another Nix already in /nix (Determinate, the nixos.org script) is refused,
# not adopted: two daemons over one store is how stores get corrupted. The
# module prints the uninstall command and stops; re-run it afterwards.
#
# The daemon socket is limited to the nix-users group. Adding the user takes
# effect at the next login, so the packages are installed by a re-run then;
# until that, the module says so instead of failing.
#
# Package check: `nix profile list --json` element names (the attribute name,
# i.e. the part after '#'). Present means done -- no network on a re-run.
# Update all with `nix profile upgrade --all` (by hand, not here).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Nix (upstream, apt nix-setup-systemd) + packages from nix-<profile>.list"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/nix.md"

declare -r NIX_GROUP="nix-users"
# Flakes and the new CLI are still experimental upstream; pass them per command
# so the module does not depend on ~/.config/nix/nix.conf being linked yet.
declare -ra NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

# Is /nix owned by something other than the apt package?
_nix_foreign_install() {
  [[ -x /usr/local/bin/determinate-nixd || -e /nix/receipt.json ]] && return 0
  [[ -d /nix/store ]] && ! st::apt_installed nix-setup-systemd
}

# Names of the packages in the user's nix profile, one per line.
_nix_profile_names() {
  nix "${NIX_FLAGS[@]}" profile list --json 2> /dev/null \
    | jq -r '.elements | if type == "object" then keys[] else .[].attrPath end'
}

module_run() {
  local -r list="nix-$(st::profile)"
  if [[ ! -f "${ST_SETUP_DIR}/packages/${list}.list" ]]; then
    st::noop "no ${list}.list -- Nix not needed for profile '$(st::profile)'"
    return 0
  fi
  local -a refs=()
  st::read_list "${list}" refs || return 1
  if (( ${#refs[@]} == 0 )); then
    st::noop "${list}.list is empty -- Nix not needed"
    return 0
  fi

  if _nix_foreign_install; then
    st::err "/nix belongs to another Nix install; remove it first, then re-run:"
    if [[ -x /nix/nix-installer ]]; then
      st::err "  sudo /nix/nix-installer uninstall    # Determinate / nix-installer"
    else
      st::err "  see 'Uninstalling' in the Nix manual (nixos.org script install)"
    fi
    return 1
  fi

  st::apt_install nix-setup-systemd

  # Dry run on a fresh host: nothing below can be checked yet.
  if ! st::have_cmd nix; then
    st::skip "nix not installed yet -- packages follow on the real run"
    return 0
  fi

  if id -nG "${USER}" | tr ' ' '\n' | st::grep_q -x "${NIX_GROUP}"; then
    st::noop "${USER} is in ${NIX_GROUP}"
  else
    st::run "add ${USER} to ${NIX_GROUP} (daemon access, next login)" -- \
      sudo usermod -aG "${NIX_GROUP}" "${USER}"
  fi
  # The group must be active in THIS process to reach the daemon.
  if ! id -nG | tr ' ' '\n' | st::grep_q -x "${NIX_GROUP}"; then
    st::war "${NIX_GROUP} not active in this session -- log out and in, then re-run"
    st::war "  to install: ${refs[*]}"
    return 0
  fi

  local -a installed=()
  mapfile -t installed < <(_nix_profile_names)
  local ref name
  for ref in "${refs[@]}"; do
    name="${ref##*#}"
    if printf '%s\n' "${installed[@]}" | st::grep_q -Fx "${name}"; then
      st::noop "nix package installed: ${name}"
    else
      st::run "nix profile add ${ref}" -- nix "${NIX_FLAGS[@]}" profile add "${ref}"
    fi
  done
}
