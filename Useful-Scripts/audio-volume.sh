#!/bin/env bash
# audio-vol-hotkey.sh

# DEPRECATED: see dotfiles/bin/media-keys instead

# == Description ============================================================
# Toggle mute and change volume of your main sound device using simple commands.
# This script is meant to be used with hotkeys in your wm (e.g. xmonad, fluxbox etc.)
#
# # Example config for fluxbox:
# Mod4 Mod1 plus  :Exec /home/cbaoth/bin/audio-volume 5%+
# Mod4 Mod1 minus :Exec /home/cbaoth/bin/audio-volume 5%-
# Mod4 Mod1 M     :Exec /home/cbaoth/bin/audio-volume toggle
# Mod4 Mod1 0     :Exec /home/cbaoth/bin/audio-volume toggle
# XF86AudioRaiseVolume :Exec /home/cbaoth/bin/audio-volume 5%+
# XF86AudioLowerVolume :Exec /home/cbaoth/bin/audio-volume 5%-

## WORKAROUND (for snd_hda_intel?)
## sometimes muting master also mutes speaker etc., but on master unmute those
## controls are not unmuted again, so we just mute/unmute all those output controls
#MUTE_WORKAROUND=1
##MUTE_WORKAROUND=0

_usage() {
  cat <<!
Usage: $(basename $0) [[+/-]VOL%|mute|unmute|toggle]
Arguments:
  VOL%          set volume to VOL%
  +/-VOL%       increase/decrease volume by VOL %
  VOL%+/-       same as above (deprecated, backward compatibility)
  mute | 1      mute audio
  unmute | 0    unmute audio
  toggle        toggle mute audio

Examples:
  # toggle mute
  $(basename $0) toggle

  # set volume to 100%
  $(basename $0) 100%

  # decrease volume by 10%
  $(basename $0) -10%
!
}

[ -z "$1" ] &&\
  usage &&\
  exit 1

# _amixer () {
#   #for card in 0 1; do
#   amixer -c$1 set $2,0 "$3" |\
#     grep -Ev "^(Available.*|Usage.*|  [a-z-].*|)$" # strip stupid usage stuff on error
# }

# always change volume on master control
# _amixer_volume() {
#   _amixer $1 Master "$2"
# }

# mute/unmute master or all with workaround active (master is reference)
# _amixer_mute() {
#   if [ $MUTE_WORKAROUND -ne 0 ] && [ "$2" = "toggle" ]; then
#     on=0
#     [ -n "`amixer -c$1 sget Master,0 | grep -E 'Playback.*\[on\]'`" ] && on=1
#     for control in Master Speaker Headphone; do
#       _amixer $1 $control `[ $on -eq 1 ] && echo mute || echo unmute`
#     done
#   else
#     for control in Master Speaker Headphone; do
#       _amixer $1 $control "$2"
#     done
#   fi
# }

_pactl () {
  pactl $1 @DEFAULT_SINK@ "$2"
}

_pactl_volume () {
  _pactl set-sink-volume "$1"
}

_pactl_mute () {
  _pactl set-sink-mute "$1"
}

param="$1"
#card="$2"
#[ -z "$card" ] && card=0
if [[ ${param} =~ ^(mute|1|unmute|0|toggle)$ ]]; then
  #_amixer_mute $card "$param"
  _pactl_mute $(echo $param | sed -r 's/^mute/1/;s/^unmute/0/')
elif [[ ${param} =~ ^([+-]?([0-9]|[1-9][0-9]|1[0-9][0-9]|200)%|([0-9]|[1-9][0-9]|1[0-9][0-9]|200)%[+-]?)$ ]]; then
  #_amixer_volume $card "$param"
  _pactl_volume $( echo $param | sed -r 's/(.*%)([+-]?)$/\2\1/' )
else
  _usage &&\
    exit 1
fi

exit 0
