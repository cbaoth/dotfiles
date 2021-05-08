#!/usr/bin/env bash
# backup.sh: Backup system

# Author:   Andreas Weyer <dev@cbaoth.de>
# Keywords: bash shell-script backup

PATH=/opt/bin:/usr/local/bin:/usr/bin:/bin

# cron example - fixed days of the month (full: 1, incr.: 8, 15, 22)
#0 4 1 * * cronic backup full
#0 4 8,15,22 * * cronic backup inc

# cron example - fixed week day (full: 1st monday, incr.: other mondays)
#0 3 1-7 * * root [[ $(date +\%w) -eq 1 ]] && cronic backup full
#0 3 8-31 * * root [[ $(date +\%w) -eq 1 ]] && cronic backup inc

# default directories, will be backed up if no dir(s) given as parameter(s)
declare -a DIRECTORIES
DIRECTORIES+=(etc boot usr/local opt srv)
DIRECTORIES+=(var/log var/lib var/spool/cron var/www)
DIRECTORIES+=(home root)
#DIRECTORIES+=($DIRECTORIES var/lib/postgresql) # pgsql only (if var/lib is not included)
#DIRECTORIES+=(usr/lib/oracle/xe/app/oracle/product/10.2.0/server/dbs usr/lib/oracle/xe/app/oracle/flash_recovery_area usr/lib/oracle/xe/oradata/XE/)
readonly DIRECTORIES
# backup target directory
declare -r BACKUPDIR="/backup"
declare -r ERRORLOG="$BACKUPDIR/backup.err"
# backup mount point (if set, backup will fail in case mp is not mounted)
# to prevent writing backups to root fs (potentially running out of space)
#declare -r BACKUPMOUNTPOINT="/backup"
# file holding the date of the last full backup
declare -r FULLDATE="$BACKUPDIR/full-date"
# take excluded directories from /etc/backup-exclude
declare -r EXCLUDEFILE="/etc/backup-exclude"
declare -a TARARGS=(-C / -cp)
[[ -f "${EXCLUDEFILE:-}" ]] && TARARGS+=(--exclude-from "$EXCLUDEFILE")
readonly TARARGS

declare -r TAR=/bin/tar
declare -r DATE=$(date +%Y-%m-%d)

help() { # call: help()
  cat <<HELP
Usage: $(basename $0) [-v] (full|inc)
HELP
}

declare _verbose

error() { # call: error(message..)
  printf "Error: %s\n" "$*" >&2
  exit 1
}

full() { # call: full()
  printf "Staring full backup ..\n" | wall 2>/dev/null
  printf -- "-- ${DATE} --------------------------------------------\n" >> "${ERRORLOG}"
  local targetdir="${BACKUPDIR}/${DATE}-full"
  mkdir -p "${targetdir}"
  for dir in "${DIRECTORIES[@]}"; do
    #[ -f $dir/.backup-exclude ] && EXCLUDE="`cat $dir/.backup-exclude|grep -v ^#`"
    local target="${targetdir}/${dir//\//+}.tar"
    if [[ -f "${target}" ]]; then
      printf "Skipping [/%s], backup file exists\n" "${dir}"
      continue
    fi
    printf "Processing [/%s] ..\n" "${dir}" #|wall 2>/dev/null
    [[ -n "${_verbose}" ]] \
      && echo "\$ $TAR ${TARARGS[@]} ${_verbose:+-v} -f ${target} ${dir} |& tee -a ${ERRORLOG}"
    $TAR "${TARARGS[@]}" ${_verbose:+-v} -f "${target}"  "${dir}" |& tee -a "${ERRORLOG}"
  done
  printf "System backups complete, status: %s\n" "$?" | wall 2>/dev/null
  printf "%s" "$DATE" > $FULLDATE
}

inc() { # call: inc(DATE)  # where DATE is date of last full backup
  local fullbackupdate="$1"
  local fullbackup="${BACKUPDIR}/${fullbackupdate}-full"
  [[ ! -d "${fullbackup}" ]] \
    && error "can't find last full-backup"
  printf "Starting incremental backup (newer: %s) ..\n" "$fullbackupdate" | wall 2>/dev/null
  printf -- "-- %s --------------------------------------------\n" "${DATE}" >> "${ERRORLOG}"
  local targetdir="${BACKUPDIR}/${DATE}-inc"
  mkdir -p "${targetdir}"
  for dir in "${DIRECTORIES[@]}"; do
    #[ -f $dir/.backup-exclude ] && EXCLUDE="`cat $dir/.backup-exclude|grep -v ^#`"
    local tarfile="${dir//\//+}.tar"
    local target="${targetdir}/${tarfile}"
    [[ ! -f "${fullbackup}/${tarfile}" ]] && \
      printf "Warning: no full-backup of [/%s] found\n" "${dir}"
    if [[ -f "${target}" ]]; then
      printf "Skipping [/%s], backup file exists" "${dir}"
      continue
    fi
    printf "Processing [/%s] ..\n" "${dir}"
    [[ -n "${_verbose}" ]] \
      && echo "\$ $TAR --newer $1 ${TARARGS[@]} ${_verbose:+-v} -f ${target} ${dir} |& tee -a ${ERRORLOG}"
    $TAR --newer $1 "${TARARGS[@]}" ${_verbose:+-v} -f "${target}" "${dir}" |& tee -a "${ERRORLOG}"
  done
  printf "System backups complete, status: %s\n" "$?" | wall 2>/dev/null
}

check_mountpoint () {
  # no mountpoint provided or not mounted?
  ([ -z "$1" ] || mountpoint -q "$1" >/dev/null) \
    && return 0
  error "unknown mountpoint: $1"
  return 1
}

main() {
  if [[ -z "${1:-}" ]]; then
    help
    exit 1
  fi
  while [[ -n "${1:-}" ]]; do
    case $1 in
      -v)
        _verbose=true
        shift
        ;;
      full)
        # check if backup mount point (if set) is mounted, exit if not
        check_mountpoint "${BACKUPMOUNTPOINT}" || exit 1
        full
        exit $?
        ;;
      inc)
        [[ ! -f "${FULLDATE}" ]] && error "no record of existing full-backup"
        local fulldate=$(cat ${FULLDATE})
        # check if backup mount point (if set) is mounted, exit if not
        check_mountpoint "${BACKUPMOUNTPOINT}" || exit 1
        inc $fulldate
        exit $?
        ;;
      *)
        help
        exit 1
        ;;
    esac
  done
}

main "$@"

exit 0

