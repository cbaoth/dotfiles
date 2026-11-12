# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/zshrc-linux_wsl.zsh: WSL-specific zshrc settings.

# set display (e.g. to use with https://sourceforge.net/projects/vcxsrv/)
export DISPLAY=:0

# enable linger for user 1000 to allow user services to run when not logged in
# this is required for e.g. systemd user services, including podman containers
loginctl enable-linger 1000

# Warn when the installed WSL is older (major.minor) than the latest GitHub
# release. Called from the MOTD section in ~/.zshrc. Opt out: CB_WSL_UPDATE_CHECK=0.
# An outdated WSL once made every new session with systemd 259 hang for ~2 min.
# The release-page redirect is used instead of api.github.com: the anonymous API
# limit is per IP and a shared office IP exhausts it. The cache is refreshed in
# the background, so the first shell after a stale cache shows the old value.
cb_wsl_update_check() {
  [[ "${CB_WSL_UPDATE_CHECK:-1}" == 0 ]] && return 0
  (( $+commands[wslinfo] )) || return 0

  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/wsl-latest-version"
  local -a fresh=($cache(N.mh-24))
  if (( ! $#fresh && $+commands[curl] )); then
    mkdir -p "${cache:h}"
    (
      local tmp="$cache.$$"
      curl -fsSI --max-time 5 https://github.com/microsoft/WSL/releases/latest 2>/dev/null \
        | sed -n 's|^location:.*/tag/\([0-9][0-9.]*\).*|\1|Ip' >| "$tmp"
      # keep the old value on failure, but touch it so an offline host retries only daily
      if [[ -s $tmp ]]; then mv -f "$tmp" "$cache"; else rm -f "$tmp"; [[ -e $cache ]] && touch "$cache"; fi
    ) &!
  fi
  [[ -s $cache ]] || return 0

  # wslinfo --wsl-version is missing on old WSL; then there is nothing to compare
  local cur latest cur_mm latest_mm
  cur=$(wslinfo --wsl-version 2>/dev/null) || return 0
  latest=$(<"$cache")
  [[ $cur == (#b)([0-9]##.[0-9]##)* ]] && cur_mm=$match[1] || return 0
  [[ $latest == (#b)([0-9]##.[0-9]##)* ]] && latest_mm=$match[1] || return 0

  autoload -Uz is-at-least
  is-at-least "$latest_mm" "$cur_mm" \
    || cl::p_war "WSL $cur is outdated (latest $latest), run 'wsl --update' in PowerShell"
}

return 0
