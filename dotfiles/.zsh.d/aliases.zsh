# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases.zsh: Zsh-specific aliases.
#
# Shell-agnostic aliases live in ~/.aliases (sourced earlier in .zshrc).
# This file contains only zsh-specific additions: global aliases, suffix
# aliases, and zsh-only convenience aliases.

# {{{ - GENERAL (ZSH ONLY) ---------------------------------------------------
# run-help is a zsh builtin; h and hs are in ~/.aliases
alias /='cd /'  # invalid alias name in bash; zsh only
alias help='run-help'

# Run a shell function as root in a new zsh instance (zsh-only: uses $functions[]).
zsudo() { sudo zsh -c "$functions[$1]" "$@"; }

# Reload shell-agnostic + zsh-specific functions
reload-functions() {
  . $HOME/lib/functions.sh
}

# Reload all alias layers: auto-rehash -> common -> zsh-specific -> os/host
reload-aliases() {
  . $HOME/.zsh.d/auto-rehash.zsh; . $HOME/.aliases; . $HOME/.zsh.d/aliases.zsh;
  source_ifex_custom $HOME/lib/aliases;
  source_ifex_custom -e .zsh $HOME/.zsh.d/aliases
}

# Fix a corrupted zsh history file by extracting printable strings and reloading it.
zsh-history-fix() {
  mv $HOME/.zsh_history $HOME/.zsh_history_corrupt \
    && strings $HOME/.zsh_history_corrupt > $HOME/.zsh_history \
    && fc -R $HOME/.zsh_history \
    && rm $HOME/.zsh_history_corrupt
}
# }}} - GENERAL (ZSH ONLY) ---------------------------------------------------

# {{{ - PLUGIN MANAGEMENT (ZINIT) --------------------------------------------
# Update zinit itself and all plugins. Deliberately NOT run on shell startup —
# invoke manually when you want updates (replaces zplug's on-startup updater).
alias zplugup='zinit self-update && zinit update --all --parallel'
# }}} - PLUGIN MANAGEMENT (ZINIT) --------------------------------------------

# {{{ - SUFFIX ALIASES -------------------------------------------------------
# e.g. 'alias -s txt=vim' makes 'foo.txt' open in vim
#alias -s {txt,ini,conf,html,htm,xml}='vim -N'
#alias -s {com,net,org,de,in}='links2'
# }}} - SUFFIX ALIASES -------------------------------------------------------

# {{{ - GLOBAL ALIASES -------------------------------------------------------
# Global aliases expand anywhere on the command line (zsh only): a bare token
# mid-line becomes its expansion, so `ls ,g foo` -> `ls | grep -E foo`.
#
# Convention: a ',' (comma) prefix. Unshifted and fast to type, and collision-
# proof — a bare ',g' token can never be a real filename or command, unlike a
# bare `G`. fast-syntax-highlighting highlights them so they stay discoverable.
# Documented in docs/reference/zsh.md.
#
# Pattern:  ,<x> = '| <cmd>';  leading e = include stderr (|&);  i = -i (nocase).

# directory walk-up (no prefix; universal, unambiguous)
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'

# pipe to another command
alias -g ,p='|'
alias -g ,ep='|&'                   # include stderr

# redirect to /dev/null
alias -g ,n='> /dev/null 2>&1'      # silence stdout + stderr
alias -g ,en='2> /dev/null'         # silence stderr only

# pipe to stdout + file
alias -g ,t='| tee'
alias -g ,ta='| tee -a'             # append to file (no replace)
alias -g ,et='|& tee'               # include stderr
alias -g ,eta='|& tee -a'           # include stderr and append to file

# page / trim
alias -g ,l='| less'
alias -g ,el='| less'
alias -g ,h='| head'
alias -g ,t='| tail'

# filter
alias -g ,g='| grep -E'
alias -g ,gi='| grep -Ei'
alias -g ,eg='|& grep -E'
alias -g ,egi='|& grep -Ei'
alias -g ,u='| LC_ALL=C  uniq'      # unique lines by byte value (more efficient and predictable)
alias -g ,uc='| LC_ALL=C  uniq -c'  # count unique lines

# sort, count
alias -g ,so='| LC_ALL=C sort'      # sort by byte value (more efficient and predictable)
alias -g ,sor='| LC_ALL=C sort -r'  # reverse sort
alias -g ,sou='| LC_ALL=C sort -u'  # sort unique lines
alias -g ,wc='| wc'
alias -g ,wcl='| wc -l'             # count lines

# xargs
alias -g ,x='| xargs'
alias -g ,x0='| xargs -0'
alias -g ,xl='| tr "\n" "\0" | xargs -0 -n 10000'   # NUL-split, batched xargs

# text transforms
alias -g ,s='| sed -E'
alias -g ,tr='| tr'
alias -g ,tlo="| tr '[:upper:]' '[:lower:]'"
alias -g ,tup="| tr '[:lower:]' '[:upper:]'"
alias -g ,aw='| awk'
alias -g ,sum="| awk '{s+=\$1} END {print s}'"      # sum first column

# code/data processing
alias -g ,j='| jq'                  # jq (default: pretty-print JSON)
alias -g ,pp='| pygmentize'         # pretty-print code

# misc pipelines
alias -g ,mpv='| tr "\n" "\0" | xargs -0 -n 10000 mpv --no-resume-playback'
alias -g ,urlclean="| sed 's/%3a/:/gi; s/%2f/\//gi; s/[?&].*//g; s/%26/&/gi; s/%3d/:/gi; s/%3f/?/gi'"

# }}} - GLOBAL ALIASES -------------------------------------------------------

return 0
