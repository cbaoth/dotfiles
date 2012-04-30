#!/bin/bash
# smfetch.sh

# == Description ============================================================
# A script to fetch rtmp media streams and direct (http) media links from
# individual media libraries (tv stations etc.). It may not be very pretty,
# but it works only with core utilities, awk, wget and rtmpdump.

# == License ================================================================
# Copyright (c) 2012, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

# == Comments, Todo etc. ====================================================
# add additional services
# http://mediathek.daserste.de / http://www.ardmediathek.de

# == Constants & Options ====================================================
declare -r  VERSION="120412"
declare -r  PROG="`basename $0`"
declare -r  DEBUG=0               # set to >0 to increase debug level
declare -r  UAGENT="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517 Mozilla Firebird/0.6"

# -- static settings and commands -------------------------------------------
declare -r  RTMPDUMP="rtmpdump"   # change if not in path or name different
#declare -ra RTMPDUMP_CMD=($RTMPDUMP -e) # "-e" to always try resuming
# no longer supported, -e is not a good idea in most cases, file will
# always be overwritten in non interactive mode
declare -ra RTMPDUMP_CMD=($RTMPDUMP)

declare -r  WGET="wget"           # change if not in path or name different
# wget should not be quiet if debuging
if [ $DEBUG -gt 0 ]; then
  declare -ra WGET_CMD=($WGET -U "$UAGENT")
else
  declare -ra WGET_CMD=($WGET -U "$UAGENT" -q)
fi

# known services
declare -ra SERVICES=(3sat ard arte zdf youtube)

# recode (replace html entities in output file name, if recode is installed)
declare -r RECODE_MODE="html..ascii"        # no umlauts etc.
#declare -r RECODE_MODE="html..ISO-8859-1"   # including umlauts

# default exit status (will be changed in case of error)
EXIT_STATUS=0

# -- default options --------------------------------------------------------
# start in interactive mode?
# yes -> overwrite existent files without query etc.
declare -r  INTERACTIVE=0
#declare -r  INTERACTIVE=1

# keep meta data file, don't delete it after download
#declare -ri KEEP_META=0
declare -ri KEEP_META=0

# default language (depends on service, eg. arte: de/fr)
declare -r  LANG="de"
#declare -r  LANG="fr"

# quality, highest = 1, lowest = N>1 (depends on service)
# note: if quality id is not available for the current service, the lowest
#       possible quality will be used
declare -ri  QUALITY=1

# -- youtube specialties ---------------------------------------------------
# available youtube qualities, availability checked in the given sequence
#5 6 34 35 18 22 37 38 83 82 85 84 43 44 45 46 100 101 46 102 13 17)
declare -ra YT_AVQUAL=(38
                       37
                       46
                       22
                       45
                       35
                       44
                       18
                       34
                       43
                       6
                       5
                       84
                       102
                       46
                       85
                       101
                       82
                       100
                       83
                       17
                       13)
# flv_h263_224p flv_h263_270p flv_h264_360p flv_h264_480p mp4_h264_360p	mp4_h264_720p mp4_h264_1080p mp4_h264_2304p
# mp4_h264_3d_240p mp4_h264_3d_360p mp4_h264_3d_520p mp4_h264_3d_720p webm_vp8_360p webm_vp8_480p webm_vp8_720p
# webm_vp8_1080p webm_vp8_3d_360p webm_vp8_3d_480p webm_vp8_3d_540p webm_vp8_3d_720p 3gp_mp3v_lq 3gp_mp3v_hq
declare -ra YT_AVQUALNAME=(mp4_h264_2304p
                           mp4_h264_1080p
                           webm_vp8_1080p
                           mp4_h264_720p
                           webm_vp8_720p
                           flv_h264_480p
                           webm_vp8_480p
                           mp4_h264_360p
                           flv_h264_360p
                           webm_vp8_360p
                           flv_h263_270p
                           flv_h263_224p
                           mp4_h264_3d_720p
                           webm_vp8_3d_720p
                           webm_vp8_3d_540p
                           mp4_h264_3d_520p
                           webm_vp8_3d_480p
                           mp4_h264_3d_360p
                           webm_vp8_3d_360p
                           mp4_h264_3d_240p
                           3gp_mp3v_lq
                           3gp_mp3v_hq)
# default quality: 1080p H.264 mp4

# == Initial stuff ==========================================================
# -- Aux functions ----------------------------------------------------------
# print a message "usage: [msg].."
prt_msg() { echo -e "> $*"; return 0; }
# print error message in format "ERROR: [msg].."
prt_err() { echo -e "ERROR: $*" >&2; EXIT_STATUS=1; return 0; }
# print error message in format "ERROR: [msg].."
prt_warn() { echo -e "WARNING: $*" >&2; return 0; }
# print debug message in format "DEBUG: [msg].." where debug level must fit:
# prt_dbg [show_at_lvl] [msg]..
prt_dbg() { [ $DEBUG -ge $1 ] && shift && echo -e "DEBUG: $*"; return 0; }

# check if executable is available
app_available() {
  if !(which "$1" 2>&1 > /dev/null); then
    prt_err "The required executable '$1' doesn't seem to be installed or in path."\
        "\nPlease install it correctly or change the appropriate constant in '$PROG'."
    return 1
  fi
  return 0
}

isint() { # may not contain .
  [ -z "$1" ] && return 0
  [ -n "`echo $1 | egrep \"^[-]?[0-9]+$\"`" ] && \
    return 0
  return 1
}

yesno_p() {
  [ -z "$1" ] && prt_msg "usage: yesno_p question" && return 1
  sh="`basename $SHELL`"
  key=""
  printf "$* (y/n) "
  while [ "$key" != "y" ] && [ "$key" != "n" ]; do
    #if [ "$sh" = "zsh" ]; then
    #  read -s -k 1 key
    #else
      read -s -n 1 key
    #fi
  done
  echo
  if [ "$key" = "y" ]; then
    return 0
  fi
  return 1
}

overwrite_p() {
  if [ -e "$1" ]; then
    echo "file '$1' exists!"
    if yesno_p "overwrite?"; then
      rm -rf "$1"
      return 0
    fi
    return 1
  fi
}

# -- Requirements -----------------------------------------------------------
app_available $RTMPDUMP || exit 1
app_available $WGET || exit 1

# -- Usage and Args ---------------------------------------------------------
usage() {
  cat <<USAGE
Usage: $PROG [options] id(s)
Version: $VERSION

IDs can be either video page url or just the video's id (see "Supported
Services" for details on the individual id pattern). In the latter case
a service has to be selected (using -s) since it can't be identified
automatically by the id alone.

Options:
  -h, --help              print this usage screen
  -s, --service SERV      select the desired service. required if ids are
                            given instead of urls.
  -l, --language LANG     language to use. if the given language is not
                            availlable the individual service fallback will
                            be used. (default: $LANG)
  -q, --quality QUALITY   quality [1-N] where 1 is highest and N>1 is lowest.
                            lowest quality depends on service, if the given
                            quality value is out of range (value too high)
                            the lowest quality for the current service is
                            used. (global default: $QUALITY)
  -o, --outfile FILE      set output file name (only for single downloads,
                            not usable if multiple ids are given)
  -op, --outfileprefix X  specify a prefix for the automaticly generated
                            output file name(s).
  -os, --outfilesuffix X  specify a suffix for the automaticly generated
                            output file name(s).
  -i, --interactive       start in interactive mode `[ $INTERACTIVE -eq 1 ] && printf "(default)"`
  -n, --noninteractive    don't ask any questions, answer everything with YES
                            NOTE: existing files will be overwritten without
                            hesitation `[ $INTERACTIVE -ne 1 ] && printf "(default)"`
  -dm, --deletemetafile   delete meta file after download is finished `[ $KEEP_META -ne 1 ] && printf "\n%27s(default)"`
  -km, --keepmetafile     don't delete meta file after download is finished `[ $KEEP_META -eq 1 ] && printf "\n%27s(default)"`

Supported Services (example URLs/Ids, availlable options):
  youtube url: http://www.youtube.com/?v=XXXXXXXXXXX
            -> id = XXXXXXXXXXX
          lang: *, quality: special, see: $PROG --help-youtube-qualities
  3sat    url: http://www.3sat.de/mediathek/mediathek.php?obj=12345
            -> id = 12345
          lang: de, quality: 1-3 [veryhigh, high, low]
  ard     url: http://www.ardmediathek.de/*/content/12345?documentId=23456
          -> id = CURRENTLY URL ONLY
          lang: de, quality: 1-3 [high, medium, low]
          quality=3 may be mp3 and 1-2 may be direct mp4 media links
  arte    url: http://videos.arte.tv/de/videos/show_one-12345.html
            -> id = show_one-12345
          lang: de/fr, quality: 1-2 [hd, sd]
  zdf     url: http://www.zdf.de/ZDFmediathek/.../video/12345/Show-X
            -> id = 12345
          lang: de, quality: 1-3 [veryhigh, high, low]

Examples:
  simplest case, fetch given video by url
    $PROG http://www.3sat.de/mediathek/mediathek.php?obj=12345
  fetch multiple videos by id from zdf in low quality
    $PROG -s zdf -q 3 12345 23456 34567
USAGE
}

youtube_qualities() {
  echo "available youtube qualities:"
  for i in `seq 0 $((${#YT_AVQUALNAME[@]}-1))`; do
    echo -e "  ${YT_AVQUAL[$i]}\t-> ${YT_AVQUALNAME[$i]}" | sed 's/_/ /g'
  done
  echo
  echo "note: if no quality is given, the shown sequence is tried (one quality after another)"
}

# initialize changeable options
o_service=""
o_keepmeta=$KEEP_META
o_interactive=$INTERACTIVE
o_quality=$QUALITY
o_language="$LANGUAGE"
o_outfile=""
o_outfilepre=""
o_outfilesuf=""
# parse arguments
while [ -n "$1" ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --help-youtube-qualities)
      youtube_qualities
      exit 0
      ;;
    -s|--service)
      [ -z "$2" ] &&\
        prt_err "parsing args, no value given for $1" && exit 1
      case "${SERVICES[@]}" in
        *"$2"*) o_service="$2";;
        *)      prt_err "parsing args, unknown service '$2'" && exit 1;;
      esac
      shift 2
      prt_dbg 1 "args | enforcing service: $o_service"
      ;;
    -l|--language)
      [ -z "$2" ] &&\
        prt_err "parsing args, no value given for $1" && exit 1
      o_lang="$2"
      shift 2
      prt_dbg 1 "args | setting language: $o_lang"
      ;;
    -q|--quality)
      [ -z "$2" ] &&\
        prt_err "parsing args, no value given for $1" && exit 1
      (!(isint $2) || [ ${#2} -gt 1 ]) &&\
        prt_err "parsing args, value given for $1 must be a one digit positive integer"
      o_quality="$2"
      shift 2
      prt_dbg 1 "args | setting quality: $o_quality"
      ;;
    -o|--outfile)
      [ -z "$2" ] &&\
        prt_err "parsing args, no value given for $1" && exit 1
      o_outfile="$2"
      shift 2
      prt_dbg 1 "args | setting output file name: $o_outfile"
      ;;
    -op|--outfileprefix)
      [ -z "$2" ] &&\
        prt_err "parsing args, no value given for $1" && exit 1
      o_outfilepre="$2"
      shift 2
      prt_dbg 1 "args | setting output file prefix: $o_outfilepre"
      ;;
    -os|--outfilesuffix)
      [ -z "$2" ] &&\
        prt_err "parsing args, no value given for $1" && exit 1
      o_outfilesuf="$2"
      shift 2
      prt_dbg 1 "args | setting output file prefix: $o_outfilesuf"
      ;;
    -i|--interactive)
      o_interactive=1
      shift
      prt_dbg 1 "args | interactive mode: on"
      ;;
    -n--noninteractive)
      o_interactive=0
      shift
      prt_dbg 1 "args | interactive mode: off"
      ;;
    -km|--keepmetafile)
      o_keepmeta=1
      shift
      prt_dbg 1 "args | keep metafile: on"
      ;;
    -dm|--deletemetafile)
      o_keepmeta=0
      shift
      prt_dbg 1 "args | keep metafile: off"
      ;;
    *)
      break;  # we assume that ids/urls follow at this point
      ;;
  esac
done

# -- Some additional checks -------------------------------------------------
# not enough arguments?
[ -z "$1" ] && prt_err "paring args, no ids/urls given\ntry '$PROG --help' for details on usage" && exit 1

# out file name given but multiple downloads?
[ -n "$o_outfile" ] && [ $# -gt 1 ] &&\
  prt_err "parsing args, outfile (-o) can only be used for single downloads" && exit 1


# == Core Functionality =====================================================
# fetch_rtmp TARGET URI
fetch_rtmp() {
  prt_dbg 1 "rtmp | $2\n  -> $1"
  prt_msg "target file: $l_outfile"
  [ $o_interactive -eq 1 ] && !(overwrite_p "$1") && return 0
  ${RTMPDUMP_CMD[@]} -o "$1" -r "$2"
}

# fetch_media TARGET URI
fetch_media() {
  prt_dbg 1 "media | $2\n  -> $1"
  prt_msg "target file: $l_outfile"
  [ $o_interactive -eq 1 ] && !(overwrite_p "$1") && return 0
  "${WGET_CMD[@]}" -O "$1" "$2"
}

# generate output file name, change to your liking
out_file_name() {
  local l_result

  local l_recode=0
  app_available recode && l_recode=1

  # if outfile is given, use it and return
  if [ -n "${o_outfile}" ]; then
    l_result="${o_outfile%.*}"  # remove extension
    # add prefix and suffix if set
    [ -n "$o_outfilepre" ] && l_result="$o_outfilepre$l_result"
    [ -n "$o_outfilesuf" ] && l_result="$l_result$o_outfilesuf"
    # re-append extension (if any)
    echo "$o_outfile" | grep '\.' 2>&1 > /dev/null \
      && l_result="$l_result.${o_outfile##*.}"
    l_result="`echo $l_result | sed 's/%26.*//g' | sed -r 's/%([0-9A-F][0-9A-F])/\\\\\\\\x\1/g'`"
    [ $l_recode -eq 1 ] && l_result="`echo $l_result | recode -f $RECODE_MODE`"
    echo $l_result; return 0
  elif [ -n "${l_outfile}" ]; then
    l_result="`echo $l_result | sed 's/%26.*//g' | sed -r 's/%([0-9A-F][0-9A-F])/\\\\\\\\x\1/g'`"
    [ $l_recode -eq 1 ] && l_result="`echo $l_result | recode -f $RECODE_MODE`"
    echo $l_result; return 0
  fi

  # if no file name is given, generate one
  # cleanup id, if it represents an url
  local l_tempid="`basename $l_id`"
  l_tempid="${l_tempid//[=&?]/-}"

  # use local variables of processors (not nice, but within scope)
  if [ -n "${l_title}" ]; then
    l_result="`echo $l_title | tr 'A-Z' 'a-z'` [${l_service}, ${l_tempid}]"
  elif [ -n "${l_orgfilename}" ]; then
    l_result="${l_orgfilename} [${l_service}, ${l_tempid}]"
  else
    l_result="${l_service} ${l_tempid}"
  fi

  # there is no known extension?
  if [ -z "$l_ext" ]; then
    prt_warn "proc | can't determine extension, using .dat"
    l_ext="dat"
  fi

  # add prefix and suffix if set
  [ -n "$o_outfilepre" ] && l_result="$o_outfilepre$l_result"
  [ -n "$o_outfilesuf" ] && l_result="$l_result$o_outfilesuf"

  # add file extension
  l_result="$l_result.${l_ext}"

  #echo $l_result | tr 'A-Z' 'a-z' | tr ' :!"' '_'
  l_result="`echo $l_result | tr ' :!\"' '_' | sed 's/%26.*//g' | sed -r 's/%([0-9A-F][0-9A-F])/\\\\\\\\x\1/g'`"
  [ $l_recode -eq 1 ] && l_result="`echo $l_result | recode -f $RECODE_MODE`"
  echo $l_result; return 0
}

# generate meta file name, same as with out_file_name
meta_file_name() {
  # cleanup id, if it represents an url
  local l_tempid="`basename $l_id`"
  l_tempid="${l_tempid//[=&?]/-}"
  echo ".$l_service $l_tempid`[ -n \"$1\" ] && echo \" $1\"`.xml" |\
    tr ' :!"' '_'
    #tr 'A-Z' 'a-z' | tr ' :!"' '_'
}

# core_processor SERVICE OBJ
# not very nice to use local variables in child functions, but ...
core_processor() {
  #[ -z "$2" ] && prt_err "core_processor: not enough arguments!" return 1
  local l_service="$1"
  local l_obj="$2"
  local l_id l_lang l_quality l_rtmp l_media
  local l_metafile l_outfile l_orgfilename l_outfile

  # call service processor
  process_$service "$obj" \
    || return 1

  l_outfile="`out_file_name`"

  # fetching rtmp stream or direct media link
  if [ -n "$l_rtmp" ]; then
    fetch_rtmp "$l_outfile" "$l_rtmp" \
      || return 1
  elif [ -n "$l_media" ]; then
    fetch_media "$l_outfile" "$l_media" \
      || return 1
  else
    prt_err "neither rtmp uri nor direct media link found" \
      && return 1
  fi

  # remove meta file if desired
  [ $o_keepmeta -ne 1 ] && rm -f "$l_metafile"

  return 0
}

# == Service Processors =====================================================
process_3sat() {
  # select lowest available quality if given quality not available (too high)
  local l_lowestquality=3
  if [ $o_quality -gt $l_lowestquality ]; then
    prt_warn "quality $l_quality not availlable (too high), new quality: "
    o_quality=$l_lowestquality
  fi

  # get id (if url was given)
  l_id="`basename $l_obj`"
  l_id="${l_id/*obj=/}"
  l_id="${l_id/&*/}"
  prt_dbg 1 "$l_service | id = $l_id"

  # check for valid id
  ([ -z "$l_id" ] || !(isint "$l_id")) && prt_err "no a valid id found" \
    && return 1

  # fetch meta file
  l_lang=de  # no other options
  l_metafile="`meta_file_name`"
  prt_dbg 1 "$l_service | fetching meta file, lang = $l_lang, meta file = $l_metafile"
  "${WGET_CMD[@]}" -O - "http://www.3sat.de/mediathek/mediathek.php?obj=$l_id&mode=play" |\
    grep -Ei "playerBottomFlashvars.mediaURL" |\
    sed -r 's/.*=\s*"([^"]+)".*/\1/' | head -1 |\
    xargs "${WGET_CMD[@]}" -O "$l_metafile" \
      || return 1

  case $o_quality in
    1) l_quality="veryhigh";;
    2) l_quality="high";;
    *) l_quality="low";;
  esac;
  # parse meta file
  prt_dbg 1 "$l_service | parsing meta file, quality = $l_quality"
  local l_ppath="`cat \"$l_metafile\" |\
    grep -iE -B1 \"name=.quality.*value=.$l_quality\" | head -1 |\
    sed -r 's/.*src=.//;s/\".*//'`"
  local l_host="`cat \"$l_metafile\" | grep -i 'name=\"host\"' |\
    sed 's/.*value=\"//;s/\".*//'`"
  local l_app="`cat \"$l_metafile\" | grep -i 'name=\"app\"' |\
    sed 's/.*value=\"//;s/\".*//'`"
  #l_title=""
  echo $l_ppath
  echo $l_host
  echo $l_app
  # rtmp[t][e]://hostname[:port][/app[/playpath]]
  l_rtmp="rtmp://$l_host:1935/$l_app/$l_ppath"
  l_orgfilename="`basename $l_ppath`"
  l_ext="${l_orgfilename##*.}"
}

process_ard() {
  # select lowest available quality if given quality not available (too high)
  local l_lowestquality=3
  if [ $o_quality -gt $l_lowestquality ]; then
    prt_warn "quality $l_quality not availlable (too high), new quality: "
    o_quality=$l_lowestquality
  fi

  # get id (if url was given)
  # CURRENTLY ONLY URL SUPPORTED
  l_id="$l_obj"
  #l_id="${l_obj/*content/}"
  #l_id="${l_id/*documentId=/}"
  prt_dbg 1 "$l_service | id = $l_id"

  # check for valid id
  #([ -z "$l_id" ] || !(isint "$l_id")) && prt_err "no a valid id found" \
  #  && return 1

  # fetch meta file
  l_lang=de  # no other options
  l_metafile="`meta_file_name`"
  prt_dbg 1 "$l_service | fetching meta file, lang = $l_lang, meta file = $l_metafile"
  "${WGET_CMD[@]}" -O "$l_metafile" "$l_id" \
    || return 1
  l_quality="$(awk '{print ($0>=3?0:3-$0)}' <<<$o_quality)"
  # parse meta file
  prt_dbg 1 "$l_service | parsing meta file, quality = $l_quality"
  # try to get desired / default quality first
  local l_metainfo="`cat \"$l_metafile\" | grep -E \"addMediaStream\([^,]*,\s*$l_quality\"`"
  # not found? check for other qualities
  local l_idx=3;
  if [ -z "$l_metainfo" ]; then
    prt_warn "media not found in given / default quality: $o_quality ($QUALITY)"
    prt_warn "checking media in all possible qualities (highest first) ..."
    while [ -z "$l_metainfo" ] && [ $l_idx -ge 0 ]; do
      l_idx=$((l_idx-1))
      l_quality=$l_idx
      l_metainfo="`cat \"$l_metafile\" | grep -E \"addMediaStream\([^,]*,\s*$l_quality\"`"
    done
    if [ -z "$l_metainfo" ]; then
      prt_err "no media found, tried qualities 1-3"
      return 1
    else
      prt_msg "media found in quality: $((3-l_idx)) ($l_idx)"
    fi
  fi
  case "$l_metainfo" in
    *"rtmp"*)
      prt_msg "$l_service: media type: rtmp"
      l_mediainfo="`echo $l_mediainfo | grep rtmp | head -1`"
      local l_base="$(awk -F'[\",\"]' '{print $4}' <<<$l_metainfo)"
      local l_path="$(awk -F'[\",\"]' '{print $7}' <<<$l_metainfo)"
      local l_app="${l_path/*mediathek=/}"
      if [ "$l_path" = "$l_app" ]; then
        l_rtmp="$l_base$l_path"
      else
        l_rtmp="$l_base${l_app/[&;]*/}/${l_path/\?*/}"
      fi
      ;;
    *".mp4"*)
      prt_msg "$l_service: media type: mp4 direct media link"
      l_mediainfo="`echo $l_mediainfo | grep mp4 | head -1`"
      l_media="$(awk -F'[\",\"]' '{print $7}' <<<$l_metainfo)"
      ;;
    *".mp3"*)
      prt_msg "$l_service: media type: mp3 direct media link"
      l_mediainfo="`echo $l_mediainfo | grep mp3 | head -1`"
      l_media="$(awk -F'[\",\"]' '{print $7}' <<<$l_metainfo)"
      ;;
  esac
  l_title="`cat \"$l_metafile\" | awk -F '[<>]' '/<title>/{print $3}' | sed -r 's/[^-]* - //;s/ \|.*//g'`"
  #l_orgfilename="`basename $l_ppath`"
  #l_ext="${l_orgfilename##*.}"
  l_ext="mp4"    # currently only mp4 streams are known
}

process_arte() {
  # select lowest available quality if given quality not available (too high)
  local l_lowestquality=2
  if [ $o_quality -gt $l_lowestquality ]; then
    prt_warn "quality $l_quality not availlable (too high), new quality: "
    o_quality=$l_lowestquality
  fi

  # get id (if url was given)
  l_id="`basename ${l_obj%.*}`"
  prt_dbg 1 "$l_service | id = $l_id"

  # check for valid id (simple)
  [ -z "$l_id" ] && prt_err "no a valid id found" \
    && return 1

  # fetch meta file
  l_lang=`case $o_lang in de|fr) echo $o_lang;; *) echo de;; esac`
  l_metafile="`meta_file_name`"
  prt_dbg 1 "$l_service | fetching meta file, lang = $l_lang, meta file = $l_metafile"
  "${WGET_CMD[@]}" -O - "http://videos.arte.tv/de/do_delegate/videos/${l_id},view,asPlayerXml.xml" |\
    grep -Ei "lang=.?$LANG" | sed -r 's/.*ref="([^>]+)".\s*\/>.*/\1/' |\
    head -1 | xargs "${WGET_CMD[@]}" -O "$l_metafile" \
      || return 1

  l_quality=`[ $o_quality -eq 1 ] && echo hd || echo sd`
  # parse meta file
  prt_dbg 1 "$l_service | parsing meta file, quality = $l_quality"
  #l_title=""
  l_rtmp="`cat \"$l_metafile\" | grep -iE \"quality=.${l_quality}\" | head -1 | sed -r 's/^[^>]+*>//g;s/<.*//g'`"
  #l_orgfilename=""
  #l_ext="${l_rtmp##*.}"
  l_ext="mp4"    # currently only mp4 streams are known
}

process_zdf() {
  # select lowest available quality if given quality not available (too high)
  local l_lowestquality=3
  if [ $o_quality -gt $l_lowestquality ]; then
    prt_warn "quality $l_quality not availlable (too high), new quality: "
    o_quality=$l_lowestquality
  fi

  # get id (if url was given)
  l_id="${l_obj}"
  l_id="${l_id/*\/video\//}"
  l_id="${l_id/\/*/}"
  prt_dbg 1 "$l_service | id = $l_id"

  # check for valid id
  ([ -z "$l_id" ] || !(isint "$l_id")) && prt_err "no a valid id found" \
    && return 1

  # fetch meta file
  l_lang=de  # no other options
  l_metafile="`meta_file_name`"
  prt_dbg 1 "$l_service | fetching meta file, lang = $l_lang, meta file = $l_metafile"

  "${WGET_CMD[@]}" -O "$l_metafile" "http://www.zdf.de/ZDFmediathek/xmlservice/web/beitragsDetails?id=${l_id}" || return 1

  case $o_quality in
    1) l_quality="veryhigh";;
    2) l_quality="high";;
    *) l_quality="low";;
  esac;
  # parse meta file
  prt_dbg 1 "$l_service | parsing meta file, quality = $l_quality"
  l_title="`cat \"$l_metafile\" | awk -F'[<|>]' '/title/{print $3}'`"

  # get 2nd meta file containing rtmp details
  prt_dbg 1 "$l_service | fetching 2nd meta file containing rtmp uri"
  l_rtmp=$("${WGET_CMD[@]}" -O - "`cat \"$l_metafile\" |\
    awk '/<formitaet.*h264_aac_mp4_rtmp_zdfmeta_http/,/\/formitaet/ {ORS=\"\";gsub(/<\/formitaet>/, \"</formitaet>\n\"); print}' |\
    grep -i \">$l_quality<\" | sed -r 's/.*url>([^<]*)<\/url.*/\1/g'`" |\
    awk -F'[<|>]' '/default-stream-url/{print $3}')
  l_orgfilename="`basename $l_rtmp`"
  l_ext="${l_rtmp##*.}"
}

# youtube has some specialties, e.g. regarding the big variety of formats/qualities
process_youtube() {
  # check if given quality is availlable
  local l_quality=$o_quality
  if [ -z "$(echo \"${YT_AVQUAL[@]:0}\" | grep -Eo '(^|[^0-9])$l_quality([^0-9]|$)')" ]; then
    if [ $l_quality -eq $QUALITY ]; then
      prt_warn "no / default given, trying all available qualities ('best' first)"
    else
      prt_err "given quality not available, see '$PROG --help-youtube-qualities' for details"
      return 1
    fi
  fi

  # get id (if url was given)
  l_id="${l_obj}"
  l_id="${l_id/*\v=/}"
  l_id="${l_id/&*/}"
  prt_dbg 1 "$l_service | id = $l_id"

  # check for valid id
  ([ -z "$l_id" ] || [ ${#l_id} -ne 11 ]) && prt_err "no a valid id found" \
    && return 1

  # fetch meta file
  #l_lang=de  # no other options
  l_metafile="`meta_file_name`"
  prt_dbg 1 "$l_service | fetching meta file, meta file = $l_metafile"

  "${WGET_CMD[@]}" -O "$l_metafile" "http://www.youtube.com/watch?v=${l_id}" || return 1

  local l_metainfo="`cat \"$l_metafile\" | grep -Eo 'url_encoded_fmt_stream_map[^;]*' |\
    sed 's/url_encoded_fmt_stream_map=//;s/url%3D//;s/%2Curl%3D/\n/g' | grep -E \"itag%3D${l_quality}([^0-9]|$)\"`"
  local l_idx=-1
  if [ -z "$l_metainfo" ]; then
    prt_warn "media not found in given / default quality: $o_quality ($QUALITY)"
    prt_warn "checking media in all possible qualities (highest first) ..."
    while [ -z "$l_metainfo" ] && [ $l_idx -lt $((${#YT_AVQUAL[@]}-1)) ]; do
      l_idx=$((l_idx+1))
      l_quality=${YT_AVQUAL[$l_idx]}
      prt_dbg 1 "$l_service | checking availability of quality: $l_quality"
      l_metainfo="`cat \"$l_metafile\" | grep -Eo 'url_encoded_fmt_stream_map[^;]*' |\
        sed 's/url_encoded_fmt_stream_map=//;s/url%3D//;s/%2Curl%3D/\n/g' | grep -E \"itag%3D${l_quality}([^0-9]|$)\"`"
      #prt_dbg 1 "$l_service | meta info: $l_metainfo"
    done
    if [ -z "$l_metainfo" ]; then
      prt_err "no media found, tried all possible qualities: ${YT_AVQUAL[@]}"
      return 1
    else
      prt_msg "media found in quality: ${YT_AVQUAL[$l_idx]} (${YT_AVQUALNAME[$l_idx]})"
    fi
  fi

  #local l_recode="| recode"
  #if which recode 2>/dev/null; then
  #  prt_warn "recode not installed, unable to convert html entities to characters"
  #  l_recode=""
  #fi

  # parse meta file
  prt_dbg 1 "$l_service | parsing meta file, quality = $l_quality"
  l_title="`cat \"$l_metafile\" | grep '<title>' | sed -r 's/(.*<title>|<\/title>.*)//g;s/^YouTube - //;s/&[^;]\;/_/g'`"
  l_media="`echo $l_metainfo | sed 's/%26.*//g' | sed -r 's/%([0-9A-F][0-9A-F])/\\\\\\\\x\1/g' |\
    xargs echo -e | sed -r 's/%([0-9A-F][0-9A-F])/\\\\\\\\x\1/g' | xargs echo -e`"
  local l_qualityname="unknown";
  for i in `seq 0 $((${#YT_AVQUAL[@]}-1))`; do
    l_idx=$i
    if [ "${YT_AVQUAL[$l_idx]}" = "$l_quality" ]; then
      l_ext="`echo ${YT_AVQUALNAME[$l_idx]} | sed 's/_.*//g'`"
      l_qualityname="`echo ${YT_AVQUALNAME[$l_idx]}`"
      break
    fi
  done
  [ -z "$l_ext" ] && prt_msg "unknown file type, using extension .dat" && l_ext="dat"
  o_outfile="`echo $l_title | tr ' :!\"' '_' | tr 'A-Z' 'a-z'`_[youtube,_${l_id}_@${l_qualityname#*_}].$l_ext"
}

# == URL / ID processing ====================================================
trap 'prt_err "BREAK (exit forced)"; prt_warn "Skipped $(($cnt_max-$cnt+1)) link(s)/ID(s): $rest"; exit 1' INT TERM SIGTERM

cnt=0
cnt_max=$#
while [ -n "$1" ]; do
  rest="$*"
  obj="$1"; shift
  cnt=$(($cnt+1))
  prt_msg "object #$cnt/$cnt_max: $obj"
  # service enforced?
  if [ -n "$o_service" ]; then
    service="$o_service"
  else # else try to resolve it by url pattern
    case "$obj" in
      *"youtube.com"*)          service="youtube";;
      *"3sat.de/mediathek/"*)   service="3sat";;
      *"ardmediathek.de/ard/"*) service="ard";;
      *"videos.arte.tv/"*)      service="arte";;
      *"zdf.de/ZDFmediathek/"*) service="zdf";;
      *) prt_warn "can't resolve service from '$obj'" \
               "\n  if this is an id, use -s to select a specific service" \
               "\nSKIPPING ..." \
           && continue;;
    esac
    prt_dbg 1 "obj | service '$service' detected"
  fi
  prt_dbg 1 "obj | calling: process_$service(\"$obj\")"
  core_processor "$service" "$obj" \
    || prt_err "error while processing ($o_service): $obj"
done

exit $EXIT_STATUS

