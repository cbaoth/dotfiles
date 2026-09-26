# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148 disable=SC2034
#
# ~/lib/env-saito.sh: Host-specific environment for saito.
#
# Sourced before ~/lib/aliases-saito.sh (see ~/.common_rc). Holds bare variable
# assignments consumed elsewhere, hence the blanket SC2034.

# {{{ - TMUX -----------------------------------------------------------------
# SSH logins attach to the persistent tmux session `main` (see ~/.common_rc,
# cb_tmux_autoattach). ON TRIAL since 2026-09; set to 0 to switch off.
CB_TMUX_AUTOATTACH=1
# }}} - TMUX -----------------------------------------------------------------

return 0
