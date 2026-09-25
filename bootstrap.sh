#!/usr/bin/env bash
set -Eeuo pipefail
REPO="${PGVPS_REPO:-sharifccs/pg-vps-hosting}"
BRANCH="${PGVPS_BRANCH:-main}"
[ "$(id -u)" -eq 0 ] || { echo 'Run as root.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates; }
command -v tar >/dev/null 2>&1 || { apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y tar gzip; }
TMP=$(mktemp -d -t pghosting.XXXXXXXX)
trap 'rm -rf "$TMP"' EXIT
URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"
echo '[+] Downloading PG Hosting installer...'
curl -fL --retry 3 --connect-timeout 20 --max-time 300 "$URL" -o "$TMP/src.tar.gz"
tar -xzf "$TMP/src.tar.gz" -C "$TMP"
DIR=$(find "$TMP" -mindepth 1 -maxdepth 1 -type d -name 'pg-vps-hosting-*' -print -quit)
[ -n "${DIR:-}" ] && [ -f "$DIR/install.sh" ] || { echo '[x] install.sh not found at repository root.' >&2; exit 1; }
cd "$DIR"
exec bash ./install.sh
