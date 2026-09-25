#!/usr/bin/env bash
set -Eeuo pipefail
DIR=/var/backups/pg-hosting-database
mapfile -t FILES < <(find "$DIR" -mindepth 2 -maxdepth 2 -type f \( -name 'postgresql-all.sql.gz' -o -name 'mariadb-all.sql.gz' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | cut -d' ' -f2-)
[ "${#FILES[@]}" -gt 0 ] || { echo '[x] No database backups found.' >&2; exit 1; }
echo 'Available database backups:'
for i in "${!FILES[@]}"; do printf '%2d) %s\n' "$((i+1))" "${FILES[$i]}"; done
read -rp 'Select backup number: ' N
[[ "$N" =~ ^[0-9]+$ ]] && [ "$N" -ge 1 ] && [ "$N" -le "${#FILES[@]}" ] || { echo '[x] Invalid selection.' >&2; exit 1; }
FILE="${FILES[$((N-1))]}"
[ -f "$FILE.sha256" ] && (cd "$(dirname "$FILE")" && sha256sum -c "$(basename "$FILE").sha256")
gzip -t "$FILE"
echo
printf 'Selected: %s\n' "$FILE"
read -rp 'Type RESTORE DATABASES to continue: ' C
[ "$C" = 'RESTORE DATABASES' ] || { echo 'Cancelled.'; exit 0; }
LOG="/var/log/pg-hosting-restore-$(date +%s).log"
case "$(basename "$FILE")" in
  postgresql-all.sql.gz)
    echo '[+] Terminating active PostgreSQL sessions...'
    sudo -u postgres psql -XAtqc "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname IS NOT NULL" postgres >/dev/null || true
    echo '[+] Restoring PostgreSQL logical backup...'
    set +e
    gzip -dc "$FILE" | sudo -u postgres psql -X -v ON_ERROR_STOP=0 postgres 2>&1 | tee "$LOG"
    RC=${PIPESTATUS[1]}
    set -e
    [ "$RC" -eq 0 ] || echo "[!] PostgreSQL restore returned $RC. Review $LOG" >&2
    ;;
  mariadb-all.sql.gz)
    DBCLI=""
    command -v mariadb >/dev/null 2>&1 && DBCLI=mariadb
    [ -z "$DBCLI" ] && command -v mysql >/dev/null 2>&1 && DBCLI=mysql
    [ -n "$DBCLI" ] || { echo '[x] MariaDB/MySQL client not found.' >&2; exit 1; }
    echo '[+] Restoring MariaDB/MySQL logical backup...'
    gzip -dc "$FILE" | "$DBCLI" 2>&1 | tee "$LOG"
    ;;
  *) echo '[x] Unsupported backup type.' >&2; exit 1;;
esac
echo "[+] Restore finished. Log: $LOG"
