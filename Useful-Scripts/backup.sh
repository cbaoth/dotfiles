#!/bin/bash
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
#0 4 1 * * clear-cache.sh; backup full /home /root /etc
#0 4 8,15,22 * * clear-cache.sh; backup inc /home /root /etc
# or
#0  3    1-7  * *    root    [ `date +\%w` -eq 1 ] && backup full && backup2ftp /backup/`date +\%Y-\%m-\%d`-full
#0  3    8-31 * *    root    [ `date +\%w` -eq 1 ] && backup inc

# default directories, will be backed up if no dir(s) given as parameter(s)
declare -a DIRECTORIES
DIRECTORIES+=(etc boot usr/local var/log var/lib var/spool/cron var/svn var/www opt srv)
DIRECTORIES+=(home root)
#DIRECTORIES+=(usr/lib/oracle/xe/app/oracle/product/10.2.0/server/dbs usr/lib/oracle/xe/app/oracle/flash_recovery_area usr/lib/oracle/xe/oradata/XE/)
DIRECTORIES+=(var/lib/postgresql)
#BACKUPDIR="/backup/$HOST"
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
usage: `basename $0` (full|inc) [files/dirs]
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
    [ -n "$1" ] && DIRECTORIES=($*)
    #for dir in `[ -z "$1" ] && echo ${DIRECTORIES[@]} || echo $*`; do
    for dir in ${DIRECTORIES[@]}; do
        dir="`echo $dir | sed 's/^\/*//'`"
        [ ! -d "$dir" ] && echo "Skipping '/$dir', no such directory" | tee -a $ERRORLOG && continue
        #EXCLUDE=""
        #[ -f $dir/.backup-exclude ] && EXCLUDE="`cat $dir/.backup-exclude|grep -v ^#`"
        TARGET=$TARGETDIR/`echo $dir | tr / +`.tar
        [ -f "$TARGET" ] && echo "Skipping '/$dir', target file exists" | tee -a $ERRORLOG && continue
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
    [ -z "$1" ] && error "missing previous full date" && exit 1
    lastfulldate="$1"; shift
    [ ! -d "$BACKUPDIR/${lastfulldate}-full" ] && error "can't find last full-backup"
    echo "Starting incremental backup (newer: ${lastfulldate}) .." | wall
    echo "-- `date` --------------------------------------------" >> $ERRORLOG
    TARGETDIR="$BACKUPDIR/$DATE-inc"
    mkdir -p $TARGETDIR
    [ -n "$1" ] && DIRECTORIES=($*)
    #for dir in `[ -z "$1" ] && echo ${DIRECTORIES[@]} || echo $*`; do
    for dir in ${DIRECTORIES[@]}; do
        dir="`echo $dir | sed 's/^\/*//'`"
        [ ! -d "$dir" ] && echo "Skipping '/$dir', no such directory" | tee -a $ERRORLOG && continue
        #EXCLUDE=""
        #[ -f $dir/.backup-exclude ] && EXCLUDE="`cat $dir/.backup-exclude|grep -v ^#`"
        TARGETFILE=`echo $dir | tr / +`.tar
        [ ! -f "$BACKUPDIR/${lastfulldate}-full/$TARGETFILE" ] && \
            echo "warning: no full-backup of /$dir found" | tee -a $ERRORLOG
        TARGET=$TARGETDIR/$TARGETFILE
        [ -f "$TARGET" ] && echo "Skipping '/$dir', target file exists" | tee -a $ERRORLOG && continue
        echo "Processing '/$dir' .."
        if [ -f "$EXCLUDEFILE" ]; then
            $TAR --newer ${lastfulldate} -C / -cpf $TARGET --exclude-from "$EXCLUDEFILE" $dir 1>/dev/null 2>> $ERRORLOG
        else
            $TAR --newer ${lastfulldate} -C / -cpf $TARGET $dir 1>/dev/null 2>> $ERRORLOG
        fi
    done
    echo "System backups complete, status: $?" | wall
}

type=$1; shift
case $type in
    full)
        full $*
        ;;
    inc)
        [ ! -f "$FULLDATE" ] && error "no record of existing full-backup"
        inc `cat $FULLDATE` $*
        ;;
    *)
        help
        exit -1
        ;;
esac

exit 0

