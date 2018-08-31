# ~/.zprofile: executed by the command interpreter for login shells.
# interactive shell: .zshenv > .zshrc | login shell: .zshenv > .zprofile > zlogin / .zlogout

# {{{ - X WINDOWS ------------------------------------------------------------
# if [[ -n "$${DESKTOP_SESSION-}" ]]; then
#   # load default keyboard layout
#   setxkbmap us -variant colemak
#   # repeat caps lock (colemak backspace)
#   xset r 66 2>/dev/null &!
#   # don't repeat tilde
#   xset -r 49 2>/dev/null &!
#   # ubuntu hack: disable stupid ubuntu shift+backspace -> x terminate
#   xmodmap -e 'keycode 0x16 = BackSpace BackSpace BackSpace BackSpace' 2>/dev/null &!
#   # and add terminate via print button (seldom used) + shift + mod
#   xmodmap -e 'keycode 0x6B = Print Sys_Req Print Terminate_Server Print Sys_Req' 2>/dev/null &!

#   [[ -f "$HOME/.Xresources.d/$(hostname)" ]] \
#     && xrdb -merge $HOME/.Xresources.d/$(hostname)

#   if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
#     export $(gnome-keyring-daemon --start)
#     # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
#     export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
#   fi
# fi
# }}} - X WINDOWS ------------------------------------------------------------
