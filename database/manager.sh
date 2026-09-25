#!/usr/bin/env bash
set -Eeuo pipefail
H=/usr/local/hestia/bin
USER=admin
[ -x "$H/v-list-databases" ] || { echo '[x] Hestia database CLI not found.' >&2; exit 1; }

list_db(){ "$H/v-list-databases" "$USER" plain || true; }
create_db(){
  local name dbuser pass type
  echo 'Database type: 1=PostgreSQL  2=MariaDB/MySQL'
  read -rp 'Select: ' type
  case "$type" in 1) type=pgsql;; 2) type=mysql;; *) echo '[x] Invalid type.'; return 1;; esac
  read -rp 'Database short name (Hestia adds admin_ prefix): ' name
  read -rp 'Database user short name (Hestia adds admin_ prefix): ' dbuser
  read -rsp 'Database password: ' pass; echo
  [[ "$name" =~ ^[A-Za-z0-9_]+$ && "$dbuser" =~ ^[A-Za-z0-9_]+$ && -n "$pass" ]] || { echo '[x] Invalid input.' >&2; return 1; }
  "$H/v-add-database" "$USER" "$name" "$dbuser" "$pass" "$type" localhost UTF8
  echo '[+] Database created.'
}
change_pass(){
  local db pass
  read -rp 'Full database name (example: admin_app): ' db
  read -rsp 'New database password: ' pass; echo
  [ -n "$db" ] && [ -n "$pass" ] || return 1
  "$H/v-change-database-password" "$USER" "$db" "$pass"
  echo '[+] Database password changed.'
}
delete_db(){
  local db c
  read -rp 'Full database name to DELETE: ' db
  read -rp "Type DELETE $db : " c
  [ "$c" = "DELETE $db" ] || { echo 'Cancelled.'; return 0; }
  "$H/v-delete-database" "$USER" "$db"
  echo '[+] Database deleted.'
}
export_db(){
  local db out
  read -rp 'Full database name: ' db
  [ -n "$db" ] || return 1
  install -d -m 700 /var/backups/pg-hosting-database/manual
  out="/var/backups/pg-hosting-database/manual/${db}-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
  echo "[+] Exporting $db ..."
  "$H/v-dump-database" "$USER" "$db" | gzip -9 >"$out"
  gzip -t "$out"
  sha256sum "$out" >"$out.sha256"
  chmod 600 "$out" "$out.sha256"
  echo "[+] Export created: $out"
}
import_db(){
  local db path
  read -rp 'Full database name: ' db
  read -rp 'Absolute path to .sql or .sql.gz: ' path
  [ -f "$path" ] || { echo '[x] File not found.' >&2; return 1; }
  tmp=''
  if [[ "$path" = *.gz ]]; then
    tmp=$(mktemp -t pghost-import.XXXXXX.sql)
    gzip -dc "$path" >"$tmp"
    path="$tmp"
  fi
  "$H/v-import-database" "$USER" "$db" "$path"
  [ -z "$tmp" ] || rm -f "$tmp"
  echo '[+] Import completed.'
}
while true; do
cat <<'MENU'

Database Manager (Hestia synchronized)
1) List databases
2) Create database + database user/password
3) Change database password
4) Import SQL into existing database
5) Export database
6) Delete database
7) Advanced PostgreSQL users / permissions
0) Exit
MENU
read -rp 'Select > ' N
case "$N" in
  1) list_db;;
  2) create_db;;
  3) change_pass;;
  4) import_db;;
  5) export_db;;
  6) delete_db;;
  7) bash /opt/pg-vps-hosting/postgresql/permission-manager.sh;;
  0) exit 0;;
  *) echo 'Invalid choice.';;
esac
done
