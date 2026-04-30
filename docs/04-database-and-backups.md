# 04 - Database and Backups

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Create production and development databases, then set up backups with 60-day retention.

For normal apps, prefer `provision-app.sh` instead of creating databases by hand. It creates the app slot, env file, database user, database, and optional Caddy route together.

## PostgreSQL App Slot

```bash
sudo APP_SLUG=<app-name> \
  ENVIRONMENT=production \
  DB_ENGINE=postgres \
  DB_NAME=<app_db> \
  DB_USER=<app_db_user> \
  DB_PASS='<SET_A_REAL_PASSWORD>' \
  ./provision-app.sh
```

## Verify DBs

```bash
sudo -u postgres psql -lqt
```

## MySQL/MariaDB App Slot

Only use this when an app actually needs MySQL compatibility:

```bash
sudo INSTALL_MYSQL=1 ./bootstrap-host.sh

sudo APP_SLUG=<app-name> \
  ENVIRONMENT=production \
  DB_ENGINE=mysql \
  DB_NAME=<app_db> \
  DB_USER=<app_db_user> \
  DB_PASS='<SET_A_REAL_PASSWORD>' \
  ./provision-app.sh
```

## Backup Policy

Use:

- nightly dump
- compressed output
- local retention: `60 days`

PostgreSQL backups:

```text
/var/backups/apps/postgres/<timestamp>/
```

MySQL/MariaDB backups:

```text
/var/backups/apps/mysql/<timestamp>/
```

## Operational rule

A backup system is not really trusted until you have successfully restored from it at least once.
