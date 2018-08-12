# ~/.zsh/aliases-freebsd.zsh: FreeBSD aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc  shell-script freebsd

# {{{ - GENERAL --------------------------------------------------------------
alias ls='ls -aFG'
alias lsa='ls -alFG'
alias lsh='ls -aFG -h'
alias lsah='ls -alFG -h'
# }}} - GENERAL --------------------------------------------------------------

# {{{ - SYSTEM ---------------------------------------------------------------
alias freebsd-term='TERM="cons25"'
alias ports-list='find /usr/ports -type d -d 2|sed "s/\/usr\/ports\///g"'
alias ports-search='whereis -sa'
alias ports-search-regex='find /usr/ports -type d -d 2|sed "s/\/usr\/ports\///g"|grep -iE'
alias ports-list-descr='find /usr/ports -name pkg-descr|while read p; do echo ---; echo $p|sed "s/\/usr\/ports\///g;s/\/pkg-descr$//g;s/^/* /g"; cat $p; done'
alias ports-update='sudo portsnap fetch update'
alias ports-upgrade='sudo portmaster --no-confirm -a'
alias ports-upgrade-rebuild='sudo portmaster -af'
alias ports-install='sudo portmaster --no-confirm --delete-packages'
alias ports-installpkg='sudo portmaster --no-confirm --delete-packages --always-fetch -P'
alias ports-uninstall='sudo portmaster --no-confirm -e'
alias ports-clean-old-depends='sudo portmaster -s'
alias ports-clean-distfiles='sudo portmaster --clean-distfiles-all'
alias ports-list-installed-bycat='portmaster -l'

alias pkg-search-installed='pkg_info | grep -iE'
# }}} - SYSTEM ---------------------------------------------------------------

# {{{ - MULTIMEDIA -----------------------------------------------------------
alias burn='sudo cdrecord -v -pad speed=24 dev=0,0,0 -eject'
alias burn-blankrw='sudo cdrecord -v dev=0,0,0 blank=fast -eject'
# }}} - MULTIMEDIA -----------------------------------------------------------

# {{{ - NETWORK --------------------------------------------------------------
#alias route-newdefault='sudo route delete default; sudo route add default'
# }}} - NETWORK --------------------------------------------------------------

# {{{ - LINUX SUBSYSTEM ------------------------------------------------------
alias linuxabi='brandelf -t Linux'
# }}} - LINUX SUBSYSTEM ------------------------------------------------------
