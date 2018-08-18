#!/bin/bash

[ -z "$1" ] \
  && echo "usage: $(basename $0) [-o] (volume-up|volume-down|play-pause|previous|next)" \
  && exit 1

osd=false
[ "$1" == "-o" ] && { osd=true; shift; }

osd_volume() {
  local vol=$(pactl list sinks | grep '^[[:space:]]Volume:' | head -n 1 | tail -n 1 | sed -e 's,.* \([0-9][0-9]*\)%.*,\1,')
  osdctl -b "Master Volume",$vol
}

osd_mute() {
  local mute=$(pactl list sinks | grep '^\s*Mute:' | head -n 1 | sed 's/.*: //g')
  if [ "$mute" == "yes" ]; then
    osdctl -b "Master Volume: Muted",0
  else
    osd_volume
  fi
}

osd_playstatus() {
  osdctl -s "Player: $(playerctl status)"
}

while [ -n "$1" ]; do
  case "$1" in
    vol+|volume-up)
      pactl set-sink-volume 0 +5%
      $osd && osd_volume
      shift
      ;;
    vol-|volume-down)
      pactl set-sink-volume 0 -5%
      $osd && osd_volume
      shift
      ;;
    mute)
      pactl set-sink-mute 0 toggle
      $osd && osd_mute
      shift
      ;;
    pp|play-pause)
      playerctl play-pause
      $osd && osd_playstatus
      shift
      ;;
    prev|previous)
      playerctl previous
      osdctl -s "Player: Previous Track"
      shift
      ;;
    next)
      playerctl next
      osdctl -s "Player: Next Track"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

exit 0
