# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-sway.zsh: SwayWM-specific zsh-only additions.
#
# Shell-agnostic aliases live in ~/lib/aliases-sway.sh (sourced first).
# This file contains only zsh-specific additions.

# {{{ - Sway Tools -----------------------------------------------------------
# (sw)ay (g|s)et (*)info-type [h]uman readable json layout (else: raw json)
if command -v swaymsg >/dev/null 2>&1; then
  _PIPE_CMD="| jq"
  command -v jq >/dev/null 2>&1 || _PIPE_CMD=""
  # with $_PIPE_CMD use doublequotes (unset below, eval on assignment not at runtime)
  alias swgt="swaymsg -t get_tree --raw $_PIPE_CMD"
  alias swgth="swaymsg -t get_tree"
  alias swgw="swaymsg -t get_workspaces --raw $_PIPE_CMD"
  alias swgwh="swaymsg -t get_workspaces"
  alias swgi="swaymsg -t get_inputs --raw $_PIPE_CMD"
  alias swgih="swaymsg -t get_inputs"
  alias swgo="swaymsg -t get_outputs --raw $_PIPE_CMD"
  alias swgoh="swaymsg -t get_outputs"
  alias swgs="swaymsg -t get_seats --raw $_PIPE_CMD"
  alias swgsh="swaymsg -t get_seats"
  alias swgm="swaymsg -t get_marks --raw $_PIPE_CMD"
  alias swgmh="swaymsg -t get_marks"
  alias swgb="swaymsg -t get_bar_config --raw $_PIPE_CMD"
  alias swgbh="swaymsg -t get_bar_config"
  alias swgbm="swaymsg -t get_binding_modes $_PIPE_CMD"
  alias swgbs="swaymsg -t get_binding_state $_PIPE_CMD"
  unset _PIPE_CMD

  alias swgc="swaymsg -t get_config"
  alias swgv="swaymsg -t get_version"
fi

# }}} - Sway Tools -----------------------------------------------------------

return 0
