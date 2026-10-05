# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/quicknote.zsh: qn/qne/qnee (notes inbox) and qt/qte (dotfiles TODO), front-end of bin/quicknote.
#
#   qn buy milk                 text parsed by the shell, like any command
#   qn -- it's `e.g.` "raw"     everything after ' -- ' taken literally (see below)
#   qn                          multi-line prompt
#   qne / qnee [DATE]           new note / edit a day's file in $EDITOR
#   qt ... / qte                the same, into the '## Quick Notes' of docs/TODO.md
#
# Sourced after the keybindings and plugins in ~/.zshrc: the input keymap is
# copied from viins, and the line-finish hook must chain with the plugins.

# {{{ = RAW TEXT AFTER ' -- ' =================================================
# By the time a command sees its arguments, the shell has already run the
# backticks and stripped the quotes, and an unbalanced quote (it's) would
# leave the prompt waiting for more input. So the raw line is rewritten
# before zsh parses it: `qn [opts] -- TEXT` becomes `qn [opts] --raw 'TEXT'`.
# History stores the quoted form, which replays the same text (and is not
# rewritten again, since it already contains --raw).
_qn_raw_line() {
  emulate -L zsh
  [[ ${CONTEXT:-} == start ]] || return 0          # not inside vared
  [[ ${BUFFER} == (qn|qt)(|[[:space:]]*)[[:space:]]--(|[[:space:]]*) ]] || return 0
  # %%: longest match from the end = cut at the *first* standalone '--'
  local head="${BUFFER%%[[:space:]]--(|[[:space:]]*)}"
  [[ ${head} == *--raw* ]] && return 0
  local rest="${BUFFER:$(( ${#head} + 3 ))}"
  rest="${rest#[[:space:]]}"
  BUFFER="${head} --raw ${(q+)rest}"
}
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-finish _qn_raw_line
# }}} = RAW TEXT AFTER ' -- ' =================================================

# {{{ = MULTI-LINE PROMPT =====================================================
# A vared keymap where Enter inserts a newline and submitting needs a modified
# Enter. Terminals only send a distinct Ctrl-Enter with modifyOtherKeys or the
# kitty protocol (foot does), so Alt-Enter and Ctrl-D are the portable keys.
_qn_newline() { LBUFFER+=$'\n'; }
zle -N _qn_newline

_qn_keymap() {
  bindkey -l _qn_input &> /dev/null && return 0
  bindkey -N _qn_input viins
  bindkey -M _qn_input '^M'          _qn_newline
  bindkey -M _qn_input '^J'          _qn_newline
  bindkey -M _qn_input '^[[27;5;13~' accept-line   # ctrl-enter (modifyOtherKeys)
  bindkey -M _qn_input '^[[13;5u'    accept-line   # ctrl-enter (kitty/CSI u)
  bindkey -M _qn_input '^[^M'        accept-line   # alt-enter
  bindkey -M _qn_input '^D'          accept-line
}

# Read a multi-line note into the variable named $1. Ctrl-C cancels.
_qn_read() {
  local _qn_text=''
  _qn_keymap
  print -P "%F{8}${2:-note}: Ctrl-Enter / Alt-Enter / Ctrl-D save, Ctrl-C cancel%f"
  # modifyOtherKeys mode 1 for the duration of the prompt: Ctrl-Enter then
  # arrives as CSI 27;5;13~ instead of a plain \r. Mode 1 (not 2, not the kitty
  # protocol) on purpose: it leaves Ctrl-C/Ctrl-D as the usual control bytes.
  # Inside tmux this also needs `extended-keys on` (~/.tmux.conf).
  print -n '\e[>4;1m' > /dev/tty
  {
    vared -M _qn_input -p '%F{cyan}>%f ' _qn_text || return 1
  } always {
    print -n '\e[>4m' > /dev/tty
  }
  : "${(P)1::=${_qn_text}}"
}
# }}} = MULTI-LINE PROMPT =====================================================

# {{{ = COMMANDS ==============================================================
# Plain words without a leading option are the note itself: `qn buy milk`.
_qn() {
  local text
  if (( $# == 0 )); then
    _qn_read text "${_qn_label:-note}" || return 1
    print -rn -- "${text}" | quicknote "${_qn_opts[@]}" --stdin
  elif [[ $1 == -* ]]; then
    quicknote "${_qn_opts[@]}" "$@"
  else
    quicknote "${_qn_opts[@]}" -- "$@"
  fi
}

qn()   { local -a _qn_opts=();          local _qn_label=note; _qn "$@"; }
qt()   { local -a _qn_opts=(-t todo);   local _qn_label=todo; _qn "$@"; }
qne()  { quicknote --edit-new "$@"; }
qnee() { quicknote --edit "$@"; }
qte()  { quicknote -t todo --edit-new "$@"; }

compdef _quicknote qn qt qne qnee qte 2> /dev/null
# }}} = COMMANDS ==============================================================
