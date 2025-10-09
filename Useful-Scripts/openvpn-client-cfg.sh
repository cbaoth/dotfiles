#!/usr/bin/env bash
set -euo pipefail

# === Defaults (override via env if needed) ===
EASYRSA_DIR="${EASYRSA_DIR:-$HOME/openvpn-ca}"
PKI_DIR="$EASYRSA_DIR/pki"
SERVER_CONF="${SERVER_CONF:-/etc/openvpn/server/server.conf}"
CCD_DIR="${CCD_DIR:-/etc/openvpn/ccd}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME}"
REMOTE_HOST="${REMOTE_HOST:-$(hostname -f)}"

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
sudoc(){ if [ "$EUID" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

need openssl
need awk
need grep
need sed
need date
[ -x "$EASYRSA_DIR/easyrsa" ] || die "easyrsa not found at $EASYRSA_DIR/easyrsa (set EASYRSA_DIR)"

# Avoid Easy-RSA host OS mis-detect on zsh/dash
export easyrsa_host_os=nix
export EASYRSA_BATCH=1

# Fix ownership pitfalls if some PKI files were created as root
fix_pki_owner(){
  if [ -d "$EASYRSA_DIR" ]; then
    local owner; owner="$(stat -c %U "$EASYRSA_DIR" 2>/dev/null || echo "")"
    if [ -n "$owner" ] && [ "$owner" != "$(id -un)" ]; then
      sudoc chown -R "$(id -un)":"$(id -gn)" "$EASYRSA_DIR"
    fi
  fi
}
fix_pki_owner

# Ensure CA present in PKI
[ -s "$PKI_DIR/private/ca.key" ] || die "missing $PKI_DIR/private/ca.key (import your CA)"
[ -s "$PKI_DIR/ca.crt" ] || die "missing $PKI_DIR/ca.crt (import your CA)"

# Detect server params
detect_port(){ awk '/^[[:space:]]*port[[:space:]]/{print $2;exit}' "$SERVER_CONF" 2>/dev/null || true; }
detect_proto(){ awk '/^[[:space:]]*proto[[:space:]]/{print $2;exit}' "$SERVER_CONF" 2>/dev/null || true; }
detect_net(){ awk '/^[[:space:]]*server[[:space:]]+[0-9]/{print $2,$3;exit}' "$SERVER_CONF" 2>/dev/null || true; }
detect_tls_mode(){
  if grep -Eq '^[[:space:]]*tls-crypt[[:space:]]+' "$SERVER_CONF"; then
    echo "crypt $(awk '/^[[:space:]]*tls-crypt[[:space:]]+/{print $2;exit}' "$SERVER_CONF")"
  elif grep -Eq '^[[:space:]]*tls-auth[[:space:]]+' "$SERVER_CONF"; then
    echo "auth $(awk '/^[[:space:]]*tls-auth[[:space:]]+/{print $2;exit}' "$SERVER_CONF")"
  else
    echo "none"
  fi
}

PORT="$(detect_port)"; PORT="${PORT:-1194}"
PROTO="$(detect_proto)"; PROTO="${PROTO:-udp}"
read -r VPN_NET VPN_MASK <<<"$(detect_net)"; VPN_NET="${VPN_NET:-10.10.0.0}"; VPN_MASK="${VPN_MASK:-255.255.255.0}"
read -r TLS_MODE TLS_KEY <<<"$(detect_tls_mode)"

# Is a CCD IP already in use by a different CN?
ip_in_use(){
  local ip="$1"; local cn="$2"
  shopt -s nullglob
  for f in "$CCD_DIR"/*; do
    [ -f "$f" ] || continue
    local existing_ip
    existing_ip="$(awk '/^ifconfig-push[[:space:]]/{print $2; exit}' "$f" 2>/dev/null || true)"
    if [ -n "$existing_ip" ] && [ "$existing_ip" = "$ip" ]; then
      local holder; holder="$(basename "$f")"
      if [ "$holder" != "$cn" ]; then
        echo "$holder"
        return 0
      fi
    fi
  done
  return 1
}

# Light sanity: for /24 masks, ensure IP prefix matches VPN_NET prefix
verify_ip_in_subnet(){
  local ip="$1"
  if [ "$VPN_MASK" = "255.255.255.0" ]; then
    local ip_pfx="${ip%.*}"
    local net_pfx="${VPN_NET%.*}"
    [ "$ip_pfx" = "$net_pfx" ]
  else
    return 0
  fi
}

# Render client .ovpn
render_ovpn(){
  local cn="$1"; local outfile="$2"; local split="${3:-1}"; local routes_csv="${4:-}"

  : > "$outfile"
  {
    echo "client"
    echo "dev tun"
    echo "proto $PROTO"
    echo "remote $REMOTE_HOST $PORT"
    echo "resolv-retry infinite"
    echo "nobind"
    echo "persist-key"
    echo "persist-tun"
    if [ "$split" = "1" ]; then
      echo "route-nopull"
      echo "route $VPN_NET $VPN_MASK"
      if [ -n "$routes_csv" ]; then
        IFS=',' read -r -a arr <<<"$routes_csv"
        for r in "${arr[@]}"; do
          if [[ "$r" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([0-9]+)$ ]]; then
            cidr="${BASH_REMATCH[2]}"
            case "$cidr" in
              32) mask=255.255.255.255 ;;
              30) mask=255.255.255.252 ;;
              29) mask=255.255.255.248 ;;
              28) mask=255.255.255.240 ;;
              27) mask=255.255.255.224 ;;
              26) mask=255.255.255.192 ;;
              25) mask=255.255.255.128 ;;
              24) mask=255.255.255.0 ;;
              16) mask=255.255.0.0 ;;
              8)  mask=255.0.0.0 ;;
              *)  mask="";;
            esac
            net="${BASH_REMATCH[1]}"
            [ -n "$mask" ] && echo "route $net $mask"
          elif [[ "$r" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            echo "route ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
          fi
        done
      fi
    fi
    echo "remote-cert-tls server"
    echo "auth SHA256"
    echo "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305"
    echo "verb 3"
    echo "auth-nocache"
    echo
    echo "<ca>"
    cat /etc/openvpn/ca.crt
    echo "</ca>"
    echo "<cert>"
    cat "$PKI_DIR/issued/$cn.crt"
    echo "</cert>"
    echo "<key>"
    cat "$PKI_DIR/private/$cn.key"
    echo "</key>"
    case "$TLS_MODE" in
      crypt)
        echo "<tls-crypt>"
        sudoc bash -c "cat '$TLS_KEY'"
        echo "</tls-crypt>"
        ;;
      auth)
        echo "key-direction 1"
        echo "<tls-auth>"
        sudoc bash -c "cat '$TLS_KEY'"
        echo "</tls-auth>"
        ;;
      *)
        echo "# NOTE: no tls-crypt/auth found on server; continuing without inline key"
        ;;
    esac
  } >>"$outfile"
}

# Ensure server uses a CRL and install a fresh one
ensure_crl_enabled(){
  local crl="/etc/openvpn/crl.pem"
  (
    cd "$EASYRSA_DIR"
    export easyrsa_host_os=nix EASYRSA_BATCH=1
    ./easyrsa gen-crl
  )
  sudoc install -m 644 "$PKI_DIR/crl.pem" "$crl"
  if ! grep -Eq '^[[:space:]]*crl-verify[[:space:]]+/etc/openvpn/crl\.pem' "$SERVER_CONF"; then
    echo "crl-verify /etc/openvpn/crl.pem" | sudoc tee -a "$SERVER_CONF" >/dev/null
  fi
  # Neustart, damit bestehende Sessions gekappt werden
  if systemctl list-unit-files | grep -q '^openvpn-server@'; then
    sudoc systemctl restart openvpn-server@server
  else
    sudoc systemctl restart openvpn
  fi
}

# Revoke existing cert for CN (safe to call if absent)
revoke_cert_if_exists(){
  local cn="$1"
  local cert="$PKI_DIR/issued/$cn.crt"
  if [ -s "$cert" ]; then
    (
      cd "$EASYRSA_DIR"
      export easyrsa_host_os=nix EASYRSA_BATCH=1
      ./easyrsa revoke "$cn" || die "Revoke failed for $cn"
    )
  else
    echo "No issued cert found for '$cn' (maybe already revoked or never issued)." >&2
  fi
}

# Backup old key/req if present to avoid Easy-RSA collisions
backup_old_key_req(){
  local cn="$1"; local ts; ts="$(date +%F_%H%M%S)"
  [ -f "$PKI_DIR/private/$cn.key" ] && mv "$PKI_DIR/private/$cn.key" "$PKI_DIR/private/${cn}.key.$ts.bak"
  [ -f "$PKI_DIR/reqs/$cn.req" ] && mv "$PKI_DIR/reqs/$cn.req" "$PKI_DIR/reqs/${cn}.req.$ts.bak"
}

# List CCDs
do_list(){
  echo "CN                        IP (if any)       CERT(issued?)   EXPIRES"
  echo "---------------------------------------------------------------"
  shopt -s nullglob
  for f in "$CCD_DIR"/*; do
    [ -f "$f" ] || continue
    cn="$(basename "$f")"
    ip="$(awk '/^ifconfig-push/ {print $2}' "$f" 2>/dev/null || true)"
    cert="$PKI_DIR/issued/$cn.crt"
    if [ -s "$cert" ]; then
      exp="$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//')"
      printf "%-24s %-16s %-14s %s\n" "$cn" "${ip:-"-"}" "yes" "${exp:-"-"}"
    else
      printf "%-24s %-16s %-14s %s\n" "$cn" "${ip:-"-"}" "no" "-"
    fi
  done
}

# Delete/disable CCD (reversible)
do_delete(){
  local cn="$1"
  [ -n "$cn" ] || die "missing client name for --delete"
  [ -f "$CCD_DIR/$cn" ] || die "no CCD found for $cn in $CCD_DIR"
  sudoc mkdir -p "$CCD_DIR.disabled"
  local stamp; stamp="$(date +%F_%H%M%S)"
  sudoc mv "$CCD_DIR/$cn" "$CCD_DIR.disabled/${cn}_$stamp"
  echo "CCD for $cn moved to $CCD_DIR.disabled/${cn}_$stamp (reversible)."
  echo "NOTE: certificate NOT revoked."
}

# Revoke a client certificate and disable its CCD (reversible CCD move)
do_revoke(){
  local cn="$1"
  [ -n "$cn" ] || die "missing client name for --revoke"
  revoke_cert_if_exists "$cn"
  ensure_crl_enabled
  # CCD beiseite räumen (optional aber sinnvoll)
  if [ -f "$CCD_DIR/$cn" ]; then
    sudoc mkdir -p "$CCD_DIR.disabled"
    local stamp; stamp="$(date +%F_%H%M%S)"
    sudoc mv "$CCD_DIR/$cn" "$CCD_DIR.disabled/${cn}_$stamp"
    echo "CCD for $cn moved to $CCD_DIR.disabled/${cn}_$stamp."
  fi
  echo "Revoked '$cn' and refreshed CRL. Active sessions were dropped by restart."
}

# Create a new client config including certificate
do_create(){
  local cn="$1"; local ip="${2:-}"; local split="1"; local routes="${3:-}"
  [ -n "$cn" ] || die "client name required"
  split="${SPLIT:-1}"

  # --- PRE-FLIGHT: static IP checks (before any cert work) ---
  if [ -n "$ip" ]; then
    if ! verify_ip_in_subnet "$ip" && [ "${FORCE:-0}" -ne 1 ]; then
      die "IP $ip scheint nicht im VPN-Subnetz $VPN_NET/$VPN_MASK zu liegen (nutze --force zum Überschreiben)."
    fi
    if [ "${FORCE:-0}" -ne 1 ]; then
      holder="$(ip_in_use "$ip" "$cn" || true)"
      [ -n "$holder" ] && die "IP $ip ist bereits per CCD an '$holder' vergeben. Wähle eine andere IP oder nutze --force."
    fi
    if [ -f "$CCD_DIR/$cn" ] && [ "${FORCE:-0}" -ne 1 ]; then
      existing="$(awk '/^ifconfig-push[[:space:]]/{print $2}' "$CCD_DIR/$cn" 2>/dev/null || true)"
      if [ -n "$existing" ] && [ "$existing" != "$ip" ]; then
        die "CCD für '$cn' existiert bereits mit IP $existing. Nutze --force zum Überschreiben oder verwende diese IP."
      fi
    fi
  fi
  # Wenn bereits ein aktives Zertifikat existiert: ohne --force abbrechen
  if [ -s "$PKI_DIR/issued/$cn.crt" ] && [ "${FORCE:-0}" -ne 1 ]; then
    die "Zertifikat für '$cn' existiert bereits. Nutze --force oder wähle einen anderen CN."
  fi
  # Mit --force: altes Zertifikat revoken + CRL aktualisieren, alte key/req sichern
  if [ -s "$PKI_DIR/issued/$cn.crt" ] && [ "${FORCE:-0}" -eq 1 ]; then
    revoke_cert_if_exists "$cn"
    backup_old_key_req "$cn"
  fi
  # --- END PRE-FLIGHT ---

  # Generate & sign (neuer Key/REQ by design)
  ( cd "$EASYRSA_DIR"
    export easyrsa_host_os=nix EASYRSA_BATCH=1
    ./easyrsa gen-req "$cn" nopass
    ./easyrsa sign-req client "$cn"
  )

  # Optional static IP via CCD (or ensure empty CCD for ccd-exclusive)
  if [ -n "$ip" ]; then
    sudoc tee "$CCD_DIR/$cn" >/dev/null <<<"ifconfig-push $ip 255.255.255.0"
    echo "CCD created: $CCD_DIR/$cn"
  else
    sudoc touch "$CCD_DIR/$cn"
  fi

  # Render .ovpn
  local iso; iso="$(date +%F)"
  local outfile="$OUTPUT_DIR/${cn}_${iso}.ovpn"
  render_ovpn "$cn" "$outfile" "$split" "$routes"
  chmod 600 "$outfile"
  echo "Client profile written: $outfile"
}

usage(){
  cat <<USAGE
Usage:
  openvpn-client-cfg CLIENT_NAME [--ip IP] [--remote HOST] [--routes "NET1/MASK,NET2/MASK"] [--no-split] [--force]
  openvpn-client-cfg --list
  openvpn-client-cfg --delete CLIENT_NAME
  openvpn-client-cfg --revoke CLIENT_NAME

Options:
  --ip IP           Assign static IP via CCD (topology subnet; /24 mask assumed)
  --remote HOST     Override remote host (default: $REMOTE_HOST)
  --routes CSV      Extra routes for split-tunnel (e.g. "192.168.1.0/24,10.23.0.0/16")
  --no-split        Do NOT add route-nopull (internet / non-vpn traffic routed through vpn)
  --force|-f        Override safety checks (IP duplicate/subnet/CCD overwrite)

  --list|-l         List CCDs with optional IPs and cert expiry

  --delete|-d NAME  Disable a client by moving CCD to ccd.disabled (no revoke)
  --revoke|-r NAME  Revoke client's cert, refresh CRL, disable CCD

Example:
  # Create a new client configuration named "myworkstation" using static IP 10.10.0.5
  openvpn-client-cfg myworkstation --ip 10.10.0.5

Env overrides:
  EASYRSA_DIR=$EASYRSA_DIR
  SERVER_CONF=$SERVER_CONF
  CCD_DIR=$CCD_DIR
  OUTPUT_DIR=$OUTPUT_DIR
USAGE
}

# === Argparse ===
if [ $# -eq 0 ]; then usage; exit 1; fi

case "${1:-}" in
  --list|-l) do_list; exit 0;;
  --delete|-d) shift; do_delete "${1:-}"; exit 0;;
  --revoke|-r) shift; do_revoke "${1:-}"; exit 0;;
  --help|-h) usage; exit 0;;
esac

CN=""
IP_OPT=""
ROUTES_OPT=""
SPLIT=1
FORCE=0

CN="$1"; shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --ip) IP_OPT="${2:-}"; shift 2;;
    --remote) REMOTE_HOST="${2:-}"; shift 2;;
    --routes) ROUTES_OPT="${2:-}"; shift 2;;
    --no-split) SPLIT=0; shift;;
    --force|-f) FORCE=1; shift;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

do_create "$CN" "${IP_OPT:-}" "${ROUTES_OPT:-}"
