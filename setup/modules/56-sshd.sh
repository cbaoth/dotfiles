# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 56-sshd: key-only authentication policy for hosts that run an sshd.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Key-only sshd authentication policy (only where sshd is installed)"
MODULE_DOC="docs/setup/ssh-hardening.md"
# No MODULE_PROFILES: every profile. The module is a no-op where openssh-server
# is absent, which is a better gate than the profile — a desktop may run an
# sshd and a container-only server may not.

# {{{ = CONSTANTS ============================================================

declare -r SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"

# The numbering is load-bearing, not cosmetic. sshd takes the FIRST value it
# sees for a keyword, and `Include /etc/ssh/sshd_config.d/*.conf` is the first
# line of the shipped sshd_config — so within this directory, LOWER NUMBER WINS
# and the managed baseline must sort AFTER the hand-maintained local file.
declare -r SSHD_LOCAL="${SSHD_DROPIN_DIR}/01-local.conf"
declare -r SSHD_BASELINE="${SSHD_DROPIN_DIR}/10-hardening.conf"

# What belongs in which file: this baseline is *authentication policy*, which is
# the part that is genuinely identical on every host. Anything describing where
# the host sits and who reaches it — Port, AllowUsers, the *Forwarding knobs —
# is per-host and belongs in 01-local.conf.
declare -r SSHD_BASELINE_CONTENT="# Managed by dotfiles: setup/modules/56-sshd.sh — do not edit by hand.
# Docs: docs/setup/ssh-hardening.md
#
# Authentication policy only, identical on every host. Host-specific settings
# (Port, AllowUsers, AllowAgentForwarding, X11Forwarding, ListenAddress) go in
# 01-local.conf, which sorts BEFORE this file and therefore wins: sshd keeps the
# first value it sees for a keyword.

PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no

# The belt-and-braces line: forecloses password, keyboard-interactive and
# GSSAPI regardless of what any other drop-in or a distro upgrade sets.
AuthenticationMethods publickey

PermitEmptyPasswords no
PermitRootLogin no
MaxAuthTries 3"

# }}} = CONSTANTS ============================================================

# {{{ = HELPERS ==============================================================

# Does the admin account have at least one usable public key on this host?
# Usage: _sshd_admin_user  ->  prints the account system-setup is acting for
_sshd_admin_user() {
  printf '%s' "${SUDO_USER:-${USER:-$(id -un)}}"
}

# Both names are in OpenSSH's default AuthorizedKeysFile; authorized_keys2 is a
# protocol-1-era leftover but still honoured, so accept either rather than
# reporting a false lockout.
_sshd_has_authorized_keys() {
  local -r account="$1"
  local home_dir
  home_dir="$(getent passwd "${account}" | cut -d: -f6)"
  [[ -n "${home_dir}" ]] || return 1

  local f
  for f in authorized_keys authorized_keys2; do
    [[ -s "${home_dir}/.ssh/${f}" ]] && return 0
  done
  return 1
}

# Is ACCOUNT a regular human login account — not root, not a service account,
# not nobody? UID_MIN is where the distro starts handing out human accounts;
# the 1000 fallback covers a host with no /etc/login.defs.
_sshd_is_regular_user() {
  local -r account="$1"
  local uid uid_min
  uid="$(id -u "${account}" 2>/dev/null)" || return 1
  uid_min="$(awk '$1 == "UID_MIN" { print $2 }' /etc/login.defs 2>/dev/null)"
  [[ "${uid_min}" =~ ^[0-9]+$ ]] || uid_min=1000
  (( uid >= uid_min )) && (( uid != 65534 ))
}

# Does anything already restrict who may log in? A bootstrap script's drop-in or
# the main config may own that decision; seeding a second AllowUsers would be
# inert (first value wins) and misleading to the next reader.
#
# The managed baseline is excluded deliberately. A host configured by hand
# before this module existed carries AllowUsers there — and this run is about to
# overwrite that file, so counting it would see a restriction that is seconds
# from disappearing and skip replacing it.
_sshd_allowusers_set() {
  local f
  for f in /etc/ssh/sshd_config "${SSHD_DROPIN_DIR}"/*.conf; do
    [[ -f "${f}" && "${f}" != "${SSHD_BASELINE}" ]] || continue
    if grep -qsiE '^[[:space:]]*(AllowUsers|AllowGroups)[[:space:]]' "${f}"; then
      return 0
    fi
  done
  return 1
}

# The systemd unit carrying sshd here. Ubuntu/Debian call it ssh.service and
# ship sshd.service as an alias; other distros only have the latter.
_sshd_service_unit() {
  if systemctl list-unit-files ssh.service >/dev/null 2>&1 \
     && systemctl cat ssh.service >/dev/null 2>&1; then
    printf 'ssh.service'
  else
    printf 'sshd.service'
  fi
}

# }}} = HELPERS ==============================================================

module_run() {
  # {{{ - is there an sshd to harden at all? ----------------------------------
  # Deliberately never installs openssh-server: turning on remote access is a
  # decision per host, not a side effect of running system-setup.
  if [[ ! -x /usr/sbin/sshd ]]; then
    st::noop "no sshd installed — nothing to harden"
    return 0
  fi
  # }}}

  # {{{ - lockout guard -------------------------------------------------------
  # AuthenticationMethods publickey with no authorized key is a locked door with
  # the key thrown away. Check before writing, not after: on a fresh box this is
  # the one mistake that cannot be fixed over the network.
  local admin
  admin="$(_sshd_admin_user)"
  local -r admin

  if ! _sshd_has_authorized_keys "${admin}"; then
    st::err "${admin} has no authorized_keys — refusing to enforce key-only auth"
    st::err "add a client public key first, then re-run this module"
    (( ST_FAILED++ ))
    return 0
  fi
  st::skip "authorized_keys present for ${admin}"
  # }}}

  # {{{ - host-specific drop-in (created once, never touched again) -----------
  if [[ -f "${SSHD_LOCAL}" ]]; then
    st::noop "host-specific drop-in exists: ${SSHD_LOCAL}"
  else
    # AllowUsers is seeded live rather than commented out, for one specific
    # account: the one running system-setup, which the lockout guard above has
    # already proven can log in by key. That is a stronger warrant than "some
    # account named X exists". Everything else stays commented — a template that
    # changes no behaviour is the safe default.
    #
    # Skipped when the account is root or a service account (restricting SSH to
    # root would be worse than not restricting it), and when something already
    # owns the decision. Both cases warn instead: a restriction that silently
    # did not happen is worse than none, because you stop checking.
    #
    # A host hardened by hand before this module existed keeps its AllowUsers in
    # the baseline, which this run replaces. Carry that value over rather than
    # seeding the caller: the hand-written list may be wider (a backup-pull
    # account), and narrowing it silently would break exactly the unattended
    # things nobody notices until the next restore.
    local carried=""
    if [[ -f "${SSHD_BASELINE}" ]]; then
      carried="$(grep -m1 -ihE '^[[:space:]]*(AllowUsers|AllowGroups)[[:space:]]' \
        "${SSHD_BASELINE}" 2>/dev/null | sed 's/^[[:space:]]*//')"
    fi

    local allow_line="" allow_warn=""
    if _sshd_allowusers_set; then
      allow_line="#AllowUsers ${admin}"
      st::skip "AllowUsers already set elsewhere — not seeding one"
    elif [[ -n "${carried}" ]]; then
      allow_line="${carried}"
      allow_warn="carried '${carried}' over from the baseline this run replaces"
    elif _sshd_is_regular_user "${admin}"; then
      allow_line="AllowUsers ${admin}"
      allow_warn="seeded 'AllowUsers ${admin}': no other account may log in over SSH"
    else
      allow_line="#AllowUsers <user>"
      allow_warn="no regular login account to seed (running as ${admin}) — set AllowUsers by hand"
    fi

    local host_name local_template
    host_name="$(hostname -s)"
    local_template="# Host-specific sshd settings for ${host_name}.
# Hand-maintained: system-setup creates this file once and never rewrites it.
#
# Sorts BEFORE 10-hardening.conf, so anything set here overrides the managed
# baseline — sshd keeps the first value it sees for a keyword.

${allow_line}

#Port 8090
#AllowAgentForwarding no
#X11Forwarding no
#ListenAddress 10.0.0.1"
    st::file_content "${SSHD_LOCAL}" "${local_template}" 644
    [[ -n "${allow_warn}" ]] && st::war "${allow_warn} (${SSHD_LOCAL})"
  fi
  # }}}

  # {{{ - the managed baseline ------------------------------------------------
  local -i before="${ST_CHANGED:-0}"
  st::file_content "${SSHD_BASELINE}" "${SSHD_BASELINE_CONTENT}" 644
  local -ri wrote=$(( "${ST_CHANGED:-0}" > before ? 1 : 0 ))

  # Validate against the *whole* config (main file + every drop-in), which is
  # the only test that means anything — `sshd -t -f <dropin>` would check the
  # fragment in isolation and happily pass a config that cannot start. A bad
  # drop-in here breaks every new connection, so roll it back rather than leave
  # the host in that state.
  if (( wrote )) && (( ST_DRY_RUN == 0 )); then
    if sudo sshd -t; then
      st::skip "sshd config validates"
    else
      st::err "sshd -t rejected the config — rolling back ${SSHD_BASELINE}"
      sudo rm -f "${SSHD_BASELINE}"
      (( ST_FAILED++ ))
      return 0
    fi
  fi
  # }}}

  # {{{ - apply ---------------------------------------------------------------
  # Writing the drop-in is not the same as the host honouring it: under socket
  # activation ssh.socket triggers a long-running ssh.service that parsed the
  # config once at start, and hands each connection a copy of what it parsed
  # then. So reload whenever the file changed. Reload, not restart: established
  # sessions keep their own forked sshd either way, but there is no reason to
  # take the listener down.
  local unit
  unit="$(_sshd_service_unit)"
  local -r unit
  if (( ! wrote )); then
    st::noop "sshd policy already applied"
  elif systemctl is-active --quiet "${unit}" 2>/dev/null; then
    st::run "reload ${unit}" -- sudo systemctl reload "${unit}"
  else
    st::skip "${unit} not running (socket-activated) — applies to new connections"
  fi
  # }}}

  # {{{ - verify the running config, not the file -----------------------------
  # Same reasoning as the sysctl module: a drop-in on disk looks identical
  # whether or not it actually took effect, and a lower-numbered local file may
  # legitimately (or accidentally) be overriding it. Ask sshd what it believes.
  if (( ST_DRY_RUN )); then
    st::skip "dry-run: skipping live sshd -T verification"
    return 0
  fi

  local effective
  effective="$(sudo sshd -T 2>/dev/null)" || {
    st::war "could not read effective config (sshd -T failed)"
    return 0
  }

  local expected
  for expected in \
    'passwordauthentication no' \
    'kbdinteractiveauthentication no' \
    'authenticationmethods publickey' \
    'permitrootlogin no'; do
    if printf '%s\n' "${effective}" | st::grep_q -qxF "${expected}"; then
      st::skip "effective: ${expected}"
    else
      st::war "NOT effective: ${expected} — check ${SSHD_LOCAL} and other drop-ins"
    fi
  done

  # Print the value rather than just "it is set": the whole point of seeding
  # AllowUsers is that you can see, on every run, exactly who that leaves.
  local allow_effective
  allow_effective="$(printf '%s\n' "${effective}" \
    | grep -E '^(allowusers|allowgroups) ' | tr '\n' ' ')"
  if [[ -n "${allow_effective}" ]]; then
    st::skip "effective: ${allow_effective% }"
  else
    st::war "no AllowUsers/AllowGroups in effect — every account with a key can log in"
  fi
  # }}}
}
