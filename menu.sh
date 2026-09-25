#!/usr/bin/env bash
set -Eeuo pipefail
BASE=/opt/pg-vps-hosting
pause(){ read -rp 'Press Enter to continue...' _; }
while true; do
  clear || true
  bash "$BASE/status.sh" || true
  cat <<'MENU'

  1) Refresh server overview
  2) Show Hestia panel / hosting services
  3) Configure NS1 / NS2 nameservers
  4) List web domains
  5) Database manager (create / password / import / export / delete)
  6) List cron jobs
  7) Show installed PHP 7.3 - 8.4 runtimes
  8) Advanced PostgreSQL users / permissions
  9) Open MikroTik / VPN firewall profiles
 10) Database-only backup now
 11) Restore database backup
 12) pgAdmin status / last logs
 13) Restart pgAdmin
 14) Re-detect VPS IP (Hestia rebuild)
 15) Update Hestia + pgAdmin
 16) Uninstall / FULL PURGE
  0) Exit
MENU
  read -rp 'Select > ' N
  case "$N" in
    1) ;;
    2) systemctl --no-pager status hestia nginx apache2 postgresql named 2>/dev/null || true; pause;;
    3) bash "$BASE/nameservers.sh"; pause;;
    4) /usr/local/hestia/bin/v-list-web-domains admin plain 2>/dev/null || true; pause;;
    5) bash "$BASE/database/manager.sh";;
    6) /usr/local/hestia/bin/v-list-cron-jobs admin plain 2>/dev/null || true; pause;;
    7) for v in 7.3 7.4 8.0 8.1 8.2 8.3 8.4; do printf '%-4s : ' "$v"; systemctl is-active "php$v-fpm" 2>/dev/null || echo not-installed; done; pause;;
    8) bash "$BASE/postgresql/permission-manager.sh";;
    9) bash "$BASE/firewall/port-profiles.sh";;
    10) bash "$BASE/backup/database-backup.sh"; pause;;
    11) bash "$BASE/backup/database-restore.sh"; pause;;
    12) docker ps --filter name=pgadmin4; echo; docker logs --tail 80 pgadmin4 2>&1 || true; pause;;
    13) docker restart pgadmin4; sleep 3; pause;;
    14) bash "$BASE/ip-sync.sh"; pause;;
    15) bash "$BASE/update.sh"; pause;;
    16) bash "$BASE/uninstall.sh"; [ -d "$BASE" ] || exit 0; pause;;
    0) exit 0;;
    *) echo 'Invalid choice.'; sleep 1;;
  esac
done
