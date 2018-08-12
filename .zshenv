# ~/.zlogout: executed by zsh(1) initially.
# interactive shell: .zshenv > .zshrc | login shell: .zshenv > .zprofile > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc zlogout shell-script

# {{{ - PATH -----------------------------------------------------------------
PATH="$HOME/bin:/opt/bin:/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin"
PATH+=":/usr/local/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:$PATH"
export PATH
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"
# }}} - PATH -----------------------------------------------------------------

# {{{ - LOCALE ---------------------------------------------------------------
#export LANG=C
export LANG="en_US.UTF-8"
export LC_ALL="en_US.utf8"
export LC="en_US.utf8"
export LESSCHARSET="utf-8"
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"
# }}} - LOCALE ---------------------------------------------------------------

# {{{ - SECURITY -------------------------------------------------------------
export HISTFILE="" # don't create shell history file
export HISTFILESIZE=0 # set shell history to zero
# }}} - SECURITY -------------------------------------------------------------
