# ~/.zlogout: executed by zsh(1) initially.
# interactive shell: .zshenv > .zshrc | login shell: .zshenv > .zprofile > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc zlogout shell-script

# == VARIABLES ===============================================================
# -- PATHS -------------------------------------------------------------------
export PATH="$HOME/bin:/home/cbaoth/bin:/opt/bin:/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"

# -- DEV ---------------------------------------------------------------------
export CLASSPATH=".:$HOME/.class:$CLASSPATH"
export PYTHONPATH="$PYTHONPATH:$HOME/lib/python/site-packages"
export SCALA_HOME="$HOME/scala"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export ARCH=`uname -m`

# Check if we are in the 32bit chroot
#export INCHROOT=0
#if [ -z "`mount -l -t ext3 | grep 'on / type'`" ]; then
#if [ ! -d "/usr/lib64/" ]; then
#  export DISPLAY=":0"
#  export INCHROOT=1
#  export ARCH=i686
#  # Change prompt color if in chroot
#  export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;32m%}%n%{\e[0m%}@%m]%# ')"
#  # Mount Radeon Shared Memory TMPFS
#  #[ -z "`mount|grep shm`" ] && sudo mount /dev/shm/
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

# -- SHELL -------------------------------------------------------------------
export HISTFILE="" # don't create shell history file
export HISTFILESIZE=0 # set shell history to zero
