#!/usr/bin/env bash
set -Eeuo pipefail

log(){ printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
need_root(){ [ "$(id -u)" -eq 0 ] || die 'Run as root.'; }

os_detect(){
  [ -r /etc/os-release ] || die 'Cannot detect operating system.'
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_VER="${VERSION_ID:-}"
  OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  case "$OS_ID:$OS_VER" in
    debian:12|debian:13|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04) ;;
    *) die "Full Hosting V9 follows Hestia's supported platforms: Debian 12/13 or Ubuntu 22.04/24.04/26.04. Found: $OS_ID $OS_VER" ;;
  esac
}

primary_ipv4(){
  local ip
  ip=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)
  if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}' || true)
  fi
  if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    ip=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i ~ /^[0-9]+\./){print $i;exit}}' || true)
  fi
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  printf '%s\n' "$ip"
}

valid_domain(){
  [[ "${1:-}" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

hestia_bin(){ printf '/usr/local/hestia/bin/%s\n' "$1"; }
hestia_ready(){ [ -x /usr/local/hestia/bin/v-list-sys-info ]; }

wait_http(){
  local url="$1" seconds="${2:-120}" insecure="${3:-yes}" i code
  for ((i=0;i<seconds;i+=3)); do
    if [ "$insecure" = yes ]; then
      code=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || true)
    else
      code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || true)
    fi
    case "$code" in 2*|3*|401|403) return 0;; esac
    printf '\r[~] Waiting for %s ... %3ss/%ss (HTTP %s)' "$url" "$i" "$seconds" "${code:-000}"
    sleep 3
  done
  printf '\n'
  return 1
}
