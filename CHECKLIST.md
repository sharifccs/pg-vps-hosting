# V10 implementation checklist

- [x] Full web-hosting control panel on TCP 2083
- [x] Official Hestia installer from upstream GitHub release branch
- [x] Multiple domains / virtual hosts
- [x] Web File Manager / source upload via Hestia
- [x] FTP/SFTP
- [x] Cron management
- [x] BIND DNS zones
- [x] NS1/NS2 configurator
- [x] Cloudflare-compatible A-record workflow
- [x] Let's Encrypt website SSL through Hestia
- [x] PHP 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4 requested through Hestia MultiPHP
- [x] Per-domain PHP selection via Hestia backend templates
- [x] PostgreSQL 18 PGDG repository enabled before Hestia install
- [x] PostgreSQL and MariaDB databases/users/passwords in hosting panel
- [x] SSH database manager for create/password/import/export/delete synchronized through Hestia CLI
- [x] Advanced PostgreSQL role/privilege CLI manager
- [x] Official pgAdmin 4 9.18 on TCP 2084
- [x] pgAdmin internal login; no webserver/REMOTE_USER auto-login
- [x] Database-only backup twice daily (PostgreSQL + MariaDB/MySQL when installed) (03:15 / 15:15)
- [x] 14-day database backup retention
- [x] Database restore with checksum verification
- [x] Hestia default automatic full-user backup cron removed; manual Hestia backup remains available
- [x] Hestia firewall / Fail2ban
- [x] MikroTik/OLT firewall profile
- [x] VPN/Xray/Proxy firewall profile
- [x] `pg-hosting` SSH control center
- [x] VPS public-IP check every 30 minutes + Hestia IP sync + pgAdmin IP-certificate refresh
- [x] Addon uninstall
- [x] Destructive full purge with exact confirmation phrase

## Deliberate architecture choice

pgAdmin is not forked into a web-hosting panel. The official pgAdmin application remains the advanced PostgreSQL UI. Hestia supplies the hosting-control-plane functions that pgAdmin does not natively provide.

## V10 PGDG/APT conflict prevention
- Pre-existing `apt.postgresql.org` source stanzas are backed up and disabled before the first APT update.
- The PG Hosting wrapper no longer creates its own PGDG source before Hestia.
- Hestia is the single owner of the PostgreSQL repository definition during installation.
- `repair-pgdg-apt.sh` is included for servers already stuck on a Signed-By conflict.
