#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Deploy the bedtime-shutdown pieces from this repo to the system.
# The repo is the single source of truth: edit files here, then deploy.
# For usage see: ./install.sh --help  (or README.md)

set -euo pipefail

# {{{ = CONSTANTS ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Repo source -> system target pairs. Targets are overridable via env only to
# allow sandbox testing (see the test harness); leave them unset in normal use.
declare -r SCRIPT_SRC="$SCRIPT_DIR/bedtime-shutdown.sh"
declare -r CONFIG_SRC="$SCRIPT_DIR/bedtime-shutdown.conf"
declare -r SERVICE_SRC="$SCRIPT_DIR/bedtime.service"
declare -r TIMER_SRC="$SCRIPT_DIR/bedtime.timer"

declare -r SCRIPT_DST="${BSS_INSTALL_SCRIPT_DST:-/opt/bin/bedtime-shutdown.sh}"
declare -r CONFIG_DST="${BSS_INSTALL_CONFIG_DST:-/etc/bedtime-shutdown.conf}"
declare -r SERVICE_DST="${BSS_INSTALL_SERVICE_DST:-/etc/systemd/system/bedtime.service}"
declare -r TIMER_DST="${BSS_INSTALL_TIMER_DST:-/etc/systemd/system/bedtime.timer}"

# File ownership (overridable for sandbox testing; real deploys are root:root).
declare -r OWNER="${BSS_INSTALL_OWNER:-root}"
declare -r GROUP="${BSS_INSTALL_GROUP:-root}"

# Colors, only on a tty.
if [[ -t 1 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[1;33m' NC=$'\033[0m'
else
  declare -r RED="" GREEN="" YELLOW="" NC=""
fi

# Globals set by argument parsing.
declare TARGET="default"
declare FORCE=false
declare DRY_RUN=false
declare DIFF_ONLY=false
# }}} = CONSTANTS ============================================================

# {{{ = HELPERS ==============================================================
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "  $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*" >&2; }
err()  { echo -e "${RED}✗ $*${NC}" >&2; }

usage() {
  local -r self="$(basename "$0")"
  cat <<EOF
Usage: $self [TARGET] [OPTIONS]

Deploy the bedtime-shutdown pieces from this repo to the system. The repo is the
source of truth: edit files here, then deploy. Real deploys need root (sudo).

Targets:
  (none)   Safe default: update the script; install config/units only if missing.
  script   Deploy the script  -> $SCRIPT_DST
  config   Deploy the config  -> $CONFIG_DST
  units    Deploy service+timer, daemon-reload, enable + restart the timer.
  all      Deploy script + config + units.

Options:
  -f, --force     Overwrite existing files without prompting.
  -n, --dry-run   Show what would change; write nothing (no root needed).
      --diff      Show diffs between repo and system; write nothing.
  -h, --help      Show this help.

Examples:
  sudo ./$self                 # first install / safe update
  sudo ./$self config          # push config changes (shows diff, asks first)
  sudo ./$self units --force   # replace units, reload, restart the timer
  ./$self --diff all           # preview all diffs, change nothing
EOF
}

# True when this run performs real writes (not a preview).
is_write_run() { [[ "$DRY_RUN" == false && "$DIFF_ONLY" == false ]]; }

# Show a unified diff between the deployed target and the repo source.
show_diff() { # show_diff DST SRC
  local -r dst=$1 src=$2
  if [[ ! -e "$dst" ]]; then info "(new - no existing $dst)"; return 0; fi
  if [[ ! -r "$dst" ]]; then warn "cannot read $dst to diff (need root); skipping diff"; return 0; fi
  diff -u --label "$dst (system)" --label "$src (repo)" "$dst" "$src" || true
}

# deploy_one SRC DST MODE LABEL [AUTO]
# AUTO=true: overwrite silently (pure build artifact, e.g. the script).
# AUTO=false (default): prompt before overwriting an existing file (unless FORCE),
# and back it up first.
deploy_one() {
  local -r src=$1 dst=$2 mode=$3 label=$4 auto=${5:-false}
  [[ -f "$src" ]] || { err "missing repo source: $src"; return 1; }

  # Refuse to fight an immutable target (README suggests chattr +i on the script).
  if [[ -e "$dst" ]] && lsattr -d "$dst" 2>/dev/null | awk '{print $1}' | grep -q i; then
    warn "$dst is immutable (chattr +i); run 'sudo chattr -i $dst' first. Skipping $label."
    return 0
  fi

  if [[ -e "$dst" ]] && cmp -s "$src" "$dst" 2>/dev/null; then
    ok "$label already up-to-date ($dst)"
    return 0
  fi

  # Something will change (or target is unreadable): show the diff for context.
  [[ -e "$dst" ]] && show_diff "$dst" "$src"

  if [[ "$DIFF_ONLY" == true ]]; then return 0; fi
  if [[ "$DRY_RUN" == true ]]; then info "would deploy: $src -> $dst (mode $mode)"; return 0; fi

  if [[ -e "$dst" && "$auto" != true && "$FORCE" != true ]]; then
    local ans
    read -r -p "Overwrite $dst? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { warn "$label: skipped"; return 0; }
  fi

  if [[ -e "$dst" && "$auto" != true ]]; then
    cp -a "$dst" "${dst}.bak" && info "backed up existing -> ${dst}.bak"
  fi

  install -D -m "$mode" -o "$OWNER" -g "$GROUP" "$src" "$dst"
  ok "$label deployed -> $dst"
}

deploy_script() { deploy_one "$SCRIPT_SRC" "$SCRIPT_DST" 700 "script" true; }
deploy_config() { deploy_one "$CONFIG_SRC" "$CONFIG_DST" 600 "config"; }

deploy_units() {
  deploy_one "$SERVICE_SRC" "$SERVICE_DST" 644 "service unit"
  deploy_one "$TIMER_SRC"   "$TIMER_DST"   644 "timer unit"

  # Reload/enable/restart only on a real deploy to real system paths.
  if ! is_write_run; then return 0; fi
  if [[ "$OWNER" != root ]]; then return 0; fi   # sandbox test: skip systemctl

  info "Reloading systemd, enabling and restarting the timer..."
  systemctl daemon-reload
  systemctl enable bedtime.timer >/dev/null 2>&1 || true
  systemctl restart bedtime.timer
  ok "Timer active:"
  systemctl list-timers bedtime.timer --no-pager || true
}
# }}} = HELPERS ==============================================================

# {{{ = ARGUMENT PARSING =====================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)   FORCE=true ;;
    -n|--dry-run) DRY_RUN=true ;;
    --diff)       DIFF_ONLY=true ;;
    -h|--help)    usage; exit 0 ;;
    script|config|units|all)
      [[ "$TARGET" != default ]] && { err "only one target allowed (got '$TARGET' and '$1')"; exit 1; }
      TARGET=$1 ;;
    *) err "unknown argument: $1"; usage >&2; exit 1 ;;
  esac
  shift
done
# }}} = ARGUMENT PARSING =====================================================

main() {
  # Real writes to system paths need root.
  if is_write_run && [[ $EUID -ne 0 && "$OWNER" == root ]]; then
    err "deploying needs root; re-run with sudo (or preview with --dry-run / --diff)."
    exit 1
  fi

  echo "===================================="
  echo "Bedtime Shutdown - Deploy (${TARGET})"
  [[ "$DRY_RUN" == true ]]   && echo "  mode: DRY-RUN (no changes)"
  [[ "$DIFF_ONLY" == true ]] && echo "  mode: DIFF (no changes)"
  echo "===================================="

  case "$TARGET" in
    script) deploy_script ;;
    config) deploy_config ;;
    units)  deploy_units ;;
    all)    deploy_script; deploy_config; deploy_units ;;
    default)
      # Safe, non-destructive: always refresh the (artifact) script; install
      # config/units only when they are missing. Use explicit targets to update.
      deploy_script
      if [[ ! -e "$CONFIG_DST" ]]; then
        deploy_config
        [[ "$DRY_RUN" == false && "$DIFF_ONLY" == false ]] && \
          warn "New config at $CONFIG_DST - review before relying on it: sudoedit $CONFIG_DST"
      else
        ok "config present ($CONFIG_DST) - left as-is (use 'config' to update)"
      fi
      if [[ ! -e "$TIMER_DST" || ! -e "$SERVICE_DST" ]]; then
        deploy_units
      else
        ok "units present - left as-is (use 'units' to update)"
      fi
      ;;
  esac

  echo
  ok "Done."
}

main
