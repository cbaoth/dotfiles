# ~/.zsh/zshrc-linux_wsl.zsh: Windows Subsystem Linux zshrc

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script linux wsl

# load  weasel-pageant (https://github.com/vuori/weasel-pageant) if available
[[ -f $HOME/weasel-pageant/weasel-pageant ]] \
    && eval $(/$HOME/weasel-pageant/weasel-pageant -r) > /dev/null

# set display (e.g. to use with https://sourceforge.net/projects/vcxsrv/)
export DISPLAY=:0

# enable linger for user 1000 to allow user services to run when not logged in
# this is required for e.g. systemd user services, including podman containers
loginctl enable-linger 1000

return 0
