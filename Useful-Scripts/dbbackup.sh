#!/usr/bin/env bash
# dbbackup.sh: Backup databases

# Author:   Andreas Weyer <dev@cbaoth.de>
# Keywords: bash shell-script postgresql mysql db backup

# FIXME mysql auth only possible via --config (default file not used)
# TODO error handling, delete partial backups on interrupt / error
# TODO add default variables for config files and expire days (optional system wide default config)
# TODO introduce an interactive mode or skip-if-exists

# cron example
#@daily root cronic dbbackup --expire 30 --backup-dir /backup/postgres --user postgres pgsql postgres
#@daily root cronic dbbackup --expire 30 --backup-dir /backup/mysql --config /root/.mylogin.cnf mysql

set -o errtrace
set -o errexit
set -o pipefail
set -o nounset
(( ${DEBUG_LVL:-0} >= 2 )) && set -o xtrace
IFS=$'\t\n\0'

# default values
typeset -r _BACKUP_DIR="/backup/db"
typeset -r _DATE=$(date -I)
typeset -r _USER
typeset -r _DB_USER_PGSQL="postgres"
typeset -r _DB_USER_MYSQL

# constats and variables
typeset -r _SCRIPT_FILE="$(basename "$0")"
typeset -r _USAGE="Usage: ${_SCRIPT_FILE} [OPTION..] DBMS DB.."
typeset _HELP
  ! IFS='' read -r -d '' _HELP <<EOF
$_USAGE

DBMS: pgsql
  Backup all postgresql databases

  Default db user: ${_DB_USER_PGSQL:--}

  The --config option must point to a valid pgpass file
    If not set the pgsql will use ~/.pgpass, example:

      myhost:5432:mydb:myuser:mypassword
      localhost:*:*:postgres:secret


DBMS: mysql
  Backup all mysql databases

  Default db user: ${_DB_USER_MYSQL:--}

  The --config option must point to a valid 'mysqldump --defaults-file' file
    If not set mysql will use ~/.mylogin.cnf, example (only pass mandatory):

      [client]
      user = myuser
      password = "mypassword"
      host = 127.0.0.1


Options:
  -u | --db-user U     the db user for the dbms connection (default: see DBMS)
  --user U             the host user that performs the backup
                         (default: ${_USER:-root})
  -b | --backup-dir    backup directory (default: ${_BACKUP_DIR})
                         the given directory must exist and be writeable
  -c | --config F      client config / credential file (default: see DBMS)
  -x | --expire DAYS   delete old DB backups for the given DBMS in the given dir
                         older than TODAY-DAYS with filename DBMS_DB_*.EXT
  --full               perform full dump (all databases, including users etc.)
                         requiring no specific db name list (ignored)
                         admin user required e.g. -u root or -u postgres

Authentication:
  Passwords must be stored in a secure, DBMS specific config file (see above).
  Using plain text passwords as command line arguments is not an option.
  These fiels should be readable only to it's owner (mode 600).
EOF
typeset -r _USAGE
typeset -a _dbs
typeset _dbms
typeset _backup_dir
typeset _user
typeset _db_user
typeset _config_file
typeset _expire_days
typeset _backup_full=false

# print error and exit with given code
_exit() {
  local _code="$1"
  shift
  printf "ERROR: %s\n" "$@" >&2
  exit ${_code}
}

# parse args
_parse_args() {
  # no arg at all?
  [[ -z "${1:-}" ]] && printf "%s\n" "${_USAGE}" && exit 1

  # read all args
  while [[ -n "${1:-}" ]]; do
    case "$1" in
      pgsql|mysql)
        [[ -n "${dbms:-}" ]] && _exit 1 "DBMS already set to [${dbms}], unable to set another [$1]."
        _dbms="$1"
        shift
        ;;
      --backup-user)
        [[ -z "${2:-}" ]] && _exit 1 "Missing value for arg [$1]."
        _backup_user="$2"
        shift 2
        ;;
      -u|--db-user)
        [[ -z "${2:-}" ]] && _exit 1 "Missing value for arg [$1]."
        _db_user="$2"
        shift 2
        ;;
      --user)
        [[ -z "${2:-}" ]] && _exit 1 "Missing value for arg [$1]."
        _user="$2"
        shift 2
        ;;
      -c|--config)
        [[ -z "${2:-}" ]] && _exit 1 "Missing value for arg [$1]."
        _config_file="$2"
        shift 2
        ;;
      -b|--backup-dir)
        [[ -z "${2:-}" ]] && _exit 1 "Missing value for arg [$1]."
        _set_backup_dir "$2"
        shift 2
        ;;
      -x|--expire)
        [[ -z "${2:-}" ]] && _exit 1 "Missing value for arg [$1]."
        [[ ! "$2" =~ ^\ *[+-]?[0-9]+\ *$ ]] \
          && _exit 1 "Not a valid integer [$2]"
        _expire_days="$2"
        shift 2
        ;;
      --full)
        _backup_full=true
        shift
        ;;
      -h|--help)
        printf "%s" "${_HELP}"
        exit 0
        ;;
      -*)
        _exit 1 "Unknown arg [$1]"
        ;;
      *)
        [[ -z "${_dbms:-}" ]] && _exit 1 "Not a valid DBMS [$1]."
        if [[ "${_dbs[@]}" =~ $1 ]]; then
          printf "WARNING: DB [%s] already added, ignoring.\n" "$1"
        else
          _dbs+=($1)
        fi
        shift
        ;;
    esac
  done

  # dbms or dbs unset?
  [[ -z "${_dbms:-}" ]] && _exit 1 "No DBMS provided."
  if [[ -z "${_dbs:-}" ]]; then
    ${_backup_full} || _exit 1 "No DB provided."
  else
    ${_backup_full} && echo "WARNING: Ignoring specifically provided DB name(s) [${_dbs[@]}], full backup will be performed instead." >&2 
  fi

  # set defaults where needed
  [[ -z "${_backup_dir}" ]] && _set_backup_dir "${_BACKUP_DIR}"
  [[ -z "${_user:-}" ]] && _user="${_USER:-}"
  local _db_user_var="_DB_USER_${_dbms^^}"
  [[ -z "${_db_user:-}" ]] && _db_user="${!_db_user_var:-}"

  return 0
}

# set backup root directory (check if exists and writeable)
_set_backup_dir() {
  local _dir="$1"

  if [[ ! -d "${_dir}" || ! -w "${_dir}" ]]; then
    _exit 1 "Backup dir not existing or missing write permissions [${_dir}]"
  fi
  _backup_dir="${_dir}"
  return 0
}

# delete old backups
_delete_old() {
  # no expire days set? then don't delete anything.
  [[ -z "${_expire_days:-}" ]] && return 0
  local _filename_pattern="$1"

  printf ">> Deleting backups older than [%s] days in [%s] matching [%s]\n" \
    "${_expire_days}" "${_backup_dir}" "${_filename_pattern}"
  find "${_backup_dir}" -maxdepth 1 -regextype posix-extended -type f \
    -ctime +${_expire_days} -regex "${_filename_pattern}" \
    -exec rm -f {} \; -print
}

# backup a single postgresql db deleting old ones first
_backup_pgsql() {
  local _db="$1"
  local _outfile="${_dbms}_${_db}_${_DATE}.gz"
  local _outfilepath="${_dir}/${_outfile}"

  [[ -f "${_outfilepath}" ]] \
    && printf "WARNING: File exists [%s], will be owerridden .."\
              "${_outfilepath}" >&2

  # detele old db backups (if expire days provided)
  _delete_old ".*\/${_dbms}_${_db}_[^/]*.gz"

  # backup db
  sudo ${_user:+-u "${_user}"} \
    ${_config_file:+env PGPASSFILE="${_config_file}"} \
    pg_dump ${_db_user:+-U "${_db_user}"} -w -Fc ${_db} \
      | gzip > "${_outfilepath}"
  return 0
}

# backup all postgresql dbs
_backup_pgsql_full() {
  local _outfile="${_dbms}_full_${_DATE}.gz"
  local _outfilepath="${_dir}/${_outfile}"

  [[ -f "${_outfilepath}" ]] \
    && printf "WARNING: File exists [${_outfilepath}], will be owerridden ..\n" >&2

  # detele old db backups (if expire days provided)
  _delete_old ".*\/${_dbms}_full_[^/]*.gz"

  # backup dbs
  sudo ${_user:+-u "${_user}"} \
    ${_config_file:+env PGPASSFILE="${_config_file}"} \
    pg_dumpall ${_db_user:+-U "${_db_user}"} -w -c \
      | gzip > "${_outfilepath}"
  return 0
}

# backup a single mysql db deleting old ones first
_backup_mysql() {
  local _db="$1"
  local _outfile="${_dbms}_${_db}_${_DATE}.gz"
  local _outfilepath="${_dir}/${_outfile}"

  [[ -f "${_outfilepath}" ]] \
    && printf "WARNING: File exists [%s], will be overridden .." \
              "${_outfilepath}" >&2

  # detele old db backups (if expire days provided)
  _delete_old ".*\/${_dbms}_${_db}_[^/]*.gz"

  # backup db
  sudo ${_user:+-u "${_user}"} \
    mysqldump ${_db_user:+-u "${_db_user}"} \
      ${_config_file:+--defaults-file="${_config_file}"} \
      --extended-insert --disable-keys --quick \
      ${_db} | gzip > "${_outfilepath}"
  return 0
}

# backup all mysql dbs
_backup_mysql_full() {
  local _outfile="${_dbms}_full_${_DATE}.gz"
  local _outfilepath="${_dir}/${_outfile}"

  [[ -f "${_outfilepath}" ]] \
    && echo "WARNING: File exists [${_outfilepath}], will be overridden .." >&2

  # detele old db backups (if expire days provided)
  _delete_old ".*\/${_dbms}_full_[^/]*.gz"

  # backup dbs
  sudo ${_user:+-u "${_user}"} \
    mysqldump ${_db_user:+-u "${_db_user}"} \
      ${_config_file:+--defaults-file="${_config_file}"} \
      --extended-insert --disable-keys --quick \
      --all-databases --add-drop-database --flush-privileges \
      --events --ignore-table=mysql.event \
      | gzip > "${_outfilepath}"
  return 0
} 

_backup() {
  local _dir="${_backup_dir}"

  printf "> Sarting [%s] backup%s%s\n" \
    "${_dbms}" "${_user:+ as [${_user}]}" \
    "${_db_user:+ connecting as [${_db_user}]}"

  if ${_backup_full}; then
    printf ">> Creating full DB backup ..\n"
    _backup_${_dbms}_full
    printf ">> .. done\n"
  else
    for _db in "${_dbs[@]}"; do
      local _outfile="${_dbms}_${_DATE}_${_db}.gz"
      printf ">> Creating backup for DB [%s] ..\n" "${_db}"
      _backup_${_dbms} "${_db}"
      printf ">> .. done\n"
    done
  fi
  printf "> Finished [%s] backup(s)" "${_dbms}"
  return 0
}

# main function
_main() {
  _parse_args "$@"
  _backup
  return 0
}

# run script
_main "$@"

exit 0

