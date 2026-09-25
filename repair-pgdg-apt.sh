#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'Run as root.' >&2; exit 1; }
BACKUP="/root/pg-hosting-pgdg-source-backup-$(date +%Y%m%d%H%M%S)"
FOUND=0
while IFS= read -r FILE; do
  [ -n "$FILE" ] || continue
  FOUND=1
  mkdir -p "$BACKUP/$(dirname "${FILE#/}")"
  cp -a "$FILE" "$BACKUP/${FILE#/}"
  case "$FILE" in
    *.sources)
      TMP="${FILE}.pg-hosting.tmp"
      awk 'BEGIN { RS=""; ORS="\n\n" } $0 !~ /apt\.postgresql\.org\/pub\/repos\/apt/' "$FILE" >"$TMP"
      if grep -q '[^[:space:]]' "$TMP"; then cat "$TMP" >"$FILE"; else rm -f "$FILE"; fi
      rm -f "$TMP"
      ;;
    *)
      sed -i '\#apt.postgresql.org/pub/repos/apt#d' "$FILE"
      grep -q '[^[:space:]]' "$FILE" 2>/dev/null || rm -f "$FILE"
      ;;
  esac
done < <(grep -RIl --include='*.list' --include='*.sources' 'apt.postgresql.org/pub/repos/apt' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)
if [ "$FOUND" -eq 1 ]; then
  echo "[+] Conflicting/old PGDG source definitions disabled. Backup: $BACKUP"
else
  echo '[+] No PGDG source definitions needed cleanup.'
fi
rm -rf /var/lib/apt/lists/partial 2>/dev/null || true
mkdir -p /var/lib/apt/lists/partial
apt-get update
echo '[+] APT source check passed.'
