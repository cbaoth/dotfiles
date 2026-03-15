# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/zshrc-linux_wsl.zsh: WSL-specific zshrc settings.

# load  weasel-pageant (https://github.com/vuori/weasel-pageant) if available
[[ -f $HOME/weasel-pageant/weasel-pageant ]] \
    && eval $(/$HOME/weasel-pageant/weasel-pageant -r) > /dev/null

# set display (e.g. to use with https://sourceforge.net/projects/vcxsrv/)
export DISPLAY=:0

# enable linger for user 1000 to allow user services to run when not logged in
# this is required for e.g. systemd user services, including podman containers
loginctl enable-linger 1000

return 0
