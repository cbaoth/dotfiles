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
alias fontcache-refresh="xset fp rehash; sudo fc-cache -f -v"
alias remount-exec="sudo mount -o remount,exec"
alias sleep-enable="sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target"
alias sleep-disable="sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target"
# }}} - SYSTEM ---------------------------------------------------------------

# {{{ - NETWORK --------------------------------------------------------------
alias route-newdefault='sudo route delete default; sudo route add default gw'
# }}} - NETWORK --------------------------------------------------------------

# {{{ - MULTIMEDIA -----------------------------------------------------------
#alias tvrec-kill='pkill -f "cat /dev/video0"'
#alias burndvd='growisofs -Z /dev/dvd -R -J'
alias midi-keyboard-output="aconnect \$(aconnect -i \
  | grep -E 'client.*Keystation Mini 32' \
  | sed -E 's/^client ([0-9]+).*/\1/') \$(aconnect -o \
  | grep -E 'client.*FLUID Synth' \
  | sed -E 's/^client ([0-9]+).*/\1/') >/dev/null \
  || printf 'Unable to connect Keystation Midi 32 to FLUYID Synth\n' >&2"
# }}} - MULTIMEDIA -----------------------------------------------------------

# {{{ - MISC -----------------------------------------------------------------
#alias incoming="xterm -fn edges -fb edges -T isdn-incoming -g 100x8+0-63 -e socket bateau 9444 &"
# }}} - MISC -----------------------------------------------------------------
# }}} = COMMON ===============================================================

# {{{ = DISTRIBUTION SPECIFIC ================================================
# {{{ - DEB ------------------------------------------------------------------

if [[ -n "$(command -v apt 2>/dev/null)" ]]; then
  # force update
  alias apud!='sudo apt update'
  # update cache, but no more than ones per hour (if sucessfull)
  # until implemented: https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1709603
  alias apud='if (( $(( $(date +%s) - $(cat /tmp/last_apt_update 2>/dev/null || echo 0) )) > 3600 )); then
                sudo apt update && date +%s > /tmp/last_apt_update
              else
                echo "> last apt update less than an hour ago, skipping (use apud! to force) ..."
              fi'
  alias api='apud; sudo apt install'
  alias apu='apud; sudo apt upgrade; sudo apt auto-remove'
  alias apuf='apud; sudo apt full-upgrade; sudo apt auto-remove'
  alias apr='sudo apt remove' # conflicts with ar
  alias apr!='sudo apt purge'
  alias apra='sudo apt auto-remove'
  alias aps='apt search'
  alias apss='apt show'
  alias apl='apt list'
  alias apli='apt list --installed'
fi

if [[ -n "$(command -v dpkg 2>/dev/null)" ]]; then
  alias dgs="dpkg --get-selections" # see "apt list --installed" too
  alias dca="dpkg --configure -a"
fi

if [[ -n "$(command -v apt-get 2>/dev/null)" ]]; then
  alias ag="sudo apt-get"
  #alias agi="sudo apt-get -y install" # apt install
  #alias agr="sudo apt-get remove" # apt remove
  #alias agu="sudo apt-get update" # apt update
  #alias agar="sudo apt-get autoremove" # apt auto-remove
  alias agma="sudo apt-mark markauto"
  #alias agug="sudo apt-get update; sudo apt-get -y upgrade; sudo apt-get autoremove" # apt upgrade
  #alias agdu="sudo apt-get update; sudo apt-get -y dist-upgrade; sudo apt-get autoremove" # apt
  # https://askubuntu.com/questions/2389/generating-list-of-manually-installed-packages-and-querying-individual-packages/492343#492343
  alias agsm="comm -23 <(apt-mark showmanual | sort -u) \
                <(gzip -dc /var/log/installer/initial-status.gz \
                    | sed -n 's/^Package: //p' | sort -u)"
fi

if [[ -n "$(command -v apt-cache 2>/dev/null)" ]]; then
  alias ac="apt-cache"
  #alias acs="apt-cache search"
  #alias aci="apt-cache show"
fi

if [[ -n "$(command -v apt-key 2>/dev/null)" ]]; then
  alias apt-key-add="sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys"
fi
# {{{ - DEB ------------------------------------------------------------------

# {{{ - PACMAN ---------------------------------------------------------------
if [[ -n "$(command -v pacman 2>/dev/null)" ]]; then
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
