# Third-party software used by PG Hosting V9

PG Hosting V9 is an orchestration layer. It downloads/installs upstream components at installation time and does not bundle their full source trees in this ZIP.

- Hestia Control Panel — https://github.com/hestiacp/hestiacp
- pgAdmin 4 — https://github.com/pgadmin-org/pgadmin4
- PostgreSQL — https://www.postgresql.org/
- Docker Engine packages from the operating-system repository

The pgAdmin deployment uses the official `dpage/pgadmin4:9.18` container image. The hosting panel is Hestia, rather than a fork that tries to convert pgAdmin into a web-hosting control panel.
