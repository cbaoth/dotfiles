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
# A small vared editor, deliberately NOT a shell prompt: no completion, no
# history, no autosuggestions or highlighting, no alias expansion on Space.
# The keymap starts from the minimal .safe keymap (every key inserts itself)
# plus plain editing keys, all bound to the builtin .widget forms, which the
# plugins' wrappers never touch. Tab inserts a literal tab.
#
# Enter inserts a newline; Ctrl-Enter or Ctrl-D save. Terminals only send a
# distinct Ctrl-Enter when asked (modifyOtherKeys, see _qn_read) and only if
# they support it (foot yes, Termius no), so Ctrl-D is the portable key.
# Alt-Enter deliberately inserts a newline: elsewhere (e.g. chat prompts) it
# means "newline", so it must never save by accident.
_qn_newline() { LBUFFER+=$'\n'; }
zle -N _qn_newline

_qn_keymap() {
  bindkey -l _qn_input &> /dev/null && return 0
  bindkey -N _qn_input .safe
  local -A keys=(
    '^M'          _qn_newline
    '^J'          _qn_newline
    '^[^M'        _qn_newline                 # alt-enter
    '^[[27;5;13~' .accept-line                # ctrl-enter (modifyOtherKeys)
    '^[[13;5u'    .accept-line                # ctrl-enter (kitty/CSI u)
    '^D'          .accept-line
    '^?'          .backward-delete-char
    '^H'          .backward-delete-char
    '^[[3~'       .delete-char
    '^W'          .backward-kill-word
    '^U'          .backward-kill-line
    '^K'          .kill-line
    '^Y'          .yank
    '^A'          .beginning-of-line
    '^E'          .end-of-line
    '^[[H'        .beginning-of-line
    '^[[F'        .end-of-line
    '^[OH'        .beginning-of-line
    '^[OF'        .end-of-line
    '^[[1~'       .beginning-of-line
    '^[[4~'       .end-of-line
    '^[[D'        .backward-char
    '^[[C'        .forward-char
    '^[OD'        .backward-char
    '^[OC'        .forward-char
    '^[[A'        .up-line                    # within the note, not history
    '^[[B'        .down-line
    '^[OA'        .up-line
    '^[OB'        .down-line
    '^[[1;5D'     .backward-word
    '^[[1;5C'     .forward-word
    '^[b'         .backward-word
    '^[f'         .forward-word
    '^[d'         .kill-word
    '^_'          .undo
    '^[[200~'     .bracketed-paste
  )
  local k
  for k in "${(@k)keys}"; do bindkey -M _qn_input "${k}" "${keys[${k}]}"; done
}

# Read a multi-line note into the variable named $1. Ctrl-C cancels.
_qn_read() {
  local _qn_text=''
  # Switch the plugins off for this prompt only (both are re-checked per key).
  local _ZSH_AUTOSUGGEST_DISABLED=1      # zsh-autosuggestions
  local ZSH_HIGHLIGHT_MAXLENGTH=0        # fast-syntax-highlighting
  _qn_keymap
  print -P "%F{8}${2:-note}: Ctrl-Enter / Ctrl-D save, Ctrl-C cancel%f"
  # modifyOtherKeys mode 1 for the duration of the prompt: Ctrl-Enter then
  # arrives as CSI 27;5;13~ instead of a plain \r. Mode 1 (not 2, not the kitty
  # protocol) on purpose: it leaves Ctrl-C/Ctrl-D as the usual control bytes.
  # Inside tmux this also needs `extended-keys on` (~/.tmux.conf).
  print -n '\e[>4;1m' > /dev/tty
  {
    # No prompt string: what you see is exactly what gets saved.
    vared -M _qn_input -p '' _qn_text || return 1
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
