# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-11001001_org.zsh: Host-specific aliases (vserver only).

# {{{ - SILVERBULLET ---------------------------------------------------------
# sb-passwd: rotate the SilverBullet login password.
#
# Exists because the rotation is three steps, and skipping the middle one looks
# exactly like a wrong password: SB_USER is read from .env only at container
# START, so editing .env alone changes nothing and the old password keeps
# working until the next restart.
#
# The password is never passed as an argument, never echoed and never written
# anywhere but .env — notably not into ~/.ccrun.log, which once captured it via
# a `docker exec … env` dump. Verification compares sha256 prefixes instead.
sb-passwd() {
  emulate -L zsh
  setopt local_options no_glob

  local -r envfile="/srv/silverbullet/.env"
  local -r compose="/srv/silverbullet/compose.yaml"

  [[ -f "${envfile}" ]] || { print -ru2 "sb-passwd: not found: ${envfile}"; return 1; }
  command -v docker >/dev/null 2>&1 || { print -ru2 "sb-passwd: docker not found"; return 1; }

  local container
  container="$(docker compose -f "${compose}" ps -q silverbullet 2>/dev/null)"
  [[ -n "${container}" ]] || { print -ru2 "sb-passwd: silverbullet container not running"; return 1; }

  # Keep the existing username; only the secret half changes.
  local user_part
  user_part="$(sed -n 's/^SB_USER=\([^:]*\):.*/\1/p' "${envfile}")"
  [[ -n "${user_part}" ]] || { print -ru2 "sb-passwd: no SB_USER=<user>:<pass> line in ${envfile}"; return 1; }

  local pw1 pw2
  read -rs "pw1?New SilverBullet password for ${user_part}: "; print
  read -rs "pw2?Repeat: "; print
  if [[ -z "${pw1}" ]]; then
    print -ru2 "sb-passwd: empty password, aborted"; return 1
  elif [[ "${pw1}" != "${pw2}" ]]; then
    print -ru2 "sb-passwd: passwords do not match, aborted"; return 1
  elif [[ "${pw1}" == *:* ]]; then
    # SB_USER splits on ':', so a colon would silently truncate the password.
    print -ru2 "sb-passwd: password must not contain ':', aborted"; return 1
  fi

  # Rewrite .env in place, preserving line order and every other setting. The
  # new value only ever lives in shell memory and the temp file (umask 077).
  local tmp
  tmp="$(umask 077; mktemp "${envfile}.XXXXXX")" || return 1
  local -a out=()
  local line
  for line in "${(f)$(<${envfile})}"; do
    if [[ "${line}" == SB_USER=* ]]; then
      out+=("SB_USER=${user_part}:${pw1}")
    else
      out+=("${line}")
    fi
  done
  print -rl -- "${out[@]}" > "${tmp}" || { rm -f "${tmp}"; return 1 }
  chmod 600 "${tmp}"
  mv "${tmp}" "${envfile}" || { rm -f "${tmp}"; return 1 }
  pw1=''; pw2=''; out=()
  print "sb-passwd: ${envfile} updated (mode 600)"

  # Step 2 — the one that is easy to forget. Recreates the container so the new
  # SB_USER is actually read.
  docker compose -f "${compose}" up -d || {
    print -ru2 "sb-passwd: compose up failed — .env holds the NEW password, container the OLD one"
    return 1
  }
  sleep 5

  # Verify without revealing anything: the container env and .env must agree.
  local h_env h_file
  h_env="$(docker exec "${container}" env 2>/dev/null | grep '^SB_USER=' | sha256sum | cut -c1-12)"
  h_file="$(grep -h '^SB_USER=' "${envfile}" | tr -d '\r' | sha256sum | cut -c1-12)"
  if [[ -z "${h_env}" ]]; then
    # Expected: `up -d` replaces the container, so the old id is gone.
    container="$(docker compose -f "${compose}" ps -q silverbullet 2>/dev/null)"
    h_env="$(docker exec "${container}" env 2>/dev/null | grep '^SB_USER=' | sha256sum | cut -c1-12)"
  fi

  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' https://notes.11001001.org/)"
  print "sb-passwd: login page HTTP ${code} (want 200)"

  if [[ "${h_env}" == "${h_file}" && "${code}" == 200 ]]; then
    print "sb-passwd: OK — container and .env agree. Now update KeePassXC, and"
    print "           log in again on every device (old sessions may survive)."
  else
    print -ru2 "sb-passwd: VERIFY FAILED (env=${h_env} file=${h_file} http=${code})"
    return 1
  fi
}
# }}} - SILVERBULLET ---------------------------------------------------------

return 0
