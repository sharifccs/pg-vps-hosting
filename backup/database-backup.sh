#!/usr/bin/env bash
set -Eeuo pipefail
DIR=/var/backups/pg-hosting-database
RETENTION_DAYS=14
install -d -m 700 "$DIR"
TS=$(date -u +%Y%m%dT%H%M%SZ)
RUN="$DIR/$TS"
install -d -m 700 "$RUN"

ok=0

if command -v pg_dumpall >/dev/null 2>&1 && sudo -u postgres psql -XAtqc 'select 1' postgres >/dev/null 2>&1; then
  OUT="$RUN/postgresql-all.sql.gz"
  TMP="$OUT.tmp"
  echo "[+] PostgreSQL logical backup: $OUT"
  sudo -u postgres pg_dumpall --clean --if-exists | gzip -9 >"$TMP"
  gzip -t "$TMP"
  mv "$TMP" "$OUT"
  sha256sum "$OUT" >"$OUT.sha256"
  ok=1
fi

DUMP_BIN=""
command -v mariadb-dump >/dev/null 2>&1 && DUMP_BIN=mariadb-dump
[ -z "$DUMP_BIN" ] && command -v mysqldump >/dev/null 2>&1 && DUMP_BIN=mysqldump
if [ -n "$DUMP_BIN" ]; then
  OUT="$RUN/mariadb-all.sql.gz"
  TMP="$OUT.tmp"
  echo "[+] MariaDB/MySQL logical backup: $OUT"
  if "$DUMP_BIN" --all-databases --single-transaction --routines --events --triggers 2>/dev/null | gzip -9 >"$TMP"; then
    gzip -t "$TMP"
    mv "$TMP" "$OUT"
    sha256sum "$OUT" >"$OUT.sha256"
    ok=1
  else
    rm -f "$TMP"
    echo '[!] MariaDB/MySQL backup was skipped because local root authentication failed.' >&2
  fi
fi

cat >"$RUN/backup.meta" <<META
created_utc=$TS
hostname=$(hostname -f 2>/dev/null || hostname)
postgres_version=$(psql --version 2>/dev/null || true)
mysql_version=$(mariadb --version 2>/dev/null || mysql --version 2>/dev/null || true)
backup_scope=databases_only
META
chmod 600 "$RUN"/* 2>/dev/null || true

[ "$ok" -eq 1 ] || { rm -rf "$RUN"; echo '[x] No database backup could be created.' >&2; exit 1; }
find "$DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} +
echo '[+] Database-only backup complete.'
