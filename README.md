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
- [docs/REBUILD_FROM_SCRATCH.md](docs/REBUILD_FROM_SCRATCH.md)

Suggested reading order:

1. [docs/ORACLE_VM_RUNBOOK.md](docs/ORACLE_VM_RUNBOOK.md)
2. [docs/APP_PLATFORM.md](docs/APP_PLATFORM.md)
3. [docs/SECOND_BRAIN.md](docs/SECOND_BRAIN.md)
4. [docs/REBUILD_FROM_SCRATCH.md](docs/REBUILD_FROM_SCRATCH.md)
5. [docs/01-vm-creation.md](docs/01-vm-creation.md)
6. [docs/02-networking.md](docs/02-networking.md)
7. [docs/03-first-ssh-and-host-setup.md](docs/03-first-ssh-and-host-setup.md)
8. [docs/04-database-and-backups.md](docs/04-database-and-backups.md)
9. [docs/05-app-layout-and-env.md](docs/05-app-layout-and-env.md)
10. [docs/06-github-actions-and-secrets.md](docs/06-github-actions-and-secrets.md)
11. [docs/07-public-routing-and-cloudflare.md](docs/07-public-routing-and-cloudflare.md)
12. [docs/08-verification-and-debugging.md](docs/08-verification-and-debugging.md)

## Recommended layout

Use one Always Free A1 VM and add production/development app slots over time:

```text
/opt/apps/my-app
/opt/apps/my-app-dev
/opt/apps/another-app
/opt/apps/another-app-dev

/etc/apps/my-app/my-app.env
/etc/apps/my-app-dev/my-app.env
/etc/apps/another-app/another-app.env

postgres server
  database: my_app
  database: my_app_dev

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

If you want a tiny public platform health endpoint too:

```bash
sudo INSTALL_PLATFORM_HEALTH=1 \
  PLATFORM_HEALTH_DOMAIN=api.example.com \
  ./bootstrap-host.sh
```

The bootstrap also installs:

- `/usr/local/sbin/oracle-postgres-backup.sh`
- `/usr/local/sbin/oracle-mysql-backup.sh`
- `/usr/local/sbin/deploy-oracle-app`
- `/usr/local/sbin/provision-deploy-user`
- `/usr/local/sbin/snapshot-platform-state`
- `/usr/local/sbin/platform-health`
- `oracle-postgres-backup.service`
- `oracle-postgres-backup.timer`
- `oracle-mysql-backup.service`
- `oracle-mysql-backup.timer`
- `platform-health.service`

The bootstrap also applies:

- SSH hardening in `/etc/ssh/sshd_config.d/99-platform-hardening.conf`
- Docker log rotation in `/etc/docker/daemon.json`
- disabled unused `rpcbind`/NFS client services when present

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
sudo APP_SLUG=my-app \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.my-app.example.com \
  PORT=3610 \
  DB_ENGINE=postgres \
  DB_NAME=my_app \
  DB_USER=my_app_app \
  DB_PASS='choose-a-real-password' \
  ./provision-app.sh
```

Development slot for the same app:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.dev.my-app.example.com \
  PORT=3611 \
  DB_ENGINE=postgres \
  DB_NAME=my_app_dev \
  DB_USER=my_app_dev_app \
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

## Deploy from GitHub Actions

Use the reusable app contract and templates:

- [docs/DEPLOYMENT_CONTRACT.md](docs/DEPLOYMENT_CONTRACT.md)
- [templates/github-actions/deploy-backend-oracle.yml](templates/github-actions/deploy-backend-oracle.yml)
- [templates/oracle/compose.api.yml](templates/oracle/compose.api.yml)
- [templates/oracle/deploy.env.example](templates/oracle/deploy.env.example)

The expected flow is:

1. provision the app once on the server
2. copy `templates/oracle/compose.api.yml` to `/opt/apps/<app-id>/stack/compose.yaml`
3. keep `/opt/apps/<app-id>/stack/.deploy.env` server-local
4. create a per-app deploy SSH key
5. run `sudo APP_ID=<app-id> DEPLOY_PUBLIC_KEY_FILE=<key.pub> provision-deploy-user`
6. copy the GitHub Actions workflow into the app repo
7. push a backend image to GHCR
8. run `/usr/local/sbin/deploy-oracle-app <app-id> <image-ref>` from CI over SSH

For Cloudflare-fronted projects, prefer:

```text
<project>.example.com      -> Cloudflare Pages frontend
api.<project>.example.com  -> Oracle backend through Caddy
dev.<project>.example.com      -> Cloudflare Pages development frontend
api.dev.<project>.example.com  -> Oracle development backend through Caddy
```

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

## Rebuild and safe-keep

Use [docs/REBUILD_FROM_SCRATCH.md](docs/REBUILD_FROM_SCRATCH.md) to recreate the platform on a clean VM.

To capture current non-secret server state:

```bash
sudo snapshot-platform-state > platform-state-$(date -u +%Y%m%dT%H%M%SZ).md
```

Commit useful snapshots only after reviewing that they contain no secrets. The snapshot is meant for layout/config inventory, not data backup.
