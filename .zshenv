# ~/.zlogout: executed by zsh(1) initially.
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc zshenv shell-script

# {{{ - PATH -----------------------------------------------------------------
export PATH="${HOME}/bin:${HOME}/.local/bin:/opt/bin:/snap/bin"\
":/usr/local/bin:/usr/bin:/bin"\
":/usr/local/sbin:/usr/sbin:/sbin"\
":/usr/bin/X11:/usr/X11R6/bin:/usr/games"\
":/opt/oracle/instantclient_21_4"\
"${PATH:+:${PATH}}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}/usr/local/lib"
# }}} - PATH -----------------------------------------------------------------

# {{{ - LOCALE ---------------------------------------------------------------
#export LANG=C
export LANG="en_US.UTF-8"
export LC_ALL="en_US.utf8"
export LC="en_US.utf8"
export LESSCHARSET="utf-8"
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"
# }}} - LOCALE ---------------------------------------------------------------
