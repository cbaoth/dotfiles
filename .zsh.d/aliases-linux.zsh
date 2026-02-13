# ~/.zsh/aliases-linux.zsh: Linux aliases
# code: language=zsh insertSpaces=true tabSize=2
# keywords: zsh dotfile zshrc aliases shell shell-script
# author: Andreas Weyer

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
alias hibernate="systemctl hibernate"
alias fsck-ntfs-clear-dirty="sudo ntfsfix --clear-dirty"
# }}} - SYSTEM ---------------------------------------------------------------

# {{{ - NETWORK --------------------------------------------------------------
alias route-newdefault='sudo route delete default; sudo route add default gw'
alias wifi-status='nmcli d wifi list; echo; iw dev wlp2s0 link'
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

# ...
# }}} = NON-NATIVE & CONTAINERIZATION ========================================

# {{{ - V12N & CONTAINERIZATION ----------------------------------------------
# https://en.wikipedia.org/wiki/Virtualization
# https://en.wikipedia.org/wiki/Containerization_(computing)
# ...
# }}} - V12N & CONTAINERIZATION ----------------------------------------------

# {{{ - WINDOWS COMPATIBILITY LAYER ------------------------------------------
# https://en.wikipedia.org/wiki/Compatibility_layer
# http://www.winehq.com
# https://github.com/ValveSoftware/Proton

alias winer='wine start /unix'  # run executable or location (file explorer) using unix path
# }}} - WINDOWS COMPATIBILITY LAYER ------------------------------------------

# {{{ - BINARY TRANSLATION / EMULATION ---------------------------------------
# https://en.wikipedia.org/wiki/Binary_translation
# ...
# }}} - BINARY TRANSLATION / EMULATION ---------------------------------------
# }}} = NON-NATIVE & CONTAINERIZATION ========================================

# {{{ = DISTRIBUTION SPECIFIC ================================================
# {{{ - DEB ------------------------------------------------------------------

if [[ -n "$(command -v dpkg 2>/dev/null)" ]]; then
  alias dpi='sudo dpkg -i' # install .deb package
  alias dpca='sudo dpkg --configure -a' # configure unpackde but on yet configured packages (e.g. continue interrupted upgrade)
  alias dpr='sudo dpkg -r' # remove package (keep config files)
  alias dpr!='sudo dpkg --force-all --purge' # purge package (remove including config files)
  alias dpgs='dpkg --get-selections'
  alias dpl='dpkg -l --no-pager'
  alias dplg='dpl | grep -i --color'
  alias dpli='dpkg --get-selections --no-pager'
  alias dplig='dpli --no-pager | grep -i --color'

  # common aliases with ap(t) prefix
  alias apl=dpl
  alias aplg=dplg
  alias apli=dpli # list installed packages
  alias aplig=dplg
fi

if [[ -n "$(command -v aptitude 2>/dev/null)" ]]; then
  alias aplo='sudo aptitude search \?obsolete' # list obsolete packages
  alias appo='sudo aptitude purge \?obsolete' # purge obsolete packages
fi

if [[ -n "$(command -v apt-get 2>/dev/null)" ]]; then
  alias ag="sudo apt-get"
  alias agi="sudo apt-get -y install" # apt install
  alias agi!='sudo apt-get install -f' # fix broken dependencies for individual packages (vs. dist-upgrade for all, fixes unmet dependencies e.g. for "packages have been kept back")
  alias agiu='sudo apt-get install --only-upgrade' # force upgrade (e.g. for early access to "upgrades have been deferred due to phasing")

  alias agr="sudo apt-get remove" # apt remove
  alias agr!="sudo apt-get purge" # apt purge
  alias agar="sudo apt-get autoremove" # apt auto-remove
  alias agu="sudo apt-get update" # apt update
  alias agug="agu && sudo apt-get -y upgrade && agar" # apt-get update/upgrade/auto-remove
  alias agdu="agu && sudo apt-get -y dist-upgrade && agar" # apt-get update/dist-upgrade/auto-remove
  # https://askubuntu.com/questions/2389/generating-list-of-manually-installed-packages-and-querying-individual-packages/492343#492343

  # common aliases with ap(t) prefix
  alias apud!=agu # force update
  # update cache, but no more than ones per hour (if sucessfull)
  # until implemented: https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1709603
  alias apud='if (( $(( $(date +%s) - $(cat /tmp/last_apt_update 2>/dev/null || echo 0) )) > 3600 )); then
                agu && date +%s > /tmp/last_apt_update
              else
                echo "> last apt update less than an hour ago, skipping (use apud! to force) ..."
              fi'
  alias api='apud && sudo apt-get install'
  #alias api='apud && agi' # alternative: less explicit but shorter
  #alias apiB='apud && sudo apt-get -t buster-backports install'
  alias api!=agi! # fix broken dependencies for individual packages (vs. dist-upgrade for all, fixes unmet dependencies e.g. for "packages have been kept back")
  alias apio=agiu # force upgrade (e.g. for early access to "upgrades have been deferred due to phasing")
  alias apr=agr # apt-get remove
  alias apr!=agr! # apt-get purge
  alias apar=agar # apt-get auto-remove
  alias apu='apud && sudo apt-get -y upgrade && agar'
  alias apu!='agu && sudo apt-get -y upgrade && agar'
  alias apug=agug # apt-get update/upgrade/auto-remove
  alias apdu=agdu # apt-get update/dist-upgrade/auto-remove

  #if [[ -n "$(command -v dpkg 2>/dev/null)" ]]; then
  #  alias apt-fix='dpca; apif'
  #fi
fi

if [[ -n "$(command -v apt-mark 2>/dev/null)" ]]; then
  alias agma="sudo apt-mark markauto"
  alias aglim="comm -23 <(apt-mark showmanual | sort -u) \
                <(gzip -dc /var/log/installer/initial-status.gz \
                    | sed -n 's/^Package: //p' | sort -u)"

  # common aliases with ap(t) prefix
  alias apma=agma # apt-mark markauto
  alias aplim=agsm # list manually installed packages
fi

if [[ -n "$(command -v apt-cache 2>/dev/null)" ]]; then
  alias ac="apt-cache"
  alias acs="apt-cache search"
  alias acsn='apt-cache search --names-only' # search package names only
  alias acsf='apt-cache search --full' # search full text
  #alias acsB='apt-cache -t buster-backports search' # search backports
  alias aci="apt-cache show"

  # common aliases with ap(t) prefix
  alias aps=acs # apt-cache search
  alias apsn=acsn # search package names only
  alias apsf=acsf # search full text
  alias apss=aci # apt-cache show
fi

if [[ -n "$(command -v apt-key 2>/dev/null)" ]]; then
  alias apt-key-add="sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys"
fi
# {{{ - DEB ------------------------------------------------------------------

# {{{ - SNAP -----------------------------------------------------------------
if [[ -n "$(command -v snap 2>/dev/null)" ]]; then
  alias sn='sudo snap'
  alias sns='snap search'
  alias sni='sudo snap install'
  alias snu='sudo snap refresh'
  alias snr='sudo snap remove'
  alias snl='snap list'
  alias snlg='snap list | grep -i --color'
  alias snd='snap info'
  alias snh='snap changes'
fi
# }}} - SNAP -----------------------------------------------------------------

# {{{ - Flatpak --------------------------------------------------------------
if [[ -n "$(command -v flatpak 2>/dev/null)" ]]; then
  alias fp='flatpak'
  alias fps='flatpak search'
  alias fpi='flatpak install'
  alias fpu='flatpak update'
  alias fpr='flatpak uninstall'
  alias fpl='flatpak list'
  alias fplg='flatpak list | grep -i --color'
  alias fpd='flatpak info'
  alias fph='flatpak history'
fi
# }}} - Flatpak --------------------------------------------------------------

# {{{ - PACMAN ---------------------------------------------------------------
if [[ -n "$(command -v pacman 2>/dev/null)" ]]; then
  alias pmi="sudo pacman -S"
  alias pms="sudo pacman -Ss"
  alias pmr="sudo pacman -Rs"
  alias pml="pacman -Q"
  alias pmlg="pacman -Q | grep -i --color"
  alias pmy="sudo pacman -Sy"
  alias pmu="sudo pacman -Syu"
  alias aurb="makepkg"
  alias auri="sudo pacman -U"
  alias aurbui="makepkg && sudo pacman -U *.pkg.tar.xz"
fi
# }}} - PACMAN ---------------------------------------------------------------

# {{{ - PKG (*) --------------------------------------------------------------
# Aliases that combine multiple package managers
# Note: Similarly named aliases may exist for FreeBSD (pkg), this is Linux specific

# pkgu - update package database and upgrade all packages
pkgu() {
  if [[ -n "$(command -v apt 2>/dev/null)" ]]; then
    echo "> Updating and upgrading apt packages (incl. auto-remove) ..."
    apu || echo -e "[\e[33mWARNING:\e[0m Apt update/upgrade failed]"
    echo
  fi
  if [[ -n "$(command -v snap 2>/dev/null)" ]]; then
    echo "> Updating snap packages ..."
    snu || echo -e "[\e[33mWARNING:\e[0m Snap update failed]"
    echo
  fi
  if [[ -n "$(command -v flatpak 2>/dev/null)" ]]; then
    echo "> Updating flatpak packages ..."
    fpu || echo -e "[\e[33mWARNING:\e[0m Flatpak update failed]"
    echo
  fi
  if [[ -n "$(command -v pacman 2>/dev/null)" ]]; then
    echo "> Updating and upgrading pacman packages ..."
    pmu || echo -e "[\e[33mWARNING:\e[0m Pacman update/upgrade failed]"
    echo
  fi
}

# pkgl - list installed packages from all package managers
pkgl() {
  if [[ -n "$(command -v apt 2>/dev/null)" ]]; then
    { dpli || echo -e "[\e[33mWARNING:\e[0m Apt list failed]" } \
      |& sed -r 's/^/apt: /'
    echo
  fi
  if [[ -n "$(command -v snap 2>/dev/null)" ]]; then
    { snl || echo -e "[\e[33mWARNING:\e[0m Snap list failed]" } \
      |& sed -r 's/^/snap: /'
    echo
  fi
  if [[ -n "$(command -v flatpak 2>/dev/null)" ]]; then
    { fpl || echo -e "[\e[33mWARNING:\e[0m Flatpak list failed]" } \
      |& sed -r 's/^/flatpak: /'
    echo
  fi
  if [[ -n "$(command -v pacman 2>/dev/null)" ]]; then
    { pml || echo -e "[\e[33mWARNING:\e[0m Pacman list failed]" }\
      |& sed -r 's/^/pacman: /'
    echo
  fi
}

alias pkglg='pkgl | grep -i --color' # list installed packages from all package managers and grep
# }}} - PKG (*) --------------------------------------------------------------
# }}} = DISTRIBUTION SPECIFIC ================================================

return 0
