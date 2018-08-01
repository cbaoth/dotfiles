# ~/.bashrc: Bash startup file

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: bashrc shell-script

# {{{ Commentary
# ----------------------------------------------------------------------------
# To view this file correctly use fold-mode for emacs and add the following
# line to your .emacs:
#   (folding-add-to-marks-list 'shell-script-mode "# {{{ " "# }}}" nil t)
# ----------------------------------------------------------------------------
# }}} Commentary

# {{{ VARIABLES
# ----------------------------------------------------------------------------
# {{{ variables: paths
# ----------------------------------------------------------------------------
export PATH="$HOME/bin:/home/cbaoth/bin:/opt/bin:/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"
export CLASSPATH=".:$HOME/.class:$CLASSPATH"
#export TEXINPUTS=".:$HOME/tex/sty:/usr/share/texmf/tex/"
#export BSTINPUTS=".:$HOME/tex/sty:/usr/share/texmf/bibtex/"
#export BIBINPUTS=".:$HOME/tex/sty:/usr/share/texmf/bibtex/"
export PYTHONPATH="$PYTHONPATH:$HOME/lib/python/site-packages"
# ----------------------------------------------------------------------------
# }}} variables: path
# {{{ variables: system
# ----------------------------------------------------------------------------
export TERM=xterm-color # rxvt, xterm-color
export COLORTERM=xterm
[ -n "`echo $TERMCAP|grep -i screen`" ] && TERM=screen
export LANG=C
export PS1="\[\e[0;37m\](\w)\[\\033[0;39m\]
[\[\\033[0;34m\]\u\[\\033[0;39m\]@\[\\033[4;38m\]\h\[\\033[0;39m\]]\$ "
export HISTFILE="" # don't create shell history file
export HISTFILESIZE=0 # set shell history to zero
# ----------------------------------------------------------------------------
# }}} variables: system
# {{{ variables: devel
# ----------------------------------------------------------------------------
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"
# ----------------------------------------------------------------------------
# }}} variables: devel
# {{{ variables: misc
# ----------------------------------------------------------------------------
export IRCNICK="cbaoth"
export IRCNAME="Jorus C'Baoth"
#export IRCUSER="cbaoth"
export ORACLE_SID=XE
export ORACLE_HOME="/usr/lib/oracle/xe/app/oracle/product/10.2.0/server"
export PATH="$PATH:$ORACLE_HOME/bin"
export SCALA_HOME="$HOME/scala"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# ----------------------------------------------------------------------------
# }}} variables: misc
# ----------------------------------------------------------------------------
# }}} VARIABLES
# {{{ INCLUDES
# ----------------------------------------------------------------------------
OS=`uname | tr '[A-Z]' '[a-z]'`
[ ! $HOST ] && export HOST=$HOSTNAME

include_ifex () {
  while [ -n "$1" ]; do
    [ -f "$1" ] && . "$1"
    shift
  done
}

# load aliases
include_ifex \
  $HOME/.aliases \
  $HOME/.aliases.$OS \
  $HOME/.aliases.$HOST \
  $HOME/.aliases.$HOST.$OS \
  $HOME/.aliases.bash
#  `cat .aliases | grep -Ev '^\s*#' | sed 's/^alias/alias -g/'`

# load functions
include_ifex \
  $HOME/.functions \
  $HOME/.functions.$OS \
  $HOME/.functions.$HOST \
  $HOME/.functions.$HOST.$OS

# load system/host specific config file (eg: ~/.bashrc.freebsd)
include_ifex \
  $HOME/.bashrc.$OS \
  $HOME/.bashrc.$HOST \
  $HOME/.bashrc.$HOST.$OS
# ----------------------------------------------------------------------------
# }}} INCLUDES
# {{{ EXECUTION
# ----------------------------------------------------------------------------
# ubuntu default: go-w
umask 022
# multi user system umask: g-w, o-rwx
#umask 027
# multi user system umask: o-rwx
#umask 007

#setopt NONOMATCH
rm -f ~/*.core ~/*.dump
# ----------------------------------------------------------------------------
# }}} exec commands
# {{{ exec dtag
# ----------------------------------------------------------------------------
(which dtags-activate 2>&1 >/dev/null \
  && (command -v dtags-activate > /dev/null 2>&1 \
      && eval "`dtags-activate bash`")
  #|| echo "WARNING: unable to activate dtags, dtags-activate not found"
) &
# ----------------------------------------------------------------------------
# }}} exec dtag
# {{{ exec x stuff
# ----------------------------------------------------------------------------
# this should normally not be here, but ... this way its always executed when
# opening a term

# no perfect check since we could e.g. be in an ssh session without
# working / running x, so we start everything in the background
# stupid messages but better timeouts in bg thatn in fg (delay at login)

# TODO: FIND A BETTER SOLUTION< MOVE TO INPUTRC / XINITRC
if [ "$DISPLAY" ]; then
  # repeat caps lock (colemak backspace)
  nohup xset r 66 2>/dev/null &!
  # don't repeat tilde
  #xset -r 49 &
  # ubuntu hack: disable stupid ubuntu shift+backspace -> x terminate
  nohup xmodmap -e 'keycode 0x16 = BackSpace BackSpace BackSpace BackSpace' 2>/dev/null &!
  # and add terminate via print button (seldom used) + shift + mod
  nohup xmodmap -e 'keycode 0x6B = Print Sys_Req Print Terminate_Server Print Sys_Req' 2>/dev/null &!
fi
# --------------------------------------------------------------------------
# }}} exec x stuff
# }}} EXECUTION
# {{{ MOTD
# print welcome message
if [[ $SHLVL -eq 1 ]]; then
   #echo
   #print -P "\e[1;32m Welcome to: \e[1;34m%m"
   #print -P "\e[1;32m Running: \e[1;34m`uname -srm`\e[1;32m on \e[1;34m%l"
   #print -P "\e[1;32m It is:\e[1;34m %D{%r}\e[1;32m on \e[1;34m%D{%A %b %f %G}"
   print -P "\e[1;32mWelcome to \e[1;34m%m\e[1;32m running \e[1;34m`uname -srm`\e[1;32m on \e[1;34m%l"
fi
# ----------------------------------------------------------------------------
# }}} MOTD

