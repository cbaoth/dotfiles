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

# {{{ - SECURITY & PRIVACY ---------------------------------------------------
# private session
#export HISTFILE="" # don't create shell history file
#export SAVEHIST=0 # set shell history file limit to zero
# shared session
export HISTSIZE=10000 # set in-memory history limit
export SAVEHIST=10000 # set history file limit
export HISTFILE="~/.history" # set history file
setopt INC_APPEND_HISTORY # write immediately (default: on exit only)
#setopt HIST_IGNORE_DUPS # don't add duplicates
setopt HIST_IGNORE_ALL_DUPS # delete old entry in favor of new one if duplicate
setopt SHARE_HISTORY # share history between sesions
#setopt EXTENDED_HISTORY # store in ":start:elapsed;command" format
setopt HIST_IGNORE_SPACE # don't record lines stating with a space (privacy)
#setopt HIST_REDUCE_BLANKS # remove unnecessary spaces
#setopt HIST_VERIFY # don't execute immediately after history expansion
setopt HIST_NO_STORE # don't store history / fc commands
setopt HIST_NO_FUNCTIONS # don't store function definitions
# }}} - SECURITY & PRIVACY ---------------------------------------------------
