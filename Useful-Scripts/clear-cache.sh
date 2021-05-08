#!/bin/bash
# clear-cache.sh

# == Description ============================================================
# Clear all (known) local caches, temp files etc.

# == License ================================================================
# Copyright (c) 2011, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

# == CONSTANTS / CONFIG =====================================================
BASEDIR="$HOME"

CFILES=()

# dot cache
CFILES+=(.cache/*)
# browser
CFILES+=(.mozilla/firefox/**/{OfflineCache,Cache,Crash\ Reports})
CFILES+=(.opera/{cache,opcache})
# gnome/nautilus trash
CFILES+=(.Trash .local/share/Trash)
# java
CFILES+=(.java/deployment/cache)
# flash player
CFILES+=({.adobe,.macromedia}/Flash_Player)
# evolution
CFILES+=(.evolution/cache)
# thunderbird (imap and message db)
#CFILES+=(.thunderbird/*.*/{ImapMail,global-messages-db.sqlite})
# openoffice / libreoffice
CFILES+=(.{openoffice.org,libreoffice}*/{?/user,user}/{temp,backup})
# gqview/geeqie (if not configured to use .thumbnails)
CFILES+=(.{gqview,geeqie}/thumbnails)
CFILES+=(**/.thumbnails)
# kodi cache
CFILES+=(.kodi/temp)
#CFILES+=(.kodi/userdata/Thumbnails)
# pidgin logs
#CFILES+=(.purple/logs/*/*)
# vlc cache
CFILES+=(.vlc/cache)
# x session error
CFILES+=(.xsession-errors*)
# x start log
CFILES+=(.x11startlog)
# core dump
CFILES+=(.zcompdump)
# winetricks
CFILES+=(.winetrickscache)
# wine temp
CFILES+=(.wine/drive_c/users/*/Temp)
#CFILES+=(.wine/drive_c/users/*/[Ll]ocal\ [Ss]ettings/[Tt]emporary\ [Ii]nternet\ [Ff]iles)  # needs to be fixed, issues with spaces
# google earth
CFILES+=(.googleearth/Cache)
# sql developer
CFILES+=(.sqldeveloper/tmp)
# jdownloader logs
CFILES+=({jd2,.jdownloader2}/{logs,backup,tmp})
# swap files
CFILES+=(**/.*.swp)

# history files (e.g. bash, grun, mysql etc.)
CFILES+=(.*[-_]history)

# == CORE ===================================================================
noact=0
force=0
while [ -n "$1" ]; do
  case "$1" in
    "-n")
      noact=1; shift
      ;;
    "-f")
      force=1; shift
      ;;
    "-b")
      [ -z "$2" ] && echo "error parsing args" && exit 1
      BASEDIR="$2"; shift 2
      ;;
    "-h")
      cat <<USAGE
usage: `basename $0` [option]

[options]
  -h   show this help
  -n   no act mode (no changes will be made)
  -f   force processing (don't ask stupid questions)
  -b   basedir (default: \$HOME)
USAGE
      exit 0
      ;;
    *)
      echo "error parsing args"
      exit 1
      ;;
  esac
done

if [ $force -ne 1 ]; then
  echo "> use argument -n to make a dry run (no deletion)"
  echo "> use argument -f to skip the following question"
  echo "> are you sure that you want to continue?"
  printf "(y)es, (n)o, (d)ry-run: "
  while ((1)); do
    read -s -n1 yesno
    case $yesno in
      [yY])
        echo
        break
        ;;
      [nN])
        echo
        exit 0
        ;;
      [dD])
        noact=1
        echo
        break
        ;;
      *)
        ;;
     esac
  done
  echo
fi

[ ! -d "$BASEDIR" ] && echo "given base directory '$BASEDIR' not found/accessible" && exit 1

if [ $noact -eq 1 ]; then
  echo "> NO ACT MODE (no changes will be made)"
else
  echo "> STARTING REMOVAL PROCESS"
fi

echo "> processing specific files/folders"
for f in ${CFILES[@]}; do
  file="$BASEDIR/$f"
  echo "> processing: $file"
  if echo "$file" | grep -v "/\.\." >/dev/null &&\
     echo "$file" | grep -vE "^${BASEDIR}/\.?$" >/dev/null; then #&&\
     #[ -e "$file" ]; then
    #echo "rm -rf $file"
    if [ $noact -ne 1 ]; then
        rm -rf $file
    else
        echo "rm -rf $file"
    fi
  else
     echo "> skipping .."
  fi
done

echo "> searching for general files/folders"
if [ $noact -eq 1 ]; then
  xargs_v=""
  echo="echo"
else
  xargs_v="--verbose"
  echo=""
fi

#echo "> find: processing thumbnail caches"
#find "$BASEDIR" -depth -type d -iname '.thumbnails' -print0 | xargs -0 -r $xargs_v $echo rm -rf
echo "> find: processing local backup/temp files '*~'"
find "$BASEDIR" -depth -type f -iname '*~' -print0 | xargs -0 -r $xargs_v $echo rm -f
#echo "> find: processing swap files '.*.swp'"
#find "$BASEDIR" -depth -type f -iname '.*.swp' -print0 | xargs -0 -r $xargs_v $echo rm -f
echo "> clearing journal, keeping last 2 days"
sudo journalctl --vacuum-time=2d
