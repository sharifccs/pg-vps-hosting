#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'Run as root.' >&2; exit 1; }
echo '[+] Updating Hestia packages...'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y hestia hestia-nginx hestia-php 2>/dev/null || true
echo '[+] Updating/redeploying pinned pgAdmin image...'
cd /opt/pg-vps-hosting/pgadmin
if docker compose version >/dev/null 2>&1; then C=(docker compose); else C=(docker-compose); fi
"${C[@]}" --env-file .env pull
"${C[@]}" --env-file .env up -d --force-recreate
nginx -t && systemctl reload nginx
echo '[+] Update completed.'
