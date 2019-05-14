# ~/.zlogin: executed by zsh(1) when login shell starts.
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc zlogin shell-script

# {{{ = FINAL LOGIN EXECUTIONS ===============================================
# {{{ - X WINDOWS ------------------------------------------------------------
# are we in a x-windows session?
if [[ -n "${DESKTOP_SESSION-}" ]]; then
  # is gnome-keyring-daemon availlable? use it as ssh agent
  if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
    export $(gnome-keyring-daemon --start)
    # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
    export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
  fi
fi
# }}} - X WINDOWS ------------------------------------------------------------
# {{{ - DTAG -----------------------------------------------------------------
# enabale dtag (when available)
#(command -v dtags-activate >& /dev/null \
#  && eval "$(dtags-activate zsh)" \
#  || cl::p_war "unable to activate dtags, dtags-activate not found" \
#) &!
# }}} - DTAG -----------------------------------------------------------------
# {{{ - X STUFF --------------------------------------------------------------
#if [[ -n "$DESKTOP_SESSION" ]]; then
#fi
# }}} - X STUFF --------------------------------------------------------------
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message (if top-level shell)
if (( $SHLVL == 1 )); then
   print -P "%B%F{white}Welcome to %F{green}%m %F{white}running %F{green}$(uname -srm)%F{white}"
   # on %F{green}#%l%f%b"
   print -P "%B%F{white}Uptime:%b%F{green}$(uptime)%f"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL LOGIN EXECUTIONS ===============================================
