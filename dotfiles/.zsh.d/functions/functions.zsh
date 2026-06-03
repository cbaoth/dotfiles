# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/functions/functions.zsh: Zsh-specific shell functions.
#
# Shell-agnostic functions live in ~/lib/functions.sh (sourced earlier in .zshrc).
# This file contains only zsh-specific additions.

# {{{ = ZSH SPECIFIC =========================================================

# Run a shell function as root in a new zsh instance (zsh-only: uses $functions[]).
zsudo() { sudo zsh -c "$functions[$1]" "$@"; }

# Completion for check_script (defined in ~/lib/functions.sh).
_check_script() {
  _alternative \
    'scripts:shell script:_files -g "*.sh *.bash *.zsh *.ksh"' \
    'plain:extensionless file:_files -g "*~*.*(.)"'
}
compdef _check_script check_script

# }}} = ZSH SPECIFIC =========================================================

return 0
