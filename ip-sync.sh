#!/usr/bin/env bash
set -Eeuo pipefail
BASE=/opt/pg-vps-hosting
source "$BASE/lib/common.sh"
need_root
NEW_IP=$(primary_ipv4) || die 'Could not determine current IPv4.'
OLD_IP=''
[ -f /etc/pg-hosting/install.conf ] && OLD_IP=$(sed -n 's/^SERVER_IP=//p' /etc/pg-hosting/install.conf | head -n1)

if [ "$NEW_IP" = "$OLD_IP" ] && [ "${1:-}" = '--quiet' ]; then exit 0; fi

[ -x /usr/local/hestia/bin/v-update-sys-ip ] && /usr/local/hestia/bin/v-update-sys-ip >/dev/null 2>&1 || true

if [ "$NEW_IP" != "$OLD_IP" ]; then
  install -d -m 700 /etc/pg-hosting/ssl
  openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 825 \
    -keyout /etc/pg-hosting/ssl/pgadmin-ip.key \
    -out /etc/pg-hosting/ssl/pgadmin-ip.crt \
    -subj "/CN=$NEW_IP" -addext "subjectAltName=IP:$NEW_IP" >/dev/null 2>&1
  chmod 600 /etc/pg-hosting/ssl/pgadmin-ip.key
  chmod 644 /etc/pg-hosting/ssl/pgadmin-ip.crt
  if [ -f /etc/pg-hosting/install.conf ]; then
    if grep -q '^SERVER_IP=' /etc/pg-hosting/install.conf; then
      sed -i "s/^SERVER_IP=.*/SERVER_IP=$NEW_IP/" /etc/pg-hosting/install.conf
    else
      printf 'SERVER_IP=%s\n' "$NEW_IP" >>/etc/pg-hosting/install.conf
    fi
  fi
  nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
  logger -t pg-hosting "Public IP changed: ${OLD_IP:-unknown} -> $NEW_IP"
fi

if [ "${1:-}" != '--quiet' ]; then
  echo "[+] Current public IPv4: $NEW_IP"
  [ "$NEW_IP" = "$OLD_IP" ] || echo "[!] Public IP changed from ${OLD_IP:-unknown}. Update registrar glue records, Cloudflare A records and any external DNS that still points to the old IP."
  bash "$BASE/status.sh"
fi
