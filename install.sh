#!/usr/bin/env bash
set -Eeuo pipefail
BASE=$(cd "$(dirname "$0")" && pwd)
source "$BASE/lib/common.sh"
need_root
os_detect

ADMIN_USER=admin
ADMIN_PASSWORD=admin
ADMIN_EMAIL=sharifulislamccs@gmail.com
PANEL_PORT=2083
PGADMIN_PORT=2084
PGADMIN_EMAIL=sharifulislamccs@gmail.com
PGADMIN_PASSWORD=admin
PGADMIN_IMAGE=dpage/pgadmin4:9.18
MULTIPHP='7.3,7.4,8.0,8.1,8.2,8.3,8.4'
IP=$(primary_ipv4) || die 'Could not detect public/server IPv4.'
AUTO_HOSTNAME="panel.${IP}.nip.io"

printf '\n\033[1;36m╔════════════════════════════════════════════════════════════════════╗\033[0m\n'
printf '\033[1;36m║       PG HOSTING V10 - FULL WEB HOSTING + PostgreSQL/pgAdmin     ║\033[0m\n'
printf '\033[1;36m╚════════════════════════════════════════════════════════════════════╝\033[0m\n'
printf '  OS            : %s %s (%s)\n' "$OS_ID" "$OS_VER" "$OS_CODENAME"
printf '  VPS IP        : %s\n' "$IP"
printf '  Hosting Panel : https://%s:%s\n' "$IP" "$PANEL_PORT"
printf '  Panel Login   : %s / %s\n' "$ADMIN_USER" "$ADMIN_PASSWORD"
printf '  pgAdmin       : https://%s:%s\n' "$IP" "$PGADMIN_PORT"
printf '  pgAdmin Login : %s / %s\n' "$PGADMIN_EMAIL" "$PGADMIN_PASSWORD"
printf '  PHP           : %s\n' "$MULTIPHP"
printf '  PostgreSQL    : 18\n\n'

if [ -d /usr/local/hestia ]; then
  die 'Hestia is already installed. Use pg-hosting update or uninstall the existing stack first.'
fi
if getent passwd admin >/dev/null 2>&1; then
  die 'Linux user "admin" already exists. Hestia requires this username to be free on a new install.'
fi

# Hestia creates and owns the PostgreSQL PGDG APT source when --postgresql yes.
# Older PG Hosting versions and PostgreSQL's helper may have already created the
# same repository with a different Signed-By key. APT rejects that combination.
# Back up and disable every pre-existing PGDG source stanza before the first
# apt-get update; Hestia will recreate one canonical source later.
normalize_pgdg_sources() {
  local backup file tmp found=0
  backup="/root/pg-hosting-pgdg-source-backup-$(date +%Y%m%d%H%M%S)"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    found=1
    mkdir -p "$backup/$(dirname "${file#/}")"
    cp -a "$file" "$backup/${file#/}"
    case "$file" in
      *.sources)
        tmp="${file}.pg-hosting.tmp"
        awk 'BEGIN { RS=""; ORS="\n\n" } $0 !~ /apt\.postgresql\.org\/pub\/repos\/apt/' "$file" >"$tmp"
        if grep -q '[^[:space:]]' "$tmp"; then
          cat "$tmp" >"$file"
        else
          rm -f "$file"
        fi
        rm -f "$tmp"
        ;;
      *)
        sed -i '\#apt.postgresql.org/pub/repos/apt#d' "$file"
        grep -q '[^[:space:]]' "$file" 2>/dev/null || rm -f "$file"
        ;;
    esac
  done < <(grep -RIl --include='*.list' --include='*.sources' 'apt.postgresql.org/pub/repos/apt' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)

  if [ "$found" -eq 1 ]; then
    log "Disabled pre-existing PostgreSQL PGDG APT source definitions to prevent Signed-By conflicts."
    log "Backup saved under: $backup"
  else
    log 'No pre-existing PostgreSQL PGDG APT source conflict found.'
  fi
}

normalize_pgdg_sources

log 'Installing bootstrap dependencies...'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl wget gnupg jq unzip zip openssl sudo

# UFW and Hestia's iptables firewall should not compete for rule ownership.
if command -v ufw >/dev/null 2>&1; then
  warn 'Disabling UFW; Hestia will manage the server firewall with iptables/ipset.'
  ufw --force disable >/dev/null 2>&1 || true
fi

# Previous PG-only attempts may have left services installed even after their configs were removed.
# Stop them during Hestia bootstrap; Hestia will install/start its own web stack.
systemctl stop docker containerd nginx apache2 2>/dev/null || true

log 'PostgreSQL repository ownership: Hestia will create the canonical PGDG source and keyring.'
# Do not create a second apt.postgresql.org entry here. Hestia's official
# installer writes /etc/apt/sources.list.d/postgresql.list with its own
# Signed-By keyring when --postgresql yes. Keeping exactly one definition avoids
# APT's "Conflicting values set for option Signed-By" error.

log 'Downloading the official Hestia Control Panel installer from GitHub...'
TMP=$(mktemp -d -t hestia-installer.XXXXXXXX)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL --retry 3 https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh -o "$TMP/hst-install.sh"
chmod +x "$TMP/hst-install.sh"

log 'Installing the full web-hosting control panel on port 2083...'
bash "$TMP/hst-install.sh" \
  --interactive no \
  --hostname "$AUTO_HOSTNAME" \
  --email "$ADMIN_EMAIL" \
  --username "$ADMIN_USER" \
  --password "$ADMIN_PASSWORD" \
  --port "$PANEL_PORT" \
  --lang en \
  --apache yes \
  --phpfpm yes \
  --multiphp "$MULTIPHP" \
  --vsftpd yes \
  --proftpd no \
  --named yes \
  --mysql yes \
  --postgresql yes \
  --exim yes \
  --dovecot yes \
  --sieve yes \
  --clamav no \
  --spamassassin no \
  --iptables yes \
  --fail2ban yes \
  --quota no \
  --webterminal yes \
  --api yes \
  --force

hestia_ready || die 'Hestia installation did not create the expected CLI.'

# Make the requested credentials authoritative even if upstream defaults changed.
/usr/local/hestia/bin/v-change-user-password "$ADMIN_USER" "$ADMIN_PASSWORD" || true
/usr/local/hestia/bin/v-change-sys-port "$PANEL_PORT" || true
/usr/local/hestia/bin/v-change-sys-php 8.4 || true
/usr/local/hestia/bin/v-change-user-php-cli "$ADMIN_USER" 8.4 || true
/usr/local/hestia/bin/v-add-sys-filemanager >/dev/null 2>&1 || true

# Install Docker only after Hestia has completed its web/firewall stack setup.
log 'Installing Docker for the official pgAdmin module...'
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin 2>/dev/null || \
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose
systemctl enable --now docker

# The user requested automatic backups to be database-only. Disable Hestia's
# default daily full-user backup job while keeping manual Hestia backups available.
if [ -f /var/spool/cron/crontabs/hestiaweb ]; then
  sed -i '/v-backup-users/d' /var/spool/cron/crontabs/hestiaweb
  chown hestiaweb:hestiaweb /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
  chmod 600 /var/spool/cron/crontabs/hestiaweb 2>/dev/null || true
  systemctl reload cron 2>/dev/null || true
fi

log 'Installing PG Hosting management layer...'
rm -rf /opt/pg-vps-hosting
install -d -m 755 /opt/pg-vps-hosting /etc/pg-hosting /var/backups/pg-hosting-database
cp -a "$BASE"/. /opt/pg-vps-hosting/
find /opt/pg-vps-hosting -type f -name '*.sh' -exec chmod 755 {} +
chmod 755 /opt/pg-vps-hosting/pg-hosting
install -m 755 /opt/pg-vps-hosting/pg-hosting /usr/local/sbin/pg-hosting

log 'Verifying requested PHP runtimes and PostgreSQL 18...'
MISSING_PHP=()
for v in 7.3 7.4 8.0 8.1 8.2 8.3 8.4; do
  [ -x "/usr/bin/php${v}" ] || MISSING_PHP+=("$v")
done
[ "${#MISSING_PHP[@]}" -eq 0 ] || die "Missing requested PHP versions: ${MISSING_PHP[*]}"
PGVER_PRE=$(sudo -u postgres psql -XAtqc 'show server_version' postgres 2>/dev/null || true)
[[ "$PGVER_PRE" == 18* ]] || die "PostgreSQL 18 was not installed by the hosting stack (found: ${PGVER_PRE:-none})."

log 'Installing official pgAdmin 4 as a separate PostgreSQL administration module...'
install -d -m 700 /etc/pg-hosting/ssl
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 825 \
  -keyout /etc/pg-hosting/ssl/pgadmin-ip.key \
  -out /etc/pg-hosting/ssl/pgadmin-ip.crt \
  -subj "/CN=$IP" -addext "subjectAltName=IP:$IP" >/dev/null 2>&1
chmod 600 /etc/pg-hosting/ssl/pgadmin-ip.key
chmod 644 /etc/pg-hosting/ssl/pgadmin-ip.crt

cat >/opt/pg-vps-hosting/pgadmin/.env <<ENV
PGADMIN_IMAGE=$PGADMIN_IMAGE
PGADMIN_DEFAULT_EMAIL=$PGADMIN_EMAIL
PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASSWORD
ENV
chmod 600 /opt/pg-vps-hosting/pgadmin/.env
cd /opt/pg-vps-hosting/pgadmin
if docker compose version >/dev/null 2>&1; then C=(docker compose); else C=(docker-compose); fi
"${C[@]}" --env-file .env pull
"${C[@]}" --env-file .env up -d --force-recreate

for i in $(seq 1 40); do
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 http://127.0.0.1:5050/misc/ping 2>/dev/null || true)
  [ "$CODE" = 200 ] && break
  printf '\r[~] Waiting for pgAdmin backend... %2d/40 (HTTP %s)' "$i" "${CODE:-000}"
  sleep 3
done
printf '\n'
CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:5050/misc/ping 2>/dev/null || true)
[ "$CODE" = 200 ] || { docker logs --tail 120 pgadmin4 2>&1 || true; die "pgAdmin backend failed health check (HTTP ${CODE:-000})."; }

cp /opt/pg-vps-hosting/pgadmin/nginx-pgadmin.conf /etc/nginx/conf.d/pgadmin-vps.conf
nginx -t
systemctl reload nginx

# Hestia owns firewall rules. Add pgAdmin port through Hestia so it survives firewall rebuilds.
/usr/local/hestia/bin/v-add-firewall-rule ACCEPT 0.0.0.0/0 "$PGADMIN_PORT" TCP 'PG Hosting pgAdmin' >/dev/null 2>&1 || true

log 'Installing twice-daily database-only backup schedule...'
cp /opt/pg-vps-hosting/systemd/pg-hosting-db-backup.service /etc/systemd/system/
cp /opt/pg-vps-hosting/systemd/pg-hosting-db-backup.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now pg-hosting-db-backup.timer
cp /opt/pg-vps-hosting/systemd/pg-hosting-ip-sync.service /etc/systemd/system/
cp /opt/pg-vps-hosting/systemd/pg-hosting-ip-sync.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now pg-hosting-ip-sync.timer

log 'Running final health verification...'
PANEL_CODE=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://127.0.0.1:$PANEL_PORT/" 2>/dev/null || true)
case "$PANEL_CODE" in 2*|3*|401|403) ;; *) die "Hestia panel failed local health check: HTTP ${PANEL_CODE:-000}";; esac
PGA_CODE=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://127.0.0.1:$PGADMIN_PORT/" 2>/dev/null || true)
case "$PGA_CODE" in 2*|3*) ;; *) die "pgAdmin proxy failed local health check: HTTP ${PGA_CODE:-000}";; esac
PGVER=$(sudo -u postgres psql -XAtqc 'show server_version' postgres 2>/dev/null || true)
[[ "$PGVER" == 18* ]] || warn "PostgreSQL is running version '${PGVER:-unknown}', expected 18.x. Check pg_lsclusters."

cat >/etc/pg-hosting/install.conf <<CONF
SERVER_IP=$IP
HESTIA_PORT=$PANEL_PORT
PGADMIN_PORT=$PGADMIN_PORT
PANEL_USER=$ADMIN_USER
PANEL_PASSWORD=$ADMIN_PASSWORD
PGADMIN_EMAIL=$PGADMIN_EMAIL
PGADMIN_PASSWORD=$PGADMIN_PASSWORD
AUTO_HOSTNAME=$AUTO_HOSTNAME
CONF
chmod 600 /etc/pg-hosting/install.conf

printf '\n\033[1;32m╔════════════════════════════════════════════════════════════════════╗\033[0m\n'
printf '\033[1;32m║                    INSTALLATION COMPLETED                        ║\033[0m\n'
printf '\033[1;32m╚════════════════════════════════════════════════════════════════════╝\033[0m\n'
printf '  Full Hosting Panel : https://%s:%s\n' "$IP" "$PANEL_PORT"
printf '  Username           : %s\n' "$ADMIN_USER"
printf '  Password           : %s\n' "$ADMIN_PASSWORD"
printf '\n'
printf '  pgAdmin 4          : https://%s:%s\n' "$IP" "$PGADMIN_PORT"
printf '  Email              : %s\n' "$PGADMIN_EMAIL"
printf '  Password           : %s\n' "$PGADMIN_PASSWORD"
printf '\n'
printf '  PostgreSQL         : %s\n' "${PGVER:-18.x}"
printf '  PHP                : 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4\n'
printf '  DB Backup          : 03:15 + 15:15 daily / 14 days\n'
printf '  SSH Manager        : pg-hosting\n'
printf '\n'
printf '  Next: run "pg-hosting" and configure NS1/NS2 when your hosting domain is ready.\n\n'
