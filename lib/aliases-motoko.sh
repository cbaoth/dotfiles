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

# {{{ - NETWORK --------------------------------------------------------------
# reload the Wi-Fi driver when the card is dead after resume (ath12k bug, see
# docs/troubleshooting/ath12k-resume-failure.md)
alias wifi-driver-reload='sudo modprobe -r ath12k_wifi7 ath12k && sudo modprobe ath12k_wifi7'
# }}} - NETWORK --------------------------------------------------------------

# {{{ - MOUNT ----------------------------------------------------------------
# host specific mount aliases
# requires: ~/lib/functions.sh (__mount_mountpoints)
alias mount-win='__mount_mountpoints /mnt/[c-f]/'
alias umount-win='__mount_mountpoints -u /mnt/[c-f]/'
alias mount-saito='__mount_mountpoints /srv/saito/*/'
alias umount-saito='__mount_mountpoints -u /srv/saito/*/'
alias mount-all='mount-win; mount-saito'
alias umount-all='umount-win; umount-saito'
alias mount-saito-data='sudo mount -t cifs -o username=cbaoth,credentials=/etc/samba/cred-file,uid=cbaoth,gid=cbaoth,file_mode=0777,dir_mode=0777,iocharset=utf8 //saito/data /media/data'
# }}} - MOUNT ----------------------------------------------------------------

return 0
