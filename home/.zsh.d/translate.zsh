# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
#
# ~/.zsh.d/translate.zsh: tlde/tlen (translate to German / English), front-end of bin/translate;
# tldeF/tlenF translate faithfully (translate -F: keep profanity and insults).
#
#   tlde This has * in it         text parsed by the shell; noglob, so * and ? need no escaping
#   tlen -- it's `raw`, ... too   everything after ' -- ' taken literally (raw-line hook, quicknote.zsh)
#   tlde -s fr -- Bonjour         options first, like translate itself
#   tlde                          multi-line prompt (stdin when piped)
#   tldeF -- Shut the fuck up.    faithful (translate -F), same forms as tlde
#
# Global aliases (`...`) still expand in plain words; use ' -- ' to keep them.
# Sourced after quicknote.zsh: reuses its raw-line hook and multi-line prompt.

_qn_raw_cmds+=(tlde tlen tldeF tlenF)

# _tl LANG MODE [ARGS...]: MODE is -F (faithful) or empty; plain words without a leading option are the text.
_tl() {
  local -a opts=(-t "$1")
  local label="translate to $1" text
  [[ -n $2 ]] && opts+=("$2") label+=" (faithful)"
  shift 2
  if (( $# == 0 )) && [[ -t 0 ]]; then
    _qn_read text "${label}" || return 1
    print -rn -- "${text}" | translate "${opts[@]}"
  elif [[ $1 == -* ]]; then
    translate "${opts[@]}" "$@"
  else
    translate "${opts[@]}" -- "$@"
  fi
}

# `function NAME` form: the name is not alias-expanded when the file is sourced again.
function _tlde { _tl de '' "$@"; }
function _tlen { _tl en '' "$@"; }
function _tldeF { _tl de -F "$@"; }
function _tlenF { _tl en -F "$@"; }
alias tlde='noglob _tlde' tlen='noglob _tlen' tldeF='noglob _tldeF' tlenF='noglob _tlenF'
