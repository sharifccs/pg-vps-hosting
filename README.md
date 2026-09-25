# PG Hosting V10 — Full Web Hosting Control Panel + PostgreSQL 18 + pgAdmin 4

> **V10 APT/PGDG fix:** before the first `apt-get update`, the installer backs up and disables any pre-existing `apt.postgresql.org` source stanzas. Hestia then creates its own single canonical PostgreSQL repository definition. This prevents Debian/Ubuntu APT from failing with `Conflicting values set for option Signed-By`.


This release changes the architecture from a **pgAdmin-only database panel** into a real **cPanel-style web hosting stack**.

> pgAdmin is kept as the official PostgreSQL administration application. It is **not modified into a hosting panel**. The full hosting functions are provided by **Hestia Control Panel**, while pgAdmin is installed beside it as the advanced PostgreSQL module. This is much more reliable than patching pgAdmin authentication/UI for tasks it was not designed to do.

## What you get

### Full hosting control panel — port 2083

- Multiple web domains
- Upload/extract website source with web File Manager
- Per-domain PHP version selection
- PHP 7.3, 7.4, 8.0, 8.1, 8.2, 8.3 and 8.4
- Nginx + Apache + PHP-FPM
- Let's Encrypt SSL
- BIND authoritative DNS zones
- Two default nameservers (NS1 / NS2)
- DNS records: A, AAAA, CNAME, MX, TXT, NS, SRV and more
- Cron job management
- FTP/SFTP support
- Mail services (Exim + Dovecot; anti-virus/SpamAssassin are disabled by this preset to reduce memory use)
- Web terminal
- Firewall + Fail2ban
- PostgreSQL **and MariaDB** databases
- Database users and passwords
- File manager
- Logs and service controls

### PostgreSQL 18

The installer enables the official PostgreSQL PGDG APT repository **before** Hestia installation, so PostgreSQL 18 is the target database engine.

### Official pgAdmin 4 — port 2084

pgAdmin runs from the official image:

```text
dpage/pgadmin4:9.18
```

Login is **internal pgAdmin authentication**. There is no webserver auto-login/REMOTE_USER authentication in V10.

```text
URL      : https://SERVER_IP:2084
Email    : sharifulislamccs@gmail.com
Password : admin
```

The main hosting panel login is:

```text
URL      : https://SERVER_IP:2083
Username : admin
Password : admin
```

> `admin` is intentionally kept because it was requested. Change both passwords before exposing a production server to the public Internet.

---

## Supported operating systems

The full hosting build follows the current Hestia-supported platforms:

- Debian 12
- Debian 13
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Ubuntu 26.04 LTS

Debian 11 and Debian 14 are **not enabled in this full-panel installer**, because the upstream hosting panel does not currently list them as supported full-stack targets. The older PG-only installer had broader OS detection, but that is not the same as a supported cPanel-style hosting stack.

---

# One-command install

Upload this project to:

```text
https://github.com/sharifccs/pg-vps-hosting
```

Then on a clean VPS:

```bash
cd /root
curl -fsSL https://raw.githubusercontent.com/sharifccs/pg-vps-hosting/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
bash bootstrap.sh
```

The installer is automatic. It uses:

```text
Hosting panel port : 2083
Hosting user       : admin
Hosting password   : admin
pgAdmin port       : 2084
pgAdmin email      : sharifulislamccs@gmail.com
pgAdmin password   : admin
PostgreSQL         : 18
Database backup    : 03:15 and 15:15 daily
Retention          : 14 days
```

The installer generates a temporary FQDN based on the VPS IP for Hestia bootstrap. You can later change the hostname to your real hosting hostname from Hestia or with its CLI.

---

# SSH management

After installation run:

```bash
pg-hosting
```

The menu shows:

```text
PG HOSTING CONTROL CENTER V10

Current VPS IP
Hosting panel URL/status
PostgreSQL 18 status
pgAdmin URL/status
Installed PHP versions
Web domain count
PostgreSQL database count
Cron job count
Database backup schedule
Nameserver status
```

Direct commands:

```bash
pg-hosting status
pg-hosting nameservers
pg-hosting database
pg-hosting db-permissions
pg-hosting firewall
pg-hosting backup
pg-hosting restore
pg-hosting pgadmin-logs
pg-hosting ip-sync
pg-hosting update
pg-hosting uninstall
```

---

# Multiple domains

Login to:

```text
https://SERVER_IP:2083
```

Open **Web → Add Web Domain**.

For each website Hestia creates an isolated hosting structure under the hosting user. You can upload your design/source from **File Manager**, extract ZIP archives, edit files and make the domain live.

Typical flow:

```text
Add Web Domain
      ↓
Select PHP version
      ↓
Upload website source
      ↓
Point DNS / nameservers
      ↓
Enable Let's Encrypt SSL
      ↓
Website LIVE
```

---

# PHP 7.3 → 8.4

The installer requests these MultiPHP versions:

```text
7.3
7.4
8.0
8.1
8.2
8.3
8.4
```

To select PHP for a domain:

```text
Web
→ Edit Domain
→ Backend Template
→ PHP-7_3 / PHP-7_4 / PHP-8_0 / ... / PHP-8_4
```

The requested default PHP is 8.4.

You can check the installed services from SSH:

```bash
for v in 7.3 7.4 8.0 8.1 8.2 8.3 8.4; do
  systemctl status php$v-fpm --no-pager
 done
```

PHP 7.3/7.4 are legacy/EOL branches. They are provided for application compatibility and should only be used where an older application requires them.

---

# VPS IP changes

V10 checks the public IPv4 every 30 minutes. If it changes, the local pgAdmin IP certificate and stored panel IP are refreshed and Hestia's IP inventory is updated.

External DNS is outside the VPS, so when the public IP changes you must also update registrar glue records / Cloudflare A records unless you configure an external DDNS/API workflow.

Manual refresh:

```bash
pg-hosting ip-sync
```

---

# Own nameservers — NS1 / NS2

Run:

```bash
pg-hosting nameservers
```

Example:

```text
NS1: ns1.example.com
NS2: ns2.example.com
```

The command configures the default Hestia nameservers and displays the current VPS IP.

At your domain registrar create **glue/host records**:

```text
ns1.example.com → SERVER_IP
ns2.example.com → SERVER_IP
```

Then set the hosted domain's nameservers to:

```text
ns1.example.com
ns2.example.com
```

Hestia/BIND will serve the DNS zones.

> Two nameserver names on one VPS are functional but do not provide real redundancy. For production DNS resilience, put NS2 on a second independent DNS server/IP and use DNS clustering.

---

# Cloudflare domains

You do not have to use your own nameservers.

You can add the domain to Cloudflare and create:

```text
A   @     → SERVER_IP
A   www   → SERVER_IP
```

For the first Let's Encrypt issuance, **DNS Only** is the simplest setup. After the website/SSL is working you can enable Cloudflare **Proxied** if desired.

The website itself is still created and managed in the hosting panel on port 2083.

---

# PostgreSQL database management

## Basic cPanel-style database management

Use the main panel:

```text
DB
→ Add Database
```

You can create PostgreSQL databases, database usernames and passwords from the hosting panel.

## Advanced roles and permissions

Use official pgAdmin:

```text
https://SERVER_IP:2084
```

or use the SSH permission manager:

```bash
pg-hosting database
pg-hosting db-permissions
```

For cPanel-style database create/password/import/export/delete from SSH, run:

```bash
pg-hosting database
```

For granular PostgreSQL roles/privileges, `pg-hosting db-permissions` supports:

- list databases/users
- create PostgreSQL login user
- change user password
- read-only database access
- read/write database access
- database owner permission
- revoke access

pgAdmin provides the complete PostgreSQL role/schema/table privilege interface for advanced control.

---

# Database import / export

Use pgAdmin for PostgreSQL import/export/backup/restore operations, or the hosting database tools.

The official pgAdmin container includes PostgreSQL client utilities such as `pg_dump`, `pg_dumpall`, `pg_restore` and `psql`.

For automatic server backup this project uses a separate logical database-only backup job.

---

# Automatic database backup

Automatic backup is **database-only**: PostgreSQL is backed up, and MariaDB/MySQL is also backed up when installed. Website files, mail and full-account data are not included in this automatic schedule. The installer removes Hestia's default scheduled `v-backup-users` job so website/mail/file archives are not created automatically. Manual Hestia backups remain available from the control panel.

Schedule:

```text
03:15 every day
15:15 every day
```

Retention:

```text
14 days
```

Manual backup:

```bash
pg-hosting backup
```

Restore:

```bash
pg-hosting restore
```

Backup path:

```text
/var/backups/pg-hosting-database
```

---

# Cron jobs

Cron jobs are managed directly from the hosting web panel.

Typical examples:

```text
*/5 * * * *
0 * * * *
0 3 * * *
```

Each hosting user/domain can manage scheduled application commands from the **Cron** section.

---

# Website source / File Manager

The main panel provides the server-side File Manager.

You can:

- upload source files
- upload ZIP archives
- extract archives
- create/rename/delete files and folders
- edit text/code files
- change permissions
- download files
- manage each hosted domain's `public_html`

FTP/SFTP support is also installed.

---

# MikroTik / OLT / VPN port profiles

Run:

```bash
pg-hosting firewall
```

MikroTik / OLT profile:

```text
TCP/UDP 1001-1020
TCP/UDP 7001-7020
```

VPN / Xray / Proxy TCP profile:

```text
22, 80, 443, 441, 445, 446, 992, 1080, 1194, 1701,
1723, 2222, 3128, 5555, 8000-8002, 8080, 8388, 8443
```

UDP profile:

```text
53, 443, 500, 1194, 1701, 3478, 4500, 51820, 5666,
8388, 9993, 41641, 20000-50000
```

The large UDP range requires explicit confirmation.

The rules are added through Hestia's firewall CLI so they survive Hestia firewall rebuilds.

---

# VPS IP change

Run:

```bash
pg-hosting ip-sync
```

This calls Hestia's system IP update/rebuild routine.

Important:

- Hestia can rebuild local hosting configuration for the new IP.
- Registrar glue records must still be changed at the registrar if NS IP changes.
- Cloudflare A records must be changed at Cloudflare unless you separately configure an API/DDNS updater.

---

# SSL

For hosted websites, Hestia provides Let's Encrypt from the web interface.

For the Hestia control panel itself, you can later change the temporary hostname to your own FQDN and issue/update the host certificate.

pgAdmin on `2084` initially uses a local self-signed IP certificate. A browser certificate warning on the raw IP is expected. This is different from a 502/backend error.

---

# Important architecture

```text
                         Internet
                            │
          ┌─────────────────┴──────────────────┐
          │                                    │
    Own NS1 / NS2                         Cloudflare DNS
       BIND DNS                           A / CNAME Proxy
          │                                    │
          └─────────────────┬──────────────────┘
                            │
                    Linux Hosting VPS
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
 Hestia Panel :2083     Websites 80/443     pgAdmin :2084
        │                   │                   │
 Multi-domain           Nginx/Apache        PostgreSQL UI
 File Manager           PHP-FPM 7.3-8.4        │
 Cron / FTP             Let's Encrypt           │
 DNS / Mail                                     │
        └───────────────────┬───────────────────┘
                            │
                       PostgreSQL 18
```

This means the system no longer tries to force pgAdmin to act like cPanel. The hosting panel handles hosting, while official pgAdmin handles PostgreSQL administration.

---

# Uninstall

Run:

```bash
pg-hosting uninstall
```

Options:

```text
1) Remove only PG Hosting addon + pgAdmin
   KEEP Hestia websites, DNS, mail and PostgreSQL data

2) FULL PURGE hosting stack/data
```

FULL PURGE requires typing:

```text
PURGE ALL HOSTING DATA
```

Always keep an off-server backup before a destructive purge.

---

# Upstream projects

This installer orchestrates upstream open-source software instead of copying their code into this small repository:

- Hestia Control Panel: `https://github.com/hestiacp/hestiacp`
- pgAdmin 4: `https://github.com/pgadmin-org/pgadmin4`
- PostgreSQL: `https://www.postgresql.org/`

Read and comply with each upstream project's license and update policy when redistributing or modifying their software.
