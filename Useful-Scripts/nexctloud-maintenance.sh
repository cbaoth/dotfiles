#!/bin/bash
#
# nextcloud-maintenance.sh
# Runs Nextcloud Maintenance: Integrity, Indices, Update-Check, Log-Cleanup etc.
# With security checks and lock while critical steps are exectude.
#
# contrab example:
# # Nextcloud Maintenance
# @weekly     root    cronic /opt/bin/nextcloud-maintenance.sh

# === Root Only Check ===
[ "$EUID" -ne 0 ] && echo "ERROR: Please run as root!" >&2 && exit 1

# === Core Options ===
# set options
set -o errtrace
#set -o errexit
set -o pipefail
set -o nounset
(( ${DEBUG_LVL:-0} >= 2 )) && set -o xtrace
IFS=$'\t\n\0'

# traps
# (optional) exit on error
trap '_rc=$?; \
      printf "ERROR(%s) in %s:%s\n  -> %s\n  -> %s\n" "${_rc}" \
             "${0:-N/A}" "${LINENO:-N/A}" "${FUNCNAME[@]:-N/A}" \
             c"${BASH_COMMAND:-N/A}"; \
      exit $_rc' ERR
# exit on int/term signal (e.g. ctrl-c)
trap 'printf "\nINTERRUPT\n"; exit 1' SIGINT SIGTERM

# === Configuration ===
NC_ROOT="/var/www/nextcloud"
OCC="$NC_ROOT/occ"
PHP_BIN="/bin/php"
WWW_USER="www-data"
LOGFILE="/var/log/nextcloud-maintenance.log"
MAX_RUNTIME=900  # Timout in seconds for the individual steps

# === Helper Functions ===
log_line() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE"
}

run_occ() {
    # $* = occ-Parameters
    timeout $MAX_RUNTIME sudo -u $WWW_USER $PHP_BIN $OCC "$@" 2> >(tee -a "$LOGFILE" >&2) \
      || ( log_line "ERROR: run_occ $* failed" && return 1 )  # return error, exit script if trap ERR is set
}

run_occ_integrity_check_for_app() {
    local app="$1"
    local app_path="$NC_ROOT/apps/$app"
    if [ -f "$app_path/appinfo/signature.json" ]; then
       log_line "Running integrity:check-app $app"
       run_occ integrity:check-app "$app"
    else
       log_line "Skipping integrity:check-app $app (no signature)"
    fi
}

# === Start ===
log_line "== Nextcloud Maintenance Start =="

# 1) Rotate logfile if it is already larger than 10MB using only a single .old
[ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -gt $((10*1024*1024)) ] \
  && mv "$LOGFILE" "$LOGFILE.old" && echo "" > "$LOGFILE"

# 2) Perform maintenance and add missing indices if any
log_line "Running db:add-missing-indices"
run_occ db:add-missing-indices

log_line "Running maintenance:repair"
run_occ maintenance:repair

# 3) Integrity check (core & apps)
log_line "Running integrity:check-core"
run_occ integrity:check-core

log_line "Running integrity:check-app for all enabled ..."
# Some versions may support --all (all apps), if not use the loop instaed
for app in $(run_occ app:list | grep -E 'Enabled:' -A1000 | tail -n +2 \
  | awk '/^Disabled:/ { exit } { sub(/:.*/, "", $2); print $2 }'); do
    run_occ_integrity_check_for_app "$app"
done
log_line "... done"

# 4) Check if any updates are available (check only, no auto update)
log_line "Running app:update --all --showonly"
run_occ app:update --all --showonly

log_line "Running update:check"
run_occ update:check

# 5) (Optional) Cleanup log
#log_line "Truncating nextcloud.log"
#truncate -s 0 "$NC_ROOT/data/nextcloud.log"

# 6) (Optional) DB opimizations / tuning, if needed
# e.g. run_occ db:convert-filecache-bigint
# e.g. run_occ app:update --all  # should not be automated, only under supervision

# 7) Finalize
log_line "== Nextcloud Maintenance End =="

