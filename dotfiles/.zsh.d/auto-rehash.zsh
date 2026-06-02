# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/auto-rehash.zsh: Auto-rehash after commands that install new executables.
#
# Commands are registered in _AUTO_REHASH_CMDS. This file owns the defaults
# (well-known package managers and build tools). Alias files register their own
# names close to where they are defined via:
#
#   _AUTO_REHASH_CMDS+=(myalias 'myalias!')
#
# Matching is on the first word of the typed command (after stripping a leading
# 'sudo'), so broad names like 'apt' match any apt invocation (including search,
# list, etc.). This is intentional — rehash is cheap and false positives are
# harmless.
#
# This file resets the array to its defaults on each source so that reload-aliases
# can re-source it first and get a clean slate before alias files re-append.

# {{{ = AUTO REHASH ==========================================================

# Reset to defaults. Alias files append their own entries after this file is sourced.
_AUTO_REHASH_CMDS=(
  # --- Debian / Ubuntu ---
  apt apt-get aptitude dpkg dpkg-deb gdebi

  # --- Arch Linux ---
  pacman yay paru pikaur trizen

  # --- RPM (Fedora / RHEL / SUSE) ---
  dnf yum rpm zypper

  # --- Alpine ---
  apk

  # --- macOS ---
  brew port mas

  # --- Snap / Flatpak (direct use) ---
  snap flatpak

  # --- Nix ---
  nix nix-env nix-channel nixos-rebuild home-manager

  # --- Node.js ---
  npm npx yarn pnpm corepack bun

  # --- Python ---
  pip pip2 pip3 pipx uv conda mamba micromamba pipenv poetry pdm hatch

  # --- Ruby ---
  gem bundle

  # --- Rust ---
  cargo rustup

  # --- Go ---
  go

  # --- PHP ---
  composer

  # --- Java / JVM ---
  sdk             # SDKMAN

  # --- Lua ---
  luarocks

  # --- Dart / Flutter ---
  dart flutter
)

_auto_rehash_preexec() {
  local cmd="${1%% *}"
  [[ "$cmd" == "sudo" ]] && cmd="${${1#sudo }%% *}"
  (( ${_AUTO_REHASH_CMDS[(Ie)$cmd]} )) && _auto_rehash_pending=1
}

_auto_rehash_precmd() {
  if (( ${_auto_rehash_pending:-0} )); then
    rehash
    _auto_rehash_pending=0
  fi
}

autoload -Uz add-zsh-hook
# Remove before re-adding to prevent duplicate hooks on re-source
add-zsh-hook -d preexec _auto_rehash_preexec 2>/dev/null
add-zsh-hook -d precmd  _auto_rehash_precmd  2>/dev/null
add-zsh-hook    preexec _auto_rehash_preexec
add-zsh-hook    precmd  _auto_rehash_precmd

# }}} = AUTO REHASH ==========================================================
