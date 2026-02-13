# ~/.zsh/aliases-motoko.zsh: Motoko host aliases
# code: language=zsh insertSpaces=true tabSize=2
# keywords: zsh dotfile zshrc aliases funcions shell shell-script
# author: Andreas Weyer

# {{{ - APPS -----------------------------------------------------------------
alias comfyenv="source ~/comfy-env/bin/activate"
alias comfy="command -v comfy-cli >& /dev/null || comfyenv && comfy-cli"
alias comfyu="comfy update"
alias comfyun="comfy node update all"
alias comfyua="comfyu && comfyun"
alias comfyui="comfy launch"
# }}} - APPS -----------------------------------------------------------------

# {{{ - MOUNT ----------------------------------------------------------------
# Mount and unmount functions and aliases for common mount points, with glob support and color-coded output.
__mount_mountpoints() {
  local do_unmount=false
  if [[ $1 == -u || $1 == --unmount || $1 == unmount ]]; then
    do_unmount=true
    shift
  fi
  if [[ -z "$1" ]]; then
    echo "Usage: __mount_mountpoints [-u|--unmount|unmount] MOUNTPOINTS..." >&2;
    return 1
  fi
  local -a mountpoints expanded
  local -r c_green=$'\e[32m' c_red=$'\e[31m' c_yellow=$'\e[33m' c_reset=$'\e[0m'

  setopt local_options nonomatch no_err_exit
  for arg in "$@"; do
    expanded=(${~arg})
    (( ${#expanded} == 0 )) && expanded=($arg)
    mountpoints+=("${expanded[@]}")
  done

  for m in "${mountpoints[@]}"; do
    if [[ $do_unmount == true ]]; then
      if ! mountpoint -q -- "$m"; then
        printf 'Unmounting: %s ... %sskipped (not mounted)%s\n' "$m" "$c_yellow" "$c_reset" >&2
        continue
      fi
      printf 'Unmounting: %s ...' "$m"
      if umount -- "$m"; then
        printf ' %sdone%s\n' "$c_green" "$c_reset"
      else
        printf '\n%sfailed!%s\n' "$c_red" "$c_reset" >&2
        return 1
      fi
    else
      if mountpoint -q -- "$m"; then
        printf 'Mounting: %s ... %sskipped (already mounted)%s\n' "$m" "$c_yellow" "$c_reset" >&2
        continue
      fi
      printf 'Mounting: %s ...' "$m"
      if mount -- "$m"; then
        printf ' %sdone%s\n' "$c_green" "$c_reset"
      else
        printf '\n%sfailed!%s\n' "$c_red" "$c_reset" >&2
        return 1
      fi
    fi
  done
}
# aliases for the function above, note that in case no mount points are provided, the function usage will be printed
alias mount-mountpoints='__mount_mountpoints'
alias umount-mountpoints='__mount_mountpoints -u'

# host specific mount aliases
alias mount-win='__mount_mountpoints /mnt/[c-f]/'
alias umount-win='__mount_mountpoints -u /mnt/[c-f]/'
alias mount-saito='__mount_mountpoints /srv/saito/*/'
alias umount-saito='__mount_mountpoints -u /srv/saito/*/'
alias mount-all='mount-win; mount-saito'
alias umount-all='umount-win; umount-saito'

# }}} - MOUNT ----------------------------------------------------------------

return 0
