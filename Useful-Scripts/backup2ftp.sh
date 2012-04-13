#!/bin/sh
# backup2ftp.sh

# == Description ============================================================
# Copy a local backup to an ftp server, and always keep the prev backup on the ftp.

# == License ================================================================
# Copyright (c) 2010, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

[ ! -d "$1" ] &&\
  echo "usage: `basename $0` backupdir" && exit 1
LBACK="$1"

FTPH="myftp.host"   # ftp host
FTPU="ftpuser"      # ftp user
FTPP="ftppass"      # ftp password

RBCUR="backup-cur"  # name of the ftp backup folder, current backup
RBPRE="backup-pre"  # name of the ftp backup folder, previous backup

ncftp -u"$FTPU" -p"$FTPP" $FTPH <<EOF
rm -r $RBPRE
rename $RBCUR $RBPRE
mkdir $RBCUR
cd $RBCUR
lcd $LBACK
mput boot* etc* root* srv* usr* var*
cd /
mput home* opt*
quit
EOF

