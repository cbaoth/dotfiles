# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-puppet.zsh: Host-specific aliases for puppet.

# {{{ - APPS -----------------------------------------------------------------
# }}} - APPS -----------------------------------------------------------------

# {{{ - MOUNT ----------------------------------------------------------------
# host specific mount aliases
# requires: ~/.zsh.d/functions/functions.zsh
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
