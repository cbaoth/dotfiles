# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148 disable=SC2034
#
# ~/lib/env-11001001_org.sh: Host-specific environment for the vserver.
#
# Sourced before ~/lib/aliases-11001001_org.sh (see ~/.common_rc). Holds bare
# variable assignments consumed elsewhere, hence the blanket SC2034.

# {{{ - GIT ------------------------------------------------------------------
# This host is a read-only replica by design: the stored GitHub credential can
# only fetch, so a plain `git push` in ~/dotfiles or ~/notes can only ever 403.
# Pushing here is meant to be a conscious act (see bin/git-push-token), so send
# it straight to the prompting push rather than failing first.
#
# Consumed by _repo_push_needs_token in ~/.aliases, which drives repo-sync and
# the dotg/notg wrappers. Set to 0 to force plain pushes again.
CB_PUSH_NEEDS_TOKEN=1
# }}} - GIT ------------------------------------------------------------------

# {{{ - TMUX -----------------------------------------------------------------
# SSH logins attach to the persistent tmux session `main` (see ~/.common_rc,
# cb_tmux_autoattach). ON TRIAL since 2026-09; set to 0 to switch off.
CB_TMUX_AUTOATTACH=1
# }}} - TMUX -----------------------------------------------------------------

return 0
