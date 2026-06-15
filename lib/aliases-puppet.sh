# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/lib/aliases-puppet.sh: Host-specific aliases for puppet.

# {{{ - APPS -----------------------------------------------------------------
# }}} - APPS -----------------------------------------------------------------

# {{{ - MOUNT ----------------------------------------------------------------
# host specific mount aliases
# requires: ~/lib/functions.sh (mount-mountpoints / umount-mountpoints)
#alias mount-win='mount-mountpoints /mnt/[c-f]/'
#alias umount-win='umount-mountpoints /mnt/[c-f]/'
alias mount-saito='mount-mountpoints /srv/saito/*/'
alias umount-saito='umount-mountpoints /srv/saito/*/'
#alias mount-all='mount-win; mount-saito'
#alias umount-all='umount-win; umount-saito'
alias mount-all='mount-saito'
alias umount-all='umount-saito'
# }}} - MOUNT ----------------------------------------------------------------

return 0
