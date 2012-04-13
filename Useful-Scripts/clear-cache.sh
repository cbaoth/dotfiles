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
# firefox
CFILES+=(.mozilla/firefox/*.*/{OfflineCache,Cache})
# opera
CFILES+=(.opera/cache)
# gnome/nautilus trash
CFILES+=(.Trash .local/share/Trash)
# java
CFILES+=(.java/deployment/cache)
# flash player
CFILES+=({.adobe,.macromedia}/Flash_Player)
# evolution
CFILES+=(.evolution/cache)
# thunderbird (imap and message db)
CFILES+=(.thunderbird/*.*/{ImapMail,global-messages-db.sqlite})
# openoffice
CFILES+=(.openoffice.org*/{?/user,user}/{temp,backup})
# gqview/geeqie (if not configured to use .thumbnails)
CFILES+=(.{gqview,geeqie}/thumbnails)
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
CFILES+=(.wine/drive_c/users/*/[Ll]ocal\ [Ss]ettings/[Tt]emporary\ [Ii]nternet\ [Ff]iles)
# google earth
CFILES+=(.googleearth/Cache)
# sql developer
CFILES+=(.sqldeveloper/tmp)

# history files (e.g. bash, grun, mysql etc.)
CFILES+=(.*[-_]history)

# == CORE ===================================================================
noact=0
case "$1" in
  "-n")
    noact=1
    ;;
  "-f")
    ;;
  "-h")
    cat <<USAGE
usage: `basename $0` [option]

[options]
  -h   show this help
  -n   no act mode (no changes will be made)
  -f   force processing (don't ask stupid questions)
USAGE
    exit 0
    ;;
  *)
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
esac

if [ $noact -eq 1 ]; then
  echo "> NO ACT MODE (no changes will be made)"
else
  echo "> STARTING REMOVAL PROCESS"
fi

echo "> processing specific files/folders"
for f in ${CFILES[@]}; do
  file="$BASEDIR/$f"
  if echo "$file" | grep -v "/\.\." >/dev/null &&\
     echo "$file" | grep -vE "^${BASEDIR}/\.?$" >/dev/null &&\
     [ -e "$file" ]; then
    echo "rm -rf $file"
    [ $noact -ne 1 ] && rm -rf "$file"
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

echo "> find: processing thumbnail caches"
find "$BASEDIR" -depth -type d -iname '.thumbnails' -print0 | xargs -0 -r $xargs_v $echo rm -rf
echo "> find: processing local backup/temp files '*~'"
find "$BASEDIR" -depth -type f -iname '*~' -print0 | xargs -0 -r $xargs_v $echo rm -f
echo "> find: processing swap files '.*.swp'"
find "$BASEDIR" -depth -type f -iname '.*.swp' -print0 | xargs -0 -r $xargs_v $echo rm -f
