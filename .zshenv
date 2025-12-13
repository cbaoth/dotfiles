# ~/.zlogout: executed by zsh(1) initially.
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout
#
# https://manpages.ubuntu.com/manpages/bionic//man1/zsh.1.html
# 1. Commands are first read from /etc/zsh/zshenv; this cannot be overridden
# 2. Commands are then read from $ZDOTDIR/.zshenv.
# 3. If the shell is a login shell, commands are read from /etc/zsh/zprofile and then $ZDOTDIR/.zprofile.
# 4. Then, if the shell is interactive, commands are read from /etc/zsh/zshrc and then $ZDOTDIR/.zshrc.
# 5. Finally, if the shell is a login shell, /etc/zsh/zlogin and $ZDOTDIR/.zlogin are read.
#
# https://zsh.sourceforge.io/Intro/intro_3.html
# .zshenv is sourced on all invocations of the shell, unless the -f option is set.
# It should contain commands to set the command search path, plus other important environment variables.
# .zshenv should not contain commands that produce output or assume the shell is attached to a tty.
#
# Author:  cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc zshenv shell-script

# {{{ = ENVIRONMENT (ALL SHELLS) =============================================
# {{{ - ZSH ------------------------------------------------------------------
# If ZDOTDIR is not set, then the value of HOME is used; this is the usual case.
#export ZDOTDIR="$HOME/.zsh"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
# }}} - ZSH ------------------------------------------------------------------

# {{{ - PATHS ----------------------------------------------------------------
export PATH="${HOME}/bin:${HOME}/.local/bin:/opt/bin:/snap/bin"\
":/usr/local/bin:/usr/bin:/bin"\
":/usr/local/sbin:/usr/sbin:/sbin"\
":/usr/bin/X11:/usr/X11R6/bin:/usr/games"\
":/opt/oracle/instantclient_21_4"\
"${PATH:+:${PATH}}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}/usr/local/lib"
# }}} - PATHS ----------------------------------------------------------------

# {{{ - LOCALE ---------------------------------------------------------------
#export LANG=C
export LANG="en_US.UTF-8"
export LC_ALL="en_US.utf8"
export LC="en_US.utf8"
export LC_CTYPE="en_US.UTF-8"
export LESSCHARSET="utf-8"
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"
# }}} - LOCALE ---------------------------------------------------------------

# {{{ - UMASK ----------------------------------------------------------------
# single user system (ubuntu default): go-w
umask 022
# multi user system umask: g-w, o-rwx
#umask 027
# multi user system umask: o-rwx
#umask 007
# }}} - UMASK ----------------------------------------------------------------

# {{{ - ENV STATE ------------------------------------------------------------
export OS="${$(uname 2> /dev/null):l}"
export HOST="${$(hostname 2> /dev/null):l}"

# Is X available? Unreliable for ssh x-forwading., suffi. for local sessions.
export IS_X=false
if [[ ! -t 0 ]] && xset b off >& /dev/null; then
    export IS_X=true
fi
# }}} - ENV STATE ------------------------------------------------------------

# {{{ - DEV ------------------------------------------------------------------
export CLASSPATH=".:$HOME/.class${CLASSPATH+:$CLASSPATH}"
export PYTHONPATH="${PYTHONPATH+:$PYTHONPATH}:$HOME/lib/python/site-packages"
export SCALA_HOME="$HOME/scala"
command -v java >& /dev/null \
  && export JAVA_HOME="${$(realpath $(command -v java))/bin\/java/}"
export ARCH="$(uname -m)"

# Check if we are in the 32bit chroot
#export INCHROOT=0
#if [[ -z "$(mount -l -t ext3 | grep 'on / type')" ]]; then
#if [[ ! -d "/usr/lib64/" ]]; then
#  export DISPLAY=":0"
#  export INCHROOT=1
#  export ARCH=i686
#  # Change prompt color if in chroot
#  export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;32m%}%n%{\e[0m%}@%m]%# ')"
#  # Mount Radeon Shared Memory TMPFS
#  #[ -z "$(mount|grep shm)" ]] && sudo mount /dev/shm/
#  alias cb="cd ~/; su cbaoth"
#fi

# GCC/G++ Optimization Flags
#case $ARCH in
#  x86_64)
#    export CHOST="x86_64-pc-linux-gnu"
#    # amd: k8, opteron, athlon64, athlon-fx
#    # intel: core2 (gcc 4.3+), nocona
#    export CFLAGS="-march=core2 -pipe -O2" # -m64
#    ;;
#  i686)
#    export CHOST="i686-pc-linux-gnu"
#    # amd: athlon, athlon-tbird, athlon-4, athlon-xp, athlon-mp
#    # intel: prescott, pentium4
#    export CFLAGS="-march=prescott -pipe -O2 -fomit-frame-pointer"
#    ;;
#esac
#export CXXFLAGS="${CFLAGS}"
#export MAKEFLAGS="-j5" # -j2 + extra cores (job count)
# }}} - DEV ------------------------------------------------------------------

# {{{ - DBMS -----------------------------------------------------------------
#export ORACLE_SID=XE
#export ORACLE_HOME="/usr/lib/oracle/xe/app/oracle/product/10.2.0/server"
#export PATH="$PATH:$ORACLE_HOME/bin"
# }}} - DBMS -----------------------------------------------------------------

# {{{ - CUSTOM VARIABLES -----------------------------------------------------
# globally raise (but never lower) the default debug level of cl::p_dbg
export DBG_LVL=0
# }}} - CUSTOM VARIABLES -----------------------------------------------------
# }}} = ENVIRONMENT (ALL SHELLS) =============================================

# {{{ = ENVIRONMENT (INTERACTIVE SHELL ONLY) =================================
# {{{ - SHELL TOOLS ----------------------------------------------------------
# Make `less` not strip color coding, if source doesn't strip it (most do
# when pide, but some support e.g. `--color=always`)
export LESS="-R"

# Enable general highlighting in less (if tools available on system)
# https://superuser.com/a/337640
# Note: Ensure that ~/.lessfilter is executable: chmod u+x ~/.lessfilter
[[ -x ~/.lessfilter ]] \
  && command -v pygmentize >& /dev/null \
  && export LESSOPEN="|~/.lessfilter %s"
# Enable auto extraction of zip files (e.g.: less log.gz)
# This supports a custom ~/.lessfilter as well
command -v lesspipe >& /dev/null \
  && eval "$(lesspipe)"
# }}} - SHELL TOOLS ----------------------------------------------------------
# }}} = ENVIRONMENT (INTERACTIVE SHELL ONLY) =================================
