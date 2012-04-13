#!/usr/bin/env bash
# pdfprint.sh

# == Description ============================================================
# A small script to print pdf/ps files with cupsdoprint
# using psnup to print multiple pages per sheet (doublesided)

# == License ================================================================
# Copyright (c) 2003, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

VERSION=20030808
prog=`basename $0`

if [ -z "$1" ]; then
	cat <<EOF
Usage: $prog file [pps]
Version: $VERSION

file        ps/pdf input file
pps         pages per sheet (default 2)

example:
  $prog foo.pdf 4
EOF
	exit 1
fi

set -e
ifile="$1"
[ ! -f "$ifile" ] && echo "error: file '$ifile' not found" >&2 && exit 1

pps=2
[ -n "$2" ] && pps=$2
[ $pps -gt 1 ] && [ $(($pps%2)) != 0 ] && \
	echo "error: pps must be even" >&2 && exit 1

ext=`echo ${ifile##*.} | tr '[A-Z]' '[a-z]'`

nupit () {
	if [ $pps -eq 1 ]; then
		cp "$1" "_$ifile.$pps.ps"
    else
        psnup -n $pps "$1" "_$ifile.$pps.ps"
    fi
}

if [ "$ext" = 'pdf' ]; then
	count=`pdfinfo $ifile|grep "Pages:"|awk '{print $2}'`
	pdftops "$ifile" "_$ifile.ps"
	nupit "_$ifile.ps"
	rm -f "_$ifile.ps"
elif [ "$ext" = 'ps' ]; then
	count=`grep -c "%%Page:" $ifile`
	nupit "$ifile"
else
	echo "error: file must be .ps/.pdf file" >&2 && exit 1
fi

even=0
[ $(($count % 2)) = 1 ] && even=1

doprint () {
	cupsdoprint "$1"
	if [ $(($count-$pps)) -gt 0 ]; then
		echo -e "\n==> please reinsert pages into the papertray"
		echo "==> (you may have to flip/rotate the pages)"
		read
		cupsdoprint "$2"
	fi
	rm -rf "$1" "$2"
}

if [ $even = 1 ]; then
	psselect -e -r "_$ifile.$pps.ps" "_$ifile.$pps.er.ps"
	psselect -o "_$ifile.$pps.ps" "_$ifile.$pps.o.ps"
	doprint "_$ifile.$pps.er.ps" "_$ifile.$pps.o.ps"
else
	psselect -o -r "_$ifile.$pps.ps" "_$ifile.$pps.or.ps"
	psselect -e "_$ifile.$pps.ps" "_$ifile.$pps.e.ps"
	doprint "_$ifile.$pps.or.ps" "_$ifile.$pps.e.ps"
fi
rm -f _$ifile.$pps.ps

