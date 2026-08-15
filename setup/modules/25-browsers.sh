# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 25-browsers: Third-party apt repos and packages for web browsers.
#
# Each browser has a setup_<name> function that ensures the apt repo (signing
# key + deb822 sources) is present. The BROWSERS table controls which repos
# are set up, the default package to install, and whether to install it.
#
# Each repo typically provides multiple release channels (stable, beta, dev/
# nightly, etc.). The module installs only the default listed in the table;
# other variants from the same repo can always be installed manually via apt.
# See docs/setup/browsers.md for available packages per repo.
#
# To add a new browser: write a setup_<name> function following the existing
# pattern, and add a line to the BROWSERS array.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Browser apt repos (Firefox Nightly, Vivaldi, Chrome, Brave, Edge)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/browsers.md"

# Browser registry: "name:package:install"
#   name    — matches setup_<name> function below
#   package — default apt package to install (one of potentially many from
#             the same repo; see docs/setup/browsers.md for all variants)
#   install — "yes" = set up repo AND install package; "repo" = repo only
declare -ra BROWSERS=(
  "firefox:firefox-nightly:yes"
  "vivaldi:vivaldi-stable:yes"
  "chrome:google-chrome-stable:repo"
  "brave:brave-browser:repo"
  "edge:microsoft-edge-stable:repo"
)

# {{{ = Helpers =============================================================

# Install a signing key from a URL. Handles both ASCII-armored keys (kept
# as-is) and binary/armored keys that need dearmoring.
# Usage: install_key URL DEST_FILE [dearmor]
install_key() {
  local -r url="$1" dest="$2" dearmor="${3:-}"

  if [[ -f "${dest}" ]]; then
    st::noop "signing key already present: ${dest}"
    return 0
  fi

  local -r dest_dir="$(dirname "${dest}")"
  if [[ "${dearmor}" == "dearmor" ]]; then
    st::run "install signing key ${dest##*/}" -- \
      sudo sh -c "install -d -m 0755 '${dest_dir}' && \
        curl -fsSL '${url}' | gpg --dearmor -o '${dest}'"
  else
    st::run "install signing key ${dest##*/}" -- \
      sudo sh -c "install -d -m 0755 '${dest_dir}' && \
        curl -fsSL '${url}' -o '${dest}'"
  fi
}

# Write a deb822 sources file and optional pin file if content differs.
# Calls st::apt_update --force when the sources file is new or changed.
# Usage: install_sources SOURCES_FILE SOURCES_CONTENT [PIN_FILE PIN_CONTENT]
install_sources() {
  local -r sources_file="$1" sources_content="$2"
  local -r pin_file="${3:-}" pin_content="${4:-}"
  local -i changed_before=${ST_CHANGED}

  st::file_content "${sources_file}" "${sources_content}"
  [[ -n "${pin_file}" ]] && st::file_content "${pin_file}" "${pin_content}"

  # Refresh apt cache if repo config was added or changed.
  if (( ST_CHANGED > changed_before )); then
    st::apt_update --force
  fi
}

# }}} = Helpers =============================================================

# {{{ = Firefox =============================================================

setup_firefox() {
  local -r key_url="https://packages.mozilla.org/apt/repo-signing-key.gpg"
  local -r key_file="/etc/apt/keyrings/packages.mozilla.org.asc"
  local -r expected_fp="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"

  local sources_content pin_content
  read -r -d '' sources_content <<'EOF' || true
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

  # Pin Mozilla packages above Ubuntu's snap-transitional firefox.
  read -r -d '' pin_content <<'EOF' || true
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

  install_key "${key_url}" "${key_file}"

  # Verify fingerprint (non-fatal).
  if [[ -f "${key_file}" ]] && ! (( ST_DRY_RUN )); then
    local fp
    fp="$(gpg -n -q --import --import-options import-show "${key_file}" 2>/dev/null \
          | awk '/pub/{getline; gsub(/^ +| +$/,""); print}')"
    if [[ -n "${fp}" && "${fp}" != "${expected_fp}" ]]; then
      st::war "Mozilla key fingerprint mismatch! Expected ${expected_fp}, got: ${fp}"
    fi
  fi

  install_sources \
    "/etc/apt/sources.list.d/mozilla.sources" "${sources_content}" \
    "/etc/apt/preferences.d/mozilla" "${pin_content}"
}

# }}} = Firefox =============================================================

# {{{ = Vivaldi =============================================================

setup_vivaldi() {
  local sources_content
  read -r -d '' sources_content <<'EOF' || true
Types: deb
URIs: https://repo.vivaldi.com/archive/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/vivaldi-keyring.gpg
EOF

  install_key "https://repo.vivaldi.com/stable/linux_signing_key.pub" \
    "/usr/share/keyrings/vivaldi-keyring.gpg" dearmor

  install_sources "/etc/apt/sources.list.d/vivaldi.sources" "${sources_content}"
}

# }}} = Vivaldi =============================================================

# {{{ = Google Chrome =======================================================

setup_chrome() {
  local sources_content
  read -r -d '' sources_content <<'EOF' || true
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF

  install_key "https://dl.google.com/linux/linux_signing_key.pub" \
    "/usr/share/keyrings/google-chrome.gpg" dearmor

  install_sources "/etc/apt/sources.list.d/google-chrome.sources" "${sources_content}"
}

# }}} = Google Chrome =======================================================

# {{{ = Brave ===============================================================

setup_brave() {
  local sources_content
  read -r -d '' sources_content <<'EOF' || true
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg
EOF

  install_key "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
    "/usr/share/keyrings/brave-browser-archive-keyring.gpg"

  install_sources "/etc/apt/sources.list.d/brave-browser.sources" "${sources_content}"
}

# }}} = Brave ===============================================================

# {{{ = Microsoft Edge ======================================================

setup_edge() {
  local sources_content
  read -r -d '' sources_content <<'EOF' || true
Types: deb
URIs: https://packages.microsoft.com/repos/edge/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft-edge.gpg
EOF

  install_key "https://packages.microsoft.com/keys/microsoft.asc" \
    "/usr/share/keyrings/microsoft-edge.gpg" dearmor

  install_sources "/etc/apt/sources.list.d/microsoft-edge.sources" "${sources_content}"
}

# }}} = Microsoft Edge ======================================================

module_run() {
  local entry name pkg install
  for entry in "${BROWSERS[@]}"; do
    IFS=: read -r name pkg install <<< "${entry}"
    st::hdr "${name} (${install})"
    "setup_${name}"
    [[ "${install}" == "yes" ]] && st::apt_install "${pkg}" || true
  done
}
