# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/lib/aliases-motoko.sh: Host-specific aliases for motoko.

# {{{ - APPS -----------------------------------------------------------------
alias comfyenv="source ~/comfy/venv/bin/activate"  # activate comfy uv venv
alias comfy="command -v comfy-cli >& /dev/null || comfyenv && comfy-cli"  # run comfy-cli while ensuring that comfy env is activated
alias comfyu="comfy update"  # update comfy itself, not the nodes
alias comfyun="comfy node update all"  # update all comfy nodes
alias comfyua="comfyu && comfyun"  # update all of comfy (incl. all nodes)
alias comfyui="comfy launch"  # launch comfy UI
# }}} - APPS -----------------------------------------------------------------

# {{{ - MOUNT ----------------------------------------------------------------
# host specific mount aliases
# requires: ~/lib/functions.sh (__mount_mountpoints)
alias mount-win='__mount_mountpoints /mnt/[c-f]/'
alias umount-win='__mount_mountpoints -u /mnt/[c-f]/'
alias mount-saito='__mount_mountpoints /srv/saito/*/'
alias umount-saito='__mount_mountpoints -u /srv/saito/*/'
alias mount-all='mount-win; mount-saito'
alias umount-all='umount-win; umount-saito'
# }}} - MOUNT ----------------------------------------------------------------

# {{{ - GAMES ----------------------------------------------------------------
alias pob='wine "C:/users/$USER/AppData/Roaming/Path of Building Community/Path of Building.exe"'
alias pob2='wine "C:/users/$USER/AppData/Roaming/Path of Building Community (PoE2)/Path of Building-PoE2.exe"'
alias poeb=pob
alias poe2b=pob2
alias bg3mm='protontricks-launch --appid 1086940 "$HOME/Documents/Games/Baldurs Gate 3/BG3ModManager/BG3ModManager.exe"'
# }}} - GAMES ----------------------------------------------------------------

return 0
