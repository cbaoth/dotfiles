#!/bin/sh
# getbyext.sh

# == Description ============================================================
# Simple HTML Image gallery creation script
#
# requires libjpeg-progs

# == License ================================================================
# Copyright (c) 2005, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

prog="`basename $0`"
title="My Gallery"
file="gallery.html"
suffix="_tn"
delete=0
bgcolor="#aaaaaa"
tndir="thumbs"

error() { echo -e "error: $1" >&2; return 0; }
usage() {
  cat <<EOF
usage: $prog [options]
options:
  -t TITLE    page title ["$title"]
  -f FILE     gallery html file ["$file"]
  -s SUFFIX   thumbnail file suffix ["$suffix"]
  -d DIR      thumbnail directory name ["$tndir"]
  -b RGB      bgcolor ["$bgcolor"]
EOF
  exit 0
}
#  -y          don't ask before deleting thumbs

while [ $# -ge 1 ]; do
  case $1 in
    -h|--help)
      usage
      ;;
    -t)
      [ -z $2 ] && error "parsing args"
      title="$2"
      shift 2
    ;;
    -f)
      [ -z $2 ] && error "parsing args"
      file="$2"
      shift 2
    ;;
    -s)
      [ -z $2 ] && error "parsing args"
      suffix="$2"
      shift 2
    ;;
#    -y)
#      delete=1
#      shift
#    ;;
    -d)
      [ -z $2 ] && error "parsing args"
      tndir="$2"
    ;;
    -b)
      [ -z $2 ] && error "parsing args"
      bgcolor="$2"
      shift 2
    ;;
    *)
      echo "error: parsing args"
      echo "$prog --help for usage"
      exit 1
    ;;
  esac
done

#if [ $delete -eq 0 ]; then
#  tncount="`ls $tndir/*${suffix}.jpg|wc -l`"
#  if [ $tncount -gt 0 ]; then
#    printf "ready to delete $tncount thumbs \"$tndir/*${suffix}.jpg\"? "
#    read -n 1 key
#    case $key in
#      [yY])
#      ;;
#      *)
#        echo
#        exit 1
#      ;;
#    esac
#  fi
#fi
rm -rf $tndir #/*${suffix}.jpg
mkdir -p $tndir

cat <<EOF > $file
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>$title</title>
</head>

<body bgcolor="$bgcolor">
EOF

for f in *.jpg
  do x="${f%%.jpg}"
  printf "processing: $f .."
  djpeg -scale "1/8" -outfile $tndir/${x}${suffix}_uc.jpg $f
  cjpeg -quality 60 -optimize -outfile $tndir/${x}${suffix}.jpg \
    $tndir/${x}${suffix}_uc.jpg
  rm -f $tndir/${x}${suffix}_uc.jpg
cat <<EOF >> $file
    <a href="./$f" target="_new"><img src="./$tndir/${x}${suffix}.jpg" border="no" /></a>
EOF
  echo ". done"
done

cat <<EOF >> $file
</body>
</html>
EOF

