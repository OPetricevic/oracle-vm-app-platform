# Oracle Host

Reusable Oracle VM host setup for multiple unrelated production and development apps.

This repository owns the platform layer:

- Ubuntu package installation and updates
- Docker and Docker Compose
- Caddy public routing with one snippet per app
- UFW and fail2ban baseline
- PostgreSQL, plus optional MySQL/MariaDB
- PostgreSQL and MySQL/MariaDB backup automation
- shared directory conventions
- per-app production/development app slots
- per-app environment files

Application repositories own their own code, images, migrations, release packaging, and app-specific deployment scripts.

## Runbook and setup guides

The full host and OCI setup guides live in:

- [docs/ORACLE_VM_RUNBOOK.md](docs/ORACLE_VM_RUNBOOK.md)
- [docs/ZERO_TO_PRODUCTION.md](docs/ZERO_TO_PRODUCTION.md)

Suggested reading order:

1. [docs/ORACLE_VM_RUNBOOK.md](docs/ORACLE_VM_RUNBOOK.md)
2. [docs/APP_PLATFORM.md](docs/APP_PLATFORM.md)
3. [docs/01-vm-creation.md](docs/01-vm-creation.md)
4. [docs/02-networking.md](docs/02-networking.md)
5. [docs/03-first-ssh-and-host-setup.md](docs/03-first-ssh-and-host-setup.md)
6. [docs/04-database-and-backups.md](docs/04-database-and-backups.md)
7. [docs/05-app-layout-and-env.md](docs/05-app-layout-and-env.md)
8. [docs/06-github-actions-and-secrets.md](docs/06-github-actions-and-secrets.md)
9. [docs/07-public-routing-and-cloudflare.md](docs/07-public-routing-and-cloudflare.md)
10. [docs/08-verification-and-debugging.md](docs/08-verification-and-debugging.md)

## Recommended layout

Use one Always Free A1 VM and add production/development app slots over time:

```text
/opt/apps/physio-tracker
/opt/apps/physio-tracker-dev
/opt/apps/konektorhub
/opt/apps/konektorhub-dev
/opt/apps/third-app

/etc/apps/physio-tracker/physio-tracker.env
/etc/apps/physio-tracker-dev/physio-tracker.env
/etc/apps/konektorhub/konektorhub.env

postgres server
  database: physio
  database: physio_tracker_dev

optional mysql/mariadb server
  database: wordpress_site
```

## Disk strategy

Start with:

- one A1 VM
- 50 GB boot volume
- no extra attached block volumes initially

The main storage risks are old releases, local backups, logs, and uploaded files, not the app binaries themselves.

## One-time host setup

Run on the Oracle VM:

```bash
sudo ./bootstrap-host.sh
```

If you need MySQL/MariaDB too:

```bash
sudo INSTALL_MYSQL=1 ./bootstrap-host.sh
```

The bootstrap also installs:

- `/usr/local/sbin/oracle-postgres-backup.sh`
- `/usr/local/sbin/oracle-mysql-backup.sh`
- `oracle-postgres-backup.service`
- `oracle-postgres-backup.timer`
- `oracle-mysql-backup.service`
- `oracle-mysql-backup.timer`

The timer runs every night at `02:15 UTC`, writes PostgreSQL backups to:

```text
/var/backups/apps/postgres/<timestamp>/
```

and removes backup directories older than `60` days.

If MySQL/MariaDB is installed, its timer runs every night at `02:35 UTC` and writes to:

```text
/var/backups/apps/mysql/<timestamp>/
```

## Add a new app

Production API with PostgreSQL:

```bash
sudo APP_SLUG=physio-tracker \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.example.com \
  PORT=3600 \
  DB_ENGINE=postgres \
  DB_NAME=physio \
  DB_USER=physio_app \
  DB_PASS='choose-a-real-password' \
  ./provision-app.sh
```

Development slot for the same app:

```bash
sudo APP_SLUG=physio-tracker \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api-dev.example.com \
  PORT=3601 \
  DB_ENGINE=postgres \
  DB_NAME=physio_dev \
  DB_USER=physio_dev_app \
  DB_PASS='choose-a-real-password' \
  ./provision-app.sh
```

Static origin on the VM, if Cloudflare Pages/Workers is not the right fit:

```bash
sudo APP_SLUG=docs-site \
  ENVIRONMENT=production \
  APP_TYPE=static \
  PUBLIC_DOMAIN=docs.example.com \
  DB_ENGINE=none \
  ./provision-app.sh
```

MySQL/MariaDB app:

```bash
sudo APP_SLUG=legacy-cms \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=cms.example.com \
  PORT=3700 \
  DB_ENGINE=mysql \
  DB_NAME=legacy_cms \
  DB_USER=legacy_cms_app \
  DB_PASS='choose-a-real-password' \
  ./provision-app.sh
```

After provisioning, each app repo deploys into its own directory under `/opt/apps/<app-id>`.

Production uses `/opt/apps/<app-slug>`.
Development uses `/opt/apps/<app-slug>-dev`.

## Backup notes

Each backup run includes:

- one compressed globals export: `globals.sql.gz`
- one custom-format dump per non-template PostgreSQL database
- a `databases.txt` inventory
- `SHA256SUMS` for quick integrity checks

Useful commands:

```bash
sudo systemctl list-timers oracle-postgres-backup.timer
sudo systemctl start oracle-postgres-backup.service
sudo journalctl -u oracle-postgres-backup.service --no-pager
ls -la /var/backups/apps/postgres
```

For MySQL/MariaDB:

```bash
sudo systemctl list-timers oracle-mysql-backup.timer
sudo systemctl start oracle-mysql-backup.service
sudo journalctl -u oracle-mysql-backup.service --no-pager
ls -la /var/backups/apps/mysql
```
