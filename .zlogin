# ~/.zlogin: executed by zsh(1) when login shell starts.
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc zlogin shell-script

# {{{ = FINAL LOGIN EXECUTIONS ===============================================
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message (if top-level shell)
if (( $SHLVL == 1 )); then
   print -P "%B%F{white}Welcome to %F{green}%m %F{white}running %F{green}$(uname -srm)%F{white}"
   # on %F{green}#%l%f%b"
   print -P "%B%F{white}Uptime:%b%F{green}$(uptime)%f"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL LOGIN EXECUTIONS ===============================================
