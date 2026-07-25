# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 60-netdata: install the Netdata agent (metrics + alarms) on all hosts.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.
#
# This module only *installs the agent* — identical on every host. Role and
# tuning (standalone vs child vs parent, ntfy alerting, streaming, lean config)
# are host-specific config files, kept out of this public repo and deployed per
# host. The design of record and the per-host kits are in monitoring.md.

MODULE_DESC="Netdata agent (system + container metrics, health alarms)"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/monitoring.md"

module_run() {
  # Netdata is NOT in Ubuntu apt on 26.04 (`apt-cache policy netdata` → none),
  # so the official kickstart is the only install path. It adds Netdata's own
  # apt repo and installs the native .deb (apt-managed thereafter); it falls
  # back to a self-updating static build only where no native package exists.
  # Either way the bundled netdata-updater keeps it current — apt does not.
  if st::have_cmd netdata || [[ -x /opt/netdata/bin/netdata ]]; then
    st::noop "netdata already installed"
    return 0
  fi

  # Flags: stable channel (not nightly), no anonymous telemetry, no prompts,
  # don't block waiting for the agent to come up. Cloud claiming is deliberately
  # omitted — the parent dashboard is self-hosted behind Caddy, no Netdata Cloud.
  st::run_sh "install netdata via official kickstart (stable, no telemetry)" \
    'curl -fsSL https://get.netdata.cloud/kickstart.sh \
       | sh -s -- --stable-channel --disable-telemetry --non-interactive --dont-wait'

  st::war "agent installed with DEFAULT config — apply the host role config"
  st::war "  (child/parent + ntfy) per docs/setup/monitoring.md before relying on it"
}
