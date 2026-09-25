#!/usr/bin/env bash
set -Eeuo pipefail
BASE=/opt/pg-vps-hosting
source "$BASE/lib/common.sh"
IP=$(primary_ipv4 2>/dev/null || echo unknown)
HOST=$(hostname -f 2>/dev/null || hostname)
OS=$(awk -F= '$1=="PRETTY_NAME"{gsub(/^"|"$/,"",$2);print $2}' /etc/os-release 2>/dev/null || true)
HESTIA=not-installed
[ -d /usr/local/hestia ] && HESTIA=$(systemctl is-active hestia 2>/dev/null || echo installed)
PG=$(pg_lsclusters --no-header 2>/dev/null | awk '$1==18{print $4;exit}')
[ -n "$PG" ] || PG=not-found
PGA=$(docker inspect -f '{{.State.Status}}' pgadmin4 2>/dev/null || echo not-installed)
PGAHTTP=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 4 https://127.0.0.1:2084/ 2>/dev/null || true)
HHTTP=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 4 https://127.0.0.1:2083/ 2>/dev/null || true)
PHPV=$(find /etc/php -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | grep -E '^(7\.3|7\.4|8\.0|8\.1|8\.2|8\.3|8\.4)$' | sort -V | paste -sd, - || true)
[ -n "$PHPV" ] || PHPV=none
DOMAINS=0; DBS=0; CRONS=0
if hestia_ready; then
  DOMAINS=$(/usr/local/hestia/bin/v-list-web-domains admin json 2>/dev/null | jq 'length' 2>/dev/null || echo '?')
  DBS=$(/usr/local/hestia/bin/v-list-databases admin json 2>/dev/null | jq 'length' 2>/dev/null || echo '?')
  CRONS=$(/usr/local/hestia/bin/v-list-cron-jobs admin json 2>/dev/null | jq 'length' 2>/dev/null || echo '?')
fi
cat <<OUT
╔════════════════════════════════════════════════════════════════════╗
║                 PG HOSTING CONTROL CENTER V9                     ║
╚════════════════════════════════════════════════════════════════════╝
  Linux User       : $(id -un)
  Hostname         : $HOST
  OS               : ${OS:-unknown}
  Current VPS IP   : $IP
  Hestia Panel     : https://$IP:2083  (HTTP $HHTTP)
  Panel Login      : admin / admin
  Hestia Service   : $HESTIA
  PostgreSQL 18    : $PG
  pgAdmin          : https://$IP:2084  (container=$PGA, HTTP $PGAHTTP)
  pgAdmin Login    : sharifulislamccs@gmail.com / admin
  PHP Versions     : $PHPV
  Web Domains      : $DOMAINS
  PostgreSQL DBs   : $DBS
  Cron Jobs        : $CRONS
  DB Backups       : 03:15 + 15:15 daily, 14-day retention
OUT
if [ -f /etc/pg-hosting/nameservers.conf ]; then
  # shellcheck disable=SC1091
  source /etc/pg-hosting/nameservers.conf
  printf '  Name Servers     : %s / %s\n' "${NS1:-unset}" "${NS2:-unset}"
else
  printf '  Name Servers     : not configured yet\n'
fi
