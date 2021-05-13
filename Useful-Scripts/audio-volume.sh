#!/bin/sh
# audio-vol-hotkey.sh

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

usage() {
  echo "usage: `basename $0` [vol%[+/-]|mute|unmute|toggle]"
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
card="$2"
[ -z "$card" ] && card=0
if [ -n "`echo \"$param\"|grep '^\(mute\|unmute\|toggle\)$'`" ]; then
  #_amixer_mute $card "$param"
  _pactl_mute $(echo $param | sed -r 's/^mute/1/;s/^unmute/0/')
elif [ -n "`echo \"$param\"|grep '^\([0-9]\|[1-9][0-9]\|100\)%[+-]\?$'`" ]; then
  #_amixer_volume $card "$param"
  _pactl_volume $(echo $param | sed -r 's/(.*%)([+-]?)$/\2\1/')
else
  usage &&\
    exit 1
fi

exit 0
