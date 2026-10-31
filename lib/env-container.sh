# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148 disable=SC2034
#
# ~/lib/env-container.sh: Environment for every container (IS_DOCKER=true).
#
# Sourced after the OS and before the host env file (see source_ifex_custom
# in ~/.common_rc), so a container's hostname file can still override this.
# Holds bare variable assignments consumed elsewhere, hence the blanket SC2034.

# {{{ - TMUX -----------------------------------------------------------------
# dcsh/dsh shells start in a fresh tmux session (see ~/.common_rc,
# cb_tmux_autoattach): the green status bar marks the container, and the
# session outlives a dropped `docker exec`. Skipped in VS Code terminals and
# when the host shell is already in tmux (CB_TMUX_SKIP, set by dcsh/dsh).
CB_TMUX_AUTOATTACH=1
# }}} - TMUX -----------------------------------------------------------------

return 0
