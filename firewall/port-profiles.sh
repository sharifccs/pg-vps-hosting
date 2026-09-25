#!/usr/bin/env bash
set -Eeuo pipefail
H=/usr/local/hestia/bin/v-add-firewall-rule
[ -x "$H" ] || { echo '[x] Hestia firewall command not found.' >&2; exit 1; }
add(){ "$H" ACCEPT 0.0.0.0/0 "$1" "$2" "$3" >/dev/null 2>&1 || true; }

mikrotik(){
  add 1001-1020 TCP 'PGHOST MikroTik-OLT TCP 1001-1020'
  add 1001-1020 UDP 'PGHOST MikroTik-OLT UDP 1001-1020'
  add 7001-7020 TCP 'PGHOST MikroTik-OLT TCP 7001-7020'
  add 7001-7020 UDP 'PGHOST MikroTik-OLT UDP 7001-7020'
  echo '[+] MikroTik/OLT profile added.'
}

vpn(){
  local p
  for p in 22 80 443 441 445 446 992 1080 1194 1701 1723 2222 3128 5555 8000-8002 8080 8388 8443; do
    add "$p" TCP "PGHOST VPN TCP $p"
  done
  for p in 53 443 500 1194 1701 3478 4500 51820 5666 8388 9993 41641; do
    add "$p" UDP "PGHOST VPN UDP $p"
  done
  read -rp 'Open large UDP range 20000-50000? Type YES: ' C
  [ "$C" = YES ] && add 20000-50000 UDP 'PGHOST VPN UDP 20000-50000'
  echo '[+] VPN/Xray/Proxy profile added.'
}

while true; do
cat <<'MENU'

PG Hosting Firewall Profiles
1) MikroTik / OLT profile
2) VPN / Xray / Proxy profile
3) Show Hestia firewall
0) Exit
MENU
read -rp 'Select > ' N
case "$N" in
  1) mikrotik;;
  2) vpn;;
  3) /usr/local/hestia/bin/v-list-firewall plain || true;;
  0) exit 0;;
  *) echo 'Invalid choice.';;
esac
done
