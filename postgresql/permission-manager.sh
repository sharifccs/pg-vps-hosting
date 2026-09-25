#!/usr/bin/env bash
set -Eeuo pipefail
valid_ident(){ [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]]; }
qident(){ printf '"%s"' "$1"; }
list_all(){
  echo '--- PostgreSQL databases ---'
  sudo -u postgres psql -X -P pager=off -c "SELECT datname AS database, pg_get_userbyid(datdba) AS owner FROM pg_database WHERE datistemplate=false ORDER BY 1;"
  echo
  echo '--- Login roles ---'
  sudo -u postgres psql -X -P pager=off -c "SELECT rolname AS role, rolsuper AS superuser, rolcreatedb AS createdb, rolcreaterole AS createrole FROM pg_roles WHERE rolcanlogin ORDER BY 1;"
}
create_user(){
  local u p
  read -rp 'Database username: ' u
  valid_ident "$u" || { echo '[x] Invalid PostgreSQL role name.' >&2; return 1; }
  read -rsp 'Password: ' p; echo
  sudo -u postgres psql -X -v ON_ERROR_STOP=1 -v pw="$p" -c "CREATE ROLE \"$u\" LOGIN PASSWORD :'pw';"
}
change_password(){
  local u p
  read -rp 'Database username: ' u
  valid_ident "$u" || return 1
  read -rsp 'New password: ' p; echo
  sudo -u postgres psql -X -v ON_ERROR_STOP=1 -v pw="$p" -c "ALTER ROLE \"$u\" PASSWORD :'pw';"
}
grant_access(){
  local db u mode owner
  read -rp 'Database: ' db
  read -rp 'Database username: ' u
  valid_ident "$db" && valid_ident "$u" || { echo '[x] Invalid name.' >&2; return 1; }
  owner=$(sudo -u postgres psql -XAtqc "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname='$db'" postgres 2>/dev/null || true)
  [ -n "$owner" ] || { echo '[x] Database not found.' >&2; return 1; }
  valid_ident "$owner" || { echo '[x] Could not safely determine database owner.' >&2; return 1; }
  echo 'Permission: 1=Read only, 2=Read/Write, 3=Owner'
  read -rp 'Select: ' mode
  case "$mode" in
    1)
      sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d "$db" <<SQL
GRANT CONNECT ON DATABASE "$db" TO "$u";
GRANT USAGE ON SCHEMA public TO "$u";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "$u";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "$u";
ALTER DEFAULT PRIVILEGES FOR ROLE "$owner" IN SCHEMA public GRANT SELECT ON TABLES TO "$u";
ALTER DEFAULT PRIVILEGES FOR ROLE "$owner" IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO "$u";
SQL
      ;;
    2)
      sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d "$db" <<SQL
GRANT CONNECT ON DATABASE "$db" TO "$u";
GRANT USAGE, CREATE ON SCHEMA public TO "$u";
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO "$u";
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO "$u";
ALTER DEFAULT PRIVILEGES FOR ROLE "$owner" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO "$u";
ALTER DEFAULT PRIVILEGES FOR ROLE "$owner" IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO "$u";
SQL
      ;;
    3)
      sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "ALTER DATABASE \"$db\" OWNER TO \"$u\";"
      sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d "$db" -c "ALTER SCHEMA public OWNER TO \"$u\";"
      ;;
    *) echo '[x] Invalid selection.'; return 1;;
  esac
  echo '[+] Permission updated.'
}
revoke_access(){
  local db u
  read -rp 'Database: ' db
  read -rp 'Database username: ' u
  valid_ident "$db" && valid_ident "$u" || return 1
  sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d "$db" <<SQL
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM "$u";
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM "$u";
REVOKE ALL ON SCHEMA public FROM "$u";
REVOKE CONNECT ON DATABASE "$db" FROM "$u";
SQL
  echo '[+] Access revoked.'
}
while true; do
cat <<'MENU'

PostgreSQL Role / Permission Manager
1) List databases and users
2) Create database user
3) Change user password
4) Grant database permission
5) Revoke database access
0) Exit
MENU
read -rp 'Select > ' N
case "$N" in
  1) list_all;;
  2) create_user;;
  3) change_password;;
  4) grant_access;;
  5) revoke_access;;
  0) exit 0;;
  *) echo 'Invalid choice.';;
esac
done
