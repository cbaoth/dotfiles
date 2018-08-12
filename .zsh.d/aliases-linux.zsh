# ~/.zsh/aliases-linux.zsh: Linux aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc  shell-script linux

# {{{ = COMMON ===============================================================
# {{{ - GENERAL --------------------------------------------------------------
# LC_COLLATE=C will sort all uppercase before all lowercase
alias ls='LC_COLLATE=C ls --color --all -F --group-directories-first'
alias lsa='LC_COLLATE=C ls --color -all -F --group-directories-first'
alias lsh='LC_COLLATE=C ls --color --all -F -sh'
alias lsah='LC_COLLATE=C ls --color -all -F -h'
alias ls.='LC_COLLATE=C ls -ld --group-directories-first .*'
alias lsg='LC_COLLATE=C ls | grep -Ei --color'
alias lsag='LC_COLLATE=C ls --all | grep -Ei --color'
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
alias midi-keyboard-output="aconnect \`aconnect -i | grep -E 'client.*Keystation Mini 32'| sed -r 's/^client ([0-9]+).*/\1/'\` \`aconnect -o | grep -E 'client.*FLUID Synth'| sed -r 's/^client ([0-9]+).*/\1/'\`"
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

if [ -n "`command -v apt-get 2>/dev/null`" ]; then
  alias ag="sudo apt-get"
  alias agi="sudo apt-get -y install"
  alias agr="sudo apt-get remove"
  alias agu="sudo apt-get update"
  alias agar="sudo apt-get autoremove"
  alias agma="sudo apt-mark markauto"
  alias agug="sudo apt-get update; sudo apt-get -y upgrade; sudo apt-get autoremove"
  alias agdu="sudo apt-get update; sudo apt-get -y dist-upgrade; sudo apt-get autoremove"
  # https://askubuntu.com/questions/2389/generating-list-of-manually-installed-packages-and-querying-individual-packages/492343#492343
  alias agsm="comm -23 <(apt-mark showmanual | sort -u) <(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u)"
fi

if [ -n "`command -v apt-cache 2>/dev/null`" ]; then
  alias ac="apt-cache"
  alias acs="apt-cache search"
  alias aci="apt-cache show"
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
