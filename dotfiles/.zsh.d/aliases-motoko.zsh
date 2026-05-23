# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-motoko.zsh: Host-specific aliases for motoko.

# {{{ - APPS -----------------------------------------------------------------
#alias comfyenv="source ~/comfy-env/bin/activate"
alias comfyenv="conda activate comfy"  # activate comfy env (assumes conda env "comfy" exists)
alias comfy="command -v comfy-cli >& /dev/null || comfyenv && comfy-cli"  # run comfy-cli while ensuring that comfy env is activated
alias comfyu="comfy update"  # update comfy itself, not the nodes
alias comfyun="comfy node update all"  # update all comfy nodes
alias comfyua="comfyu && comfyun"  # update all of comfy (incl. all nodes)
alias comfyui="comfy launch"  # launch comfy UI
# }}} - APPS -----------------------------------------------------------------

# {{{ - MOUNT ----------------------------------------------------------------
# host specific mount aliases
# requires: ~/.zsh.d/functions/functions.zsh
alias mount-win='__mount_mountpoints /mnt/[c-f]/'
alias umount-win='__mount_mountpoints -u /mnt/[c-f]/'
alias mount-saito='__mount_mountpoints /srv/saito/*/'
alias umount-saito='__mount_mountpoints -u /srv/saito/*/'
alias mount-all='mount-win; mount-saito'
alias umount-all='umount-win; umount-saito'
# }}} - MOUNT ----------------------------------------------------------------

return 0
