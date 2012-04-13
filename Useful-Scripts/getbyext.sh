#!/usr/bin/env bash
# getbyext.sh

# == Description ============================================================
# Fetch all direct linked media files (e.g. mp3/jpg) from a given URL
# using wget, or another tool (link output possible).

# == License ================================================================
# Copyright (c) 2001, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

trap 'exit 1' INT TERM SIGTERM

# -- options ----------------------------------------------------------------
VERSION="080726"
PROG="`basename $0`"
zext="gz,tgz,bz2,zip,rar,ace"
aext="ogg,mp4,mp3,mp2,wav,mid,mod,sid,wma"
vext="mpeg,mpg,avi,divx,asf,asx,wmv"
gext="jpg,jpeg,png,gif,xcf"
pre="" # default prefix
autopre=0 # dynamic prefix (!0 -> true)
dirsep="+" # replacement character for / in urls (used for dynamic prefixing)
uagent="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517 Mozilla Firebird/0.6"
errorlog=0
errorlogfile="$HOME/getbyext-error.log"
verbosity=1
stdout=0
# ---------------------------------------------------------------------------

p_err() { echo -e "ERROR: $*" >&2; return 0; }
p_err2() {
  echo -e "error: $1" >&2
  [ $errorlog -gt 0 ] &&\
    echo -e "`date +%y-%d-%m\ %H:%M:%S` ERROR: $1" >> "$errorlogfile"
    return 0
}
p_msg2() { [ $1 -ge $2 ] && shift 2 && echo -e "$*"; return 0; }

isint() { # may not contain .
  [ -z "$1" ] && return 0
  [ -n "`echo $1 | egrep \"^[-]?[0-9]+$\"`" ] && \
    return 0
  return 1
}

function usage {
  [ -n "$1" ] && p_err "error: $1"
  cat << EOF
$PROG ext.. [options] url..

ext:
  -e EXTLIST   list of file-extentions seperated by ','
  -ez          archives [$zext]
  -ea          audio [$aext]
  -eg          graphics ($gext]
  -ev          video [$vext]
  -em          media -a -g -v
  -a           all (-e*)
  -i EXP       ignore files matching regexp EXP (case insensitive)
  -iu          match whole url when using -i
  -m EXP       just get files matching regexp EXP (case insensitive)
  -mu          match whole url when using -m
  -u user:pw   auth

options:
  -p PREFIX    outputfile prefix
  -d           dynamic output filename, '/' in url are replaced by '$dirsep'
  -x           exit on first error
  --referer R  referer url
  --dir D      destination directory
  --post D     post data string
  --stdout     print links only instead of downloading them
               verbotity set to 0 in this case! example usage:
  --verb X     set verbosity level [$verbosity]

examples:
  $PROG -z -p foo. http://files.foo/files.html http://src.foo/src.html
  $PROG -e sh,txt -i ^text[0-9]+ http://foo.bar/shellscripts.html -p script.
  $PROG -e tar,bz2 -m _src http://pkg.bar/packages.html
  $PROG -a --stdout http://some.url | uniq | xargs wget-mp -d
EOF
}
#  --cfile F    load cookie file

ext=""
function extappend {
  if [ -n "$ext" ]; then
    ext="$ext,$1"
  else
    ext="$1"
  fi
}

urls=""
function urlappend {
  if [ -n "$urls" ]; then
    urls="$urls $1"
  else
    urls="$1"
  fi
}

ignoreexp=""; ignoreexpurl=0; matchexp=""; matchexpurl=0
auth=""; ref=""; dir=""
wgetargs=()
while [ -n "$1" ]; do
  case "$1" in
  -ez|-EZ)
    extappend "$zext"
    shift
    ;;
  -ea|-EA)
    extappend "$aext"
    shift
    ;;
  -ev|-EV)
    extappend "$vext"
    shift
    ;;
  -eg|-EG)
    extappend "$gext"
    shift
    ;;
  -em|-EM)
    extappend "$aext,$vext,$gext"
    shift
    ;;
  -a|-A|-all)
    extappend "$aext,$vext,$gext,$zext"
    shift
    ;;
  -[eE])
    extappend "$2"
    shift 2
    ;;
  -[iI])
    [ -z "$2" ] && p_err "parsing args" && exit 1
    ignoreexp="$2"
    shift 2
    ;;
  -[iI][uU])
    ignoreexpurl=1
    shift
    ;;
  -[mM])
    [ -z "$2" ] && p_err "parsing args" && exit 1
    matchexp="$2"
    shift 2
    ;;
  -[mM][uU])
    matchexpurl=1
    shift
    ;;
  -[pP])
    [ -z "$2" ] && p_err "parsing args" && exit 1
    pre="$2"
    shift 2
    ;;
  -[uU])
    [ -z "$2" ] && p_err "parsing args" && exit 1
    auth="$2"
    shift 2
    ;;
  --referer)
    [ -z "$2" ] && p_err "parsing args" && exit 1
    ref="$2"
    shift 2
    ;;
  --dir)
    [ -z "$2" ] && error "parsing args" && exit 1
    dir="${2%/}/"
    [ ! -d "$dir" ] &&\
      p_err "destination directory does't exist: '$dir'" && exit 1
    shift 2
    ;;
  --cfile)
    [ -z "$2" ] && p_err "parsing args" && exit 1
    wgetargs=(${wgetargs[*]} --load-cookies $2)
    shift 2
    ;;
  --post)
    [ -z "$2" ] && p_err "parsing args" && exit 1
    wgetargs=(${wgetargs[*]} --post-data="$2")
    shift 2
    ;;
  --stdout)
    stdout=1
    shift
    ;;
  --verb|--verbosity)
    ([ -z "$2" ] || ! isint "$2") && p_err "parsing args" && exit 1
    verbosity=$2
    shift 2
    ;;
  -[dD])
    autopre=1
    shift
    ;;
    -[xX])
        set -e
        shift
        ;;
  *)
    urlappend $1
    shift
    ;;
  esac
done

[ $stdout -gt 0 ] && verbosity=0
[ -z "$ext" ] && usage "no ext given" && exit 1
[ -z "$urls" ] && usage "no url given" && exit 1

ext="$(echo $ext|sed 's/,/\\\|/g')"

get_last () {
  string="$1"
  count=$(($2+1))
  len=${#string}
  idx=$(($len-$count))
  [ $idx -lt 0 ] && idx=0
  echo $string | cut -c $idx-$len
}

if [ -n "$auth" ] && [ -n "`echo $auth | grep :`" ]; then
  auth="--http-user=\"`echo $auth|cut -d : -f 1`\" --http-password=\"`echo $auth|cut -d : -f 2`\""
else
  auth=""
fi

p_msg2 $verbosity 1 "initialising transfer"
for url in $urls; do
  if [ -n "$ref" ]; then
    referer="$ref"
  else
    referer="$url"
  fi
  p_msg2 $verbosity 1 "url: $url"
  wget --quiet -U "$uagent" -O - "$url"| \
  sed 's/<[ \t]*[a][ \t]*/\n/gi'| \
  grep -i href| grep -i "$ext"| \
  sed "s/^.*href=[\"']*//i ; s/[\"']*[ \t]*>.*$/ >/i ;
    s/\([\"'][^>]*\|[ \t]\+[^> \t]\+\=[^>]*\|[ \t]*\)>.*$//i"| \
  while read l; do
    #echo "> l: $l"
    if [ "$(echo $l | egrep -i '^http')" ]; then
      link="$l"
    else
      if [ "`echo $l | cut -c -1`" == '/' ]; then
        host="`echo $url | sed 's/http:\/\///g ; s/\/.*//g'`"
        url="http://$host"
      elif [ -n "$(echo $url| grep -i '.php\|.htm\|.asp\|.cgi')" ]; then
        url="`dirname $url`"
      fi
      link="`echo $url | sed 's/[&?].*//g'`/$l"
    fi
    #echo "> link: $link"
    if [ -n "$(echo ${link##*.}| grep -i $ext)" ]; then
      fname=`basename "$link"`
      file=""
      [ -n "$pre" ] && \
        file="$pre"
      if [ $autopre -eq 1 ]; then
        file="$file`echo $link | sed \"s/http:\/\///g ; s/[&?].*//g ; s/\//$dirsep/g ; s/${dirsep}+/$dirsep/g\"`"
      else
        file="${file}`echo ${link##*/} | sed 's/[&?].*//g'`"
      fi
      file="`echo $file | sed 's/\(%20\|[ ]\)/_/g'`"
      if [ -n "$ignoreexp" ]; then
        if [ $igoreexpurl -gt 0 ]; then
          if [ -n "`echo \"$link\" | egrep -i \"$ignoreexp\"`" ]; then
            p_msg2 $verbosity 2 "ignoing '$fname'"
            continue
          fi
        elif [ -n "`echo \"$fname\" | egrep -i \"$ignoreexp\"`" ]; then
          p_msg2 $verbosity 2 "ignoing '$fname'"
          continue
        fi
      fi
      if [ -n "$matchexp" ]; then
        if [ $matchexpurl -gt 0 ]; then
          if [ -n "`echo \"$link\" | egrep -vi \"$matchexp\"`" ]; then
            p_msg2 $verbosity 2 "ignoing '$fname'"
            continue
          fi
        elif [ -n "`echo \"$fname\" | egrep -vi \"$matchexp\"`" ]; then
          p_msg2 $verbosity 2 "ignoing '$fname'"
          continue
        fi
      fi
      file="`echo $file | cut -d \\\" -f 1`"
      link="`echo $link | cut -d \\\" -f 1`"
      if [ -n "`echo $link | grep 'javascript:'`" ]; then
        p_msg2 $verbosity 2 "skipping js link '$link'"
      elif [ -z "`echo $link | grep -E '\.\w+$'`" ]; then
        p_msg2 $verbosity 2 "skipping link '$link'"
      else
        p_msg2 $verbosity 1 "getting '$link' -> '$file' "
        if [ $stdout -gt 0 ]; then
          echo $link
        else
          if [ $errorlog -gt 0 ]; then
            p_err2 "wget --quiet $auth -c -U \"$uagent\" --referer=\"$referer\" \"$link\" -O \"$dir$file\" ${wgetargs[*]}"
            wget --quiet $auth -c -U "$uagent" --referer="$referer" "$link" -O "$dir$file" ${wgetargs[*]} 2>> "$errorlogfile"
          else
            wget --quiet $auth -c -U "$uagent" --referer="$referer" "$link" -O "$dir$file" ${wgetargs[*]}
          fi
          if [ $? == 0 ]; then
            p_msg2 $verbosity 2 ".. done\n"
          else
            p_err ".. error, or already retrieved!\n"
          fi
        fi
      fi
    fi
  done
done

p_msg2 $verbosity 1 ".. tranfer complete"
