# ~/.zsh/aliases-linux.zsh: Linux aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc  shell-script linux

# {{{ = COMMON ===============================================================
# {{{ - GENERAL --------------------------------------------------------------
# LC_COLLATE=C will sort all uppercase before all lowercase
LS_CMD="LC_COLLATE=C ls --color=auto --group-directories-first --time-style=long-iso"
# list all files, long version with human readable file size
alias ls="$LS_CMD -aF"
alias ll="$LS_CMD -aFlh"
# list by modification time (oldest first)
alias lst="$LS_CMD -aFtr"
alias llt="$LS_CMD -aFtrlh"
# list by size (smallest first), long version with allocated space
alias lss="$LS_CMD -aFSr"
alias lls="$LS_CMD -aFSrslh"
# list . files and directories only
alias ls.="$LS_CMD -aFd .*"
alias ll.="$LS_CMD -aFdlh .*"
# list files and grep
alias lsg="ls -a | grep -Ei --color"
alias llg="ls -al | grep -Ei --color"
# }}} - GENERAL --------------------------------------------------------------

# {{{ - SYSTEM ---------------------------------------------------------------
alias fontcache-refresh="sudo fc-cache -f -v"
alias remount-exec="sudo mount -o remount,exec"
# }}} - SYSTEM ---------------------------------------------------------------

# {{{ - NETWORK --------------------------------------------------------------
alias route-newdefault='sudo route delete default; sudo route add default gw'
# }}} - NETWORK --------------------------------------------------------------

# {{{ - MULTIMEDIA -----------------------------------------------------------
#alias tvrec-kill='pkill -f "cat /dev/video0"'
#alias burndvd='growisofs -Z /dev/dvd -R -J'
alias midi-keyboard-output="aconnect \$(aconnect -i \
  | grep -E 'client.*Keystation Mini 32' \
  | sed -r 's/^client ([0-9]+).*/\1/') \$(aconnect -o \
  | grep -E 'client.*FLUID Synth' \
  | sed -r 's/^client ([0-9]+).*/\1/') >/dev/null \
  || printf 'Unable to connect Keystation Midi 32 to FLUYID Synth\n' >&2"
# }}} - MULTIMEDIA -----------------------------------------------------------

# {{{ - MISC -----------------------------------------------------------------
#alias incoming="xterm -fn edges -fb edges -T isdn-incoming -g 100x8+0-63 -e socket bateau 9444 &"
# }}} - MISC -----------------------------------------------------------------
# }}} = COMMON ===============================================================

# {{{ = DISTRIBUTION SPECIFIC ================================================
# {{{ - DEB ------------------------------------------------------------------
if [ -n "`command -v dpkg 2>/dev/null`" ]; then
  alias dgs="dpkg --get-selections"
  alias dca="dpkg --configure -a"
fi

if [ -n "`command -v apt 2>/dev/null`" ]; then
  # until implemented: https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1709603
  alias apd='sudo apt update'
  alias api='sudo apt update; sudo apt install'
  alias apu='sudo apt update; sudo apt upgrade; sudo apt auto-remove'
  alias apuf='sudo apt update; sudo apt full-upgrade; sudo apt auto-remove'
  alias apr='sudo apt remove' # conflicts with ar
  alias apr!='sudo apt purge'
  alias apra='sudo apt auto-remove'
  alias aps='sudo apt search'
  alias apss='sudo apt show'
  alias apl='sudo apt list'
  alias apli='sudo apt list --installed'
fi

if [ -n "`command -v apt-get 2>/dev/null`" ]; then
  alias ag="sudo apt-get"
  #alias agi="sudo apt-get -y install"
  #alias agr="sudo apt-get remove"
  #alias agu="sudo apt-get update"
  #alias agar="sudo apt-get autoremove"
  alias agma="sudo apt-mark markauto"
  #alias agug="sudo apt-get update; sudo apt-get -y upgrade; sudo apt-get autoremove"
  #alias agdu="sudo apt-get update; sudo apt-get -y dist-upgrade; sudo apt-get autoremove"
  # https://askubuntu.com/questions/2389/generating-list-of-manually-installed-packages-and-querying-individual-packages/492343#492343
  alias agsm="comm -23 <(apt-mark showmanual | sort -u) \
                <(gzip -dc /var/log/installer/initial-status.gz \
                    | sed -n 's/^Package: //p' | sort -u)"
fi

if [ -n "`command -v apt-cache 2>/dev/null`" ]; then
  alias ac="apt-cache"
  #alias acs="apt-cache search"
  #alias aci="apt-cache show"
fi

if [ -n "`command -v apt-key 2>/dev/null`" ]; then
  alias apt-key-add="sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys"
fi
# {{{ - DEB ------------------------------------------------------------------

# {{{ - PACMAN ---------------------------------------------------------------
if [ -n "`command -v pacman 2>/dev/null`" ]; then
  alias pmi="sudo pacman -S"
  alias pms="sudo pacman -Ss"
  alias pmr="sudo pacman -Rs"
  alias pmy="sudo pacman -Sy"
  alias pmu="sudo pacman -Syu"
  alias aurb="makepkg"
  alias auri="sudo pacman -U"
  alias aurbui="makepkg && sudo pacman -U *.pkg.tar.xz"
fi
# }}} - PACMAN ---------------------------------------------------------------
# }}} = DISTRIBUTION SPECIFIC ================================================
