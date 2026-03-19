# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-linux_desktop.zsh: Host-specific aliases for Linux desktop environments.

# {{{ - FLATPAK APPS ---------------------------------------------------------
# best effort auto-generate aliases for all flatpak apps
# pattern: lowercase, spaces replaced with dashes
#   adds suffix 'f' to avoid conflicts with native apps (if existing)
while IFS=$'\t' read -r name application; do
  alias_name="$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
  if command -v ${alias_name} >& /dev/null; then
    # name conflict, alias with suffix 'f' for flatpak
    alias "${alias_name}f"="flatpak run ${application}"
  else
    # no conflict, alias without suffix
    alias "${alias_name}"="flatpak run ${application}"
  fi
done < <(flatpak list --app --columns=name,application 2>/dev/null | tail -n +2)
# }}} - FLATPAK APPS ---------------------------------------------------------
