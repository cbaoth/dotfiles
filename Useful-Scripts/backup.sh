#!/bin/sh
# backup.sh

# == Description ============================================================
# make incremental or full backup of some important folders
# use of exclude list is possible

# == License ================================================================
# Copyright (c) 2008, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.


PATH=/usr/local/bin:/usr/bin:/bin

# cron example
#0 4 1 * * backup full
#0 4 8,15,22 * * backup inc
# or
#0  3    1-7  * *    root    [ `date +\%w` -eq 1 ] && backup full && backup2ftp /backup/`date +\%Y-\%m-\%d`-full
#0  3    8-31 * *    root    [ `date +\%w` -eq 1 ] && backup inc

DIRECTORIES="etc boot home root usr/local var/log var/lib var/spool/cron var/svn var/www opt srv"
#DIRECTORIES="$DIRECTORIES usr/lib/oracle/xe/app/oracle/product/10.2.0/server/dbs usr/lib/oracle/xe/app/oracle/flash_recovery_area usr/lib/oracle/xe/oradata/XE/"
DIRECTORIES="$DIRECTORIES var/lib/postgresql"
BACKUPDIR="/backup"
ERRORLOG="$BACKUPDIR/backup.err"
# file holding the date of the last full backup
FULLDATE="$BACKUPDIR/full-date"
# take excluded directories (backup blacklist) from /etc/backup-exclude
# file/files includes a list of folders that should be excluded separated by newline
EXCLUDEFILE="/etc/backup-exclude"

TAR=/bin/tar
DATE=`date +%Y-%m-%d`

help() { # call: help()
    cat <<HELP
usage: `basename $0` (full|inc)
HELP
}

error() { # call: error(message..)
    echo "error: $*" 1>&2
    exit -1
}

full() { # call: full()
    echo "Staring full backup .." | wall
    echo "-- `date` --------------------------------------------" >> $ERRORLOG
    TARGETDIR="$BACKUPDIR/$DATE-full"
    mkdir -p $TARGETDIR 
    for dir in $DIRECTORIES; do
        #EXCLUDE=""
        #[ -f $dir/.backup-exclude ] && EXCLUDE="`cat $dir/.backup-exclude|grep -v ^#`"
        TARGET=$TARGETDIR/`echo $dir | tr / +`.tar
        [ -f "$TARGET" ] && echo "Skipping '/$dir', file exists" && continue
        echo "Processing '/$dir' .." #|wall
        if [ -f "$EXCLUDEFILE" ]; then
            $TAR -C / -cpf $TARGET --exclude-from "$EXCLUDEFILE" $dir 1>/dev/null 2>> $ERRORLOG
        else
            $TAR -C / -cpf $TARGET $dir 1>/dev/null 2>> $ERRORLOG
        fi
    done
    echo "System backups complete, status: $?" | wall
    echo $DATE > $FULLDATE
}

inc() { # call: inc(DATE)  # where DATE is date of last full backup
    [ -z "$0" ] && error "..."
    [ ! -d "$BACKUPDIR/$1-full" ] && error "can't find last full-backup"
    echo "Starting incremental backup (newer: $1) .." | wall
    echo "-- `date` --------------------------------------------" >> $ERRORLOG
    TARGETDIR="$BACKUPDIR/$DATE-inc"
    mkdir -p $TARGETDIR
    for dir in $DIRECTORIES; do
        #EXCLUDE=""
        #[ -f $dir/.backup-exclude ] && EXCLUDE="`cat $dir/.backup-exclude|grep -v ^#`"
        TARGETFILE=`echo $dir | tr / +`.tar
        [ ! -f "$BACKUPDIR/$1-full/$TARGETFILE" ] && \
            echo "warning: no full-backup of /$dir found"
        TARGET=$TARGETDIR/$TARGETFILE
        [ -f "$TARGET" ] && echo "Skipping '$dir', file exists" && continue
        echo "Processing '/$dir' .."
        if [ -f "$EXCLUDEFILE" ]; then
            $TAR --newer $1 -C / -cpf $TARGET --exclude-from "$EXCLUDEFILE" $dir 1>/dev/null 2>> $ERRORLOG
        else
            $TAR --newer $1 -C / -cpf $TARGET $dir 1>/dev/null 2>> $ERRORLOG
        fi
    done
    echo "System backups complete, status: $?" | wall
}

case $1 in
    full)
        full
        ;;
    inc)
        [ ! -f "$FULLDATE" ] && error "no record of existing full-backup"
        inc `cat $FULLDATE`
        ;;
    *)
        help
        exit -1
        ;;
esac

exit 0

