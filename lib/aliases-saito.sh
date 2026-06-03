# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/lib/aliases-saito.sh: Host-specific aliases for saito.

# {{{ - SYSTEM ---------------------------------------------------------------
alias open-stash="sudo cryptsetup open /dev/md1 stash"
alias close-stash="sudo cryptsetup close stash"
alias mount-stash="sudo cryptsetup open /dev/md1 stash && sudo mount /dev/mapper/stash /media/stash"
alias umount-stash="sudo umount /media/stash; sudo cryptsetup close stash"
# }}} - SYSTEM ---------------------------------------------------------------

return 0
