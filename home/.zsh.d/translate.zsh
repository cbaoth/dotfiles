# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
#
# ~/.zsh.d/translate.zsh: tlde/tlen (translate to German / English), front-end of bin/translate.
#
#   tlde This has * in it         text parsed by the shell; noglob, so * and ? need no escaping
#   tlen -- it's `raw`, ... too   everything after ' -- ' taken literally (raw-line hook, quicknote.zsh)
#   tlde -s fr -- Bonjour         options first, like translate itself
#   tlde                          multi-line prompt (stdin when piped)
#
# Global aliases (`...`) still expand in plain words; use ' -- ' to keep them.
# Sourced after quicknote.zsh: reuses its raw-line hook and multi-line prompt.

_qn_raw_cmds+=(tlde tlen)

# _tl LANG [ARGS...]: plain words without a leading option are the text.
_tl() {
  local target=$1 text
  shift
  if (( $# == 0 )) && [[ -t 0 ]]; then
    _qn_read text "translate to ${target}" || return 1
    print -rn -- "${text}" | translate -t "${target}"
  elif [[ $1 == -* ]]; then
    translate -t "${target}" "$@"
  else
    translate -t "${target}" -- "$@"
  fi
}

# `function NAME` form: the name is not alias-expanded when the file is sourced again.
function tlde { _tl de "$@"; }
function tlen { _tl en "$@"; }
alias tlde='noglob tlde' tlen='noglob tlen'
