# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/zle-mx.zsh: M-x widget picker (fzf) and zle-keys cheat sheet.
#
#   M-x                   pick any zle widget, Enter runs it (replaces the
#                         built-in execute-named-cmd, which shows names only)
#   C-x C-z               run the last widget picked with M-x again
#   zle-keys [PAT...]     print bound widgets: keys, description, keywords;
#                         rows must match all PATs (case-insensitive)
#   zle-keys -a [PAT...]  the same, unbound widgets included
#
# Every row reads: widget, its keys in the main keymap, a description and
# search keywords, and fzf searches all of them, so `swap` finds
# transpose-chars. Keys are read live from `bindkey`; descriptions of the
# built-in widgets are parsed from `man zshzle` (cached per zsh version) and
# completed by _CB_MX_DESC below. Keywords are synonyms the name lacks: add
# to _CB_MX_KEYWORDS whenever a search comes up empty.
#
# Sourced after the keybindings and plugins in ~/.zshrc, so the M-x binding
# is not reset by `bindkey -e`.

# {{{ = DATA ==================================================================
# Descriptions for widgets the zshzle man page does not cover (plugins, own
# widgets, completion widgets, a few built-ins with an odd man page entry).
typeset -gA _CB_MX_DESC=(
  _cb-edit-command-line     'Edit the line (or the selection only) in Emacs, else $EDITOR.'
  _cb_deactivate_or_break   'Cancel the selection; without one, abort the line.'
  _cb_kill_region_or_word   'Cut the selection; without one, delete the word left.'
  _cb-mx                    'Pick a widget with fzf and run it (this picker).'
  _cb-mx-last               'Run the last widget picked with M-x again.'
  _expand_alias             'Expand the alias under the cursor.'
  _expand_word              'Expand the word under the cursor (globs, variables).'
  _complete_help            'Show the completion context and tags for the current word.'
  _correct_word             'Spelling-correct the current word.'
  _correct_filename         'Spelling-correct the current file name.'
  _history-complete-older   'Complete the current word from older history words.'
  _history-complete-newer   'Complete the current word from newer history words.'
  _most_recent_file         'Insert the most recently modified file name.'
  _list_expansions          'List the possible expansions of the current word.'
  _next_tags                'Cycle completion through the next tag group.'
  _complete_debug           'Complete with a trace of the completion system (debug).'
  _complete_tag             'Complete tags from a tags file (ctags/etags).'
  _read_comp                'Complete from a typed function name or word list.'
  _bash_complete-word       'Complete using bash-style completion functions.'
  _bash_list-choices        'List the bash-style completion choices.'
  zi-browse-symbol          'Browse functions/symbols of the current file (zinit).'
  zi-browse-symbol-backwards   'zi-browse-symbol, searching backwards.'
  zi-browse-symbol-pbackwards  'zi-browse-symbol, previous match backwards.'
  zi-browse-symbol-pforwards   'zi-browse-symbol, previous match forwards.'
  accept-search             'Leave the incremental search, keeping the found line.'
  beep                      'Beep, unless the BEEP option is unset.'
  quoted-insert             'Insert the next key literally, even if it is bound.'
  visual-mode               'Toggle vim-style visual (character-wise) selection.'
  visual-line-mode          'Toggle vim-style visual line-wise selection.'
  edit-command-line         'Edit the line in $EDITOR.'
  autosuggest-accept        'Accept the whole autosuggestion.'
  autosuggest-execute       'Accept the autosuggestion and run it.'
  autosuggest-clear         'Clear the current autosuggestion.'
  autosuggest-toggle        'Toggle autosuggestions on or off.'
  autosuggest-enable        'Enable autosuggestions.'
  autosuggest-disable       'Disable autosuggestions.'
  fzf-history-widget        'Fuzzy-search the command history (fzf).'
  fzf-file-widget           'Insert file or directory path(s) picked with fzf.'
  fzf-cd-widget             'cd into a subdirectory picked with fzf.'
  fzf-completion            'Complete; `**<Tab>` completes with fzf.'
  sudo-command-line         'Toggle sudo in front of the line (or the previous one).'
  dirhistory_zle_dirhistory_back    'cd to the previous directory in the history.'
  dirhistory_zle_dirhistory_future  'cd to the next directory in the history.'
  dirhistory_zle_dirhistory_up      'cd to the parent directory.'
  dirhistory_zle_dirhistory_down    'cd into the first subdirectory.'
)

# Synonyms the widget name and description lack.
typeset -gA _CB_MX_KEYWORDS=(
  accept-line                    'run execute enter submit'
  backward-kill-line             'cut delete erase start'
  backward-kill-word             'cut delete erase'
  beginning-of-line              'home start'
  capitalize-word                'uppercase titlecase'
  clear-screen                   'cls wipe'
  copy-region-as-kill            'copy selection'
  delete-char-or-list            'eof exit logout quit'
  describe-key-briefly           'help binding shortcut what'
  down-case-word                 'lowercase'
  edit-command-line              'editor vim emacs'
  _cb-edit-command-line          'editor emacs vim'
  end-of-line                    'end'
  exchange-point-and-mark        'selection swap other end'
  expand-or-complete             'tab complete'
  fzf-cd-widget                  'directory folder jump change'
  fzf-file-widget                'path find'
  fzf-history-widget             'search find recent commands'
  history-incremental-search-backward 'find search reverse'
  insert-last-word               'previous argument last arg'
  kill-buffer                    'cut delete clear erase'
  kill-line                      'cut delete erase end'
  kill-whole-line                'cut delete clear erase'
  kill-word                      'cut delete erase'
  overwrite-mode                 'insert replace'
  push-line                      'stash save park'
  quote-line                     'escape'
  run-help                       'man manual help documentation'
  send-break                     'abort cancel quit'
  set-mark-command               'select selection region start'
  spell-word                     'correct typo'
  sudo-command-line              'root admin'
  transpose-chars                'swap exchange flip'
  transpose-words                'swap exchange flip'
  undo                           'revert'
  up-case-word                   'uppercase'
  where-is                       'help binding shortcut find'
  which-command                  'where type locate'
  yank                           'paste insert'
  yank-pop                       'paste cycle kill-ring'
  _cb_deactivate_or_break        'abort cancel quit'
  _cb_kill_region_or_word        'cut delete erase'
)

# Internal widgets (hooks, plugin plumbing) left out of the list.
typeset -ga _CB_MX_HIDE=(
  '.*' 'user:*' 'zle-*' '_qn_*' '_cb_cursor_shape' 'orig-*'
  'autosuggest-capture-completion' 'autosuggest-fetch' 'autosuggest-suggest'
  'autosuggest-orig-*' '_zsh_highlight*' 'self-insert*'
)
# }}} = DATA ==================================================================

# {{{ = TABLE =================================================================
# Print "widget<TAB>description" for every widget in `man zshzle`, cached per
# zsh version. A man page entry is one or more 5-space indented headings
# (name, then its default keys), followed by a tab-indented paragraph; the
# first sentence of that paragraph is the description.
_cb_mx_man_desc() {
  emulate -L zsh
  local cache="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/zle-widgets-${ZSH_VERSION}.tsv"
  if [[ ! -s "${cache}" ]]; then
    mkdir -p "${cache:h}"
    MANWIDTH=1000 man zshzle 2> /dev/null | col -b | awk '
      /^     [a-z][a-z0-9-]*( \(.*)?$/ { split($0, a, " "); n[++k] = a[1]; next }
      k && /^[ \t]+[^ \t]/ {
        d = $0; sub(/^[ \t]+/, "", d); gsub(/\t/, " ", d)
        if (match(d, /\. +[A-Z]/)) d = substr(d, 1, RSTART)
        for (i = 1; i <= k; i++) print n[i] "\t" d
        k = 0; next
      }
      { k = 0 }' > "${cache}.tmp" && mv "${cache}.tmp" "${cache}"
  fi
  [[ -r "${cache}" ]] && < "${cache}"
}

# Set REPLY to a readable, Emacs-style name for a `bindkey` key sequence in
# caret notation: "^X^E" -> "C-x C-e", "^[." -> "M-.", "^[[1;5D" -> "C-<left>".
_cb_mx_keyname() {
  emulate -L zsh
  local -A csi=(
    '[A' '<up>' '[B' '<down>' '[C' '<right>' '[D' '<left>'
    'OA' '<up>' 'OB' '<down>' 'OC' '<right>' 'OD' '<left>'
    '[H' '<home>' '[F' '<end>' 'OH' '<home>' 'OF' '<end>'
    '[1~' '<home>' '[7~' '<home>' '[4~' '<end>' '[8~' '<end>'
    '[2~' '<insert>' '[3~' '<delete>' '[5~' '<prior>' '[6~' '<next>'
    '[200~' '<paste>'
  )
  local -A mods=( 2 S- 3 M- 4 M-S- 5 C- 6 C-S- 7 C-M- 8 C-M-S- )
  local k="$1" meta= key seq out=()
  while [[ -n "${k}" ]]; do
    if [[ "${k}" =~ '^\^\[([[O][0-9;]*[A-Za-z~])' ]]; then
      # CSI/SS3 sequence; xterm modifiers: "[1;5D" = "C-" + "[D"
      seq="${match[1]}"; k="${k[$(( 3 + ${#seq} )),-1]}"
      if [[ "${seq}" =~ '^\[1;([2-8])([A-DHF])$' ]]; then
        local mod="${mods[${match[1]}]}" base="[${match[2]}"
        key="${mod}${csi[${base}]}"
      else
        key="${csi[${seq}]:-^[${seq}}"
      fi
      out+=("${meta}${key}"); meta=; continue
    fi
    if [[ "${k}" == '^['* ]]; then
      [[ -n "${meta}" ]] && out+=('ESC')   # ESC ESC: the first one is a key
      meta='M-'; k="${k[3,-1]}"
      continue
    fi
    case "${k}" in
      '^?'*)  key='DEL';   k="${k[3,-1]}" ;;
      '^I'*)  key='TAB';   k="${k[3,-1]}" ;;
      '^M'*)  key='RET';   k="${k[3,-1]}" ;;
      '^@'*)  key='C-SPC'; k="${k[3,-1]}" ;;
      '^'?*)  key="C-${(L)k[2]}"; k="${k[3,-1]}" ;;
      ' '*)   key='SPC';   k="${k[2,-1]}" ;;
      *)      key="${k[1]}"; k="${k[2,-1]}" ;;
    esac
    out+=("${meta}${key}"); meta=
  done
  [[ -n "${meta}" ]] && out+=('ESC')
  REPLY="${(j: :)out}"
}

# Print one row per widget: "widget<TAB>keys<TAB>description<TAB>keywords",
# bound widgets first. -a: include unbound widgets.
_cb_mx_table() {
  emulate -L zsh
  local all=false; [[ "${1-}" == -a ]] && all=true
  local -A keys desc seen
  local line w d sk
  local -a words
  while IFS=$'\t' read -r w d; do desc[${w}]="${d}"; done < <(_cb_mx_man_desc)
  desc+=("${(@kv)_CB_MX_DESC}")
  for line in "${(@f)$(bindkey)}"; do
    [[ "${line}" == \"*\"-\"* ]] && continue   # key ranges (self-insert)
    words=(${(z)line})
    _cb_mx_keyname "${(Q)words[1]}"
    w="${words[-1]}"
    sk="${w} ${REPLY}"
    (( ${+seen[${sk}]} )) && continue   # e.g. <left> is both ^[[D and ^[OD
    seen[${sk}]=1
    keys[${w}]+="${keys[${w}]:+, }${REPLY}"
  done
  local -a bound unbound
  local p hidden
  for w in ${(o)$(zle -la)}; do
    hidden=false
    for p in "${_CB_MX_HIDE[@]}"; do [[ "${w}" == ${~p} ]] && { hidden=true; break; }; done
    ${hidden} && continue
    line="${w}"$'\t'"${keys[${w}]-}"$'\t'"${desc[${w}]-}"$'\t'"${_CB_MX_KEYWORDS[${w}]-}"
    if [[ -n "${keys[${w}]-}" ]]; then bound+=("${line}"); else unbound+=("${line}"); fi
  done
  print -rl -- "${bound[@]}"
  ${all} && print -rl -- "${unbound[@]}"
  return 0
}
# }}} = TABLE =================================================================

# {{{ = COMMANDS ==============================================================
# Print the widget table as aligned columns; see the file header.
zle-keys() {
  emulate -L zsh -o extended_glob
  local -a opt=()
  [[ "${1-}" == -a ]] && { opt=(-a); shift; }
  local row p
  local -a rows=("${(@f)$(_cb_mx_table "${opt[@]}")}")
  for p in "$@"; do rows=(${(M)rows:#(#i)*${p}*}); done
  (( ${#rows} )) || return 1
  local -a f
  for row in "${rows[@]}"; do
    f=("${(@ps:\t:)row}")   # keeps empty fields, unlike read with IFS=<tab>
    printf '%-34s %-22s %s%s\n' "${f[1]}" "${f[2]}" "${f[3]}" "${f[4]:+  [${f[4]}]}"
  done
}

_cb_mx_last=

# M-x: fzf over all widgets (keys, description and keywords are searchable),
# Enter runs the pick, honoring a numeric argument (M-3 M-x ...).
_cb-mx() {
  emulate -L zsh
  if ! (( ${+commands[fzf]} )); then zle execute-named-cmd; return; fi
  local sel
  sel="$(zle-keys -a | fzf --height=50% --layout=reverse --no-multi \
    --prompt='M-x ' --header='Enter: run · Esc: cancel · bound widgets first' \
    --tiebreak=begin,index)"
  zle reset-prompt
  [[ -n "${sel}" ]] || return 0
  _cb_mx_last="${sel%% *}"
  if (( ${+NUMERIC} )); then zle "${_cb_mx_last}" -n "${NUMERIC}"; else zle "${_cb_mx_last}"; fi
}
zle -N _cb-mx

_cb-mx-last() {
  emulate -L zsh
  [[ -n "${_cb_mx_last}" ]] || { zle _cb-mx; return; }
  zle "${_cb_mx_last}"
}
zle -N _cb-mx-last

bindkey '^[x' _cb-mx          # M-x: widget picker (was execute-named-cmd)
bindkey '^x^z' _cb-mx-last    # C-x C-z: repeat the last M-x pick
# }}} = COMMANDS ==============================================================
