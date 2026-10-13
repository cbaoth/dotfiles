# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.bash_profile: initialization for bash login shells.
#
# interactive non-login shell: .bashrc
# login shell: .bash_profile (or .bash_login or .profile, first found) > .bash_logout

# {{{ - SOURCE BASHRC --------------------------------------------------------
if [[ -f "$HOME/.bashrc" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.bashrc"
else
  echo "Warning: ~/.bashrc not found, some potentially crucial environment settings or functionality may be missing!" >&2
fi
# }}} - SOURCE BASHRC --------------------------------------------------------
