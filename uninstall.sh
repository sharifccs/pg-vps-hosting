#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'Run as root.' >&2; exit 1; }
BASE=/opt/pg-vps-hosting
cat <<'MENU'

╔══════════════════════════════════════════════════════════════╗
║                  PG HOSTING UNINSTALL V9                   ║
╚══════════════════════════════════════════════════════════════╝
1) Remove PG Hosting addon + pgAdmin only
   KEEP Hestia websites, DNS, mail, PostgreSQL databases and /home data
2) FULL PURGE hosting stack and all Hestia-managed hosting data
0) Cancel
MENU
read -rp 'Select > ' N
case "$N" in
  1)
    systemctl disable --now pg-hosting-db-backup.timer pg-hosting-ip-sync.timer 2>/dev/null || true
    rm -f /etc/systemd/system/pg-hosting-db-backup.{service,timer} /etc/systemd/system/pg-hosting-ip-sync.{service,timer}
    systemctl daemon-reload
    if [ -d "$BASE/pgadmin" ]; then
      cd "$BASE/pgadmin"
      if docker compose version >/dev/null 2>&1; then docker compose --env-file .env down -v --remove-orphans || true; else docker-compose --env-file .env down -v --remove-orphans || true; fi
    fi
    docker rm -f pgadmin4 >/dev/null 2>&1 || true
    rm -f /etc/nginx/conf.d/pgadmin-vps.conf
    nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
    rm -f /usr/local/sbin/pg-hosting
    rm -rf /etc/pg-hosting "$BASE"
    echo '[+] PG Hosting addon removed. Hestia and hosted data were kept.'
    ;;
  2)
    cat <<'WARN'
DANGER: this will delete Hestia-managed hosting users/sites/DNS/mail configuration,
PostgreSQL/MariaDB databases, pgAdmin data and PG Hosting database backups.
WARN
    read -rp 'Type exactly PURGE ALL HOSTING DATA : ' C
    [ "$C" = 'PURGE ALL HOSTING DATA' ] || { echo 'Cancelled.'; exit 0; }
    systemctl disable --now pg-hosting-db-backup.timer pg-hosting-ip-sync.timer 2>/dev/null || true
    if [ -d "$BASE/pgadmin" ]; then
      cd "$BASE/pgadmin"
      if docker compose version >/dev/null 2>&1; then docker compose --env-file .env down -v --remove-orphans || true; else docker-compose --env-file .env down -v --remove-orphans || true; fi
    fi
    docker rm -f pgadmin4 >/dev/null 2>&1 || true
    # Capture Hestia-created users before removing Hestia.
    USERS=""
    if [ -x /usr/local/hestia/bin/v-list-users ]; then
      USERS=$(/usr/local/hestia/bin/v-list-users json 2>/dev/null | jq -r 'keys[]' 2>/dev/null || true)
    fi
    systemctl stop hestia nginx apache2 postgresql postgresql@18-main mariadb mysql bind9 named exim4 dovecot vsftpd fail2ban docker containerd 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get purge -y \
      'hestia*' hestia-nginx hestia-php hestia-web-terminal \
      nginx 'apache2*' \
      'php7.3*' 'php7.4*' 'php8.0*' 'php8.1*' 'php8.2*' 'php8.3*' 'php8.4*' \
      mariadb-server mariadb-client mariadb-common \
      postgresql-18 postgresql-client-18 postgresql-common \
      bind9 vsftpd 'exim4*' 'dovecot*' fail2ban \
      docker.io docker-compose docker-compose-plugin containerd runc >/dev/null 2>&1 || true
    for u in $USERS; do
      [ "$u" = root ] && continue
      id "$u" >/dev/null 2>&1 && userdel -r "$u" >/dev/null 2>&1 || true
    done
    rm -rf /usr/local/hestia /etc/hestiacp /var/lib/postgresql /etc/postgresql
    rm -rf /var/lib/mysql /etc/mysql /etc/php /etc/apache2 /etc/nginx /etc/bind /etc/exim4 /etc/dovecot
    rm -rf /var/backups/pg-hosting-database /backup /etc/pg-hosting "$BASE"
    rm -f /root/.my.cnf /etc/vsftpd.conf
    rm -f /etc/nginx/conf.d/pgadmin-vps.conf /usr/local/sbin/pg-hosting
    rm -f /etc/systemd/system/pg-hosting-db-backup.{service,timer} /etc/systemd/system/pg-hosting-ip-sync.{service,timer}
    systemctl daemon-reload
    echo '[+] FULL PURGE completed.'
    ;;
  0) exit 0;;
  *) echo 'Invalid choice.'; exit 2;;
esac
