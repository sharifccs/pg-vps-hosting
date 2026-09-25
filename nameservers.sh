#!/usr/bin/env bash
set -Eeuo pipefail
BASE=/opt/pg-vps-hosting
source "$BASE/lib/common.sh"
need_root
hestia_ready || die 'Hestia is not installed.'
IP=$(primary_ipv4)
read -rp 'NS1 hostname (example: ns1.example.com): ' NS1
read -rp 'NS2 hostname (example: ns2.example.com): ' NS2
valid_domain "$NS1" || die 'Invalid NS1 hostname.'
valid_domain "$NS2" || die 'Invalid NS2 hostname.'
/usr/local/hestia/bin/v-change-user-ns admin "$NS1" "$NS2"
mkdir -p /etc/pg-hosting
cat >/etc/pg-hosting/nameservers.conf <<CONF
NS1=$NS1
NS2=$NS2
IP=$IP
CONF
chmod 600 /etc/pg-hosting/nameservers.conf
cat <<OUT

[+] Default Hestia nameservers updated.

Registrar / Glue records required:
  $NS1  ->  $IP
  $NS2  ->  $IP

Then set the hosted domain's authoritative nameservers to:
  $NS1
  $NS2

IMPORTANT: Both names currently point to the same VPS IP. This works functionally,
but real DNS redundancy requires NS2 on a different server/IP.
OUT
