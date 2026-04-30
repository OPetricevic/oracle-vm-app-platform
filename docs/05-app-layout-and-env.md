# 05 - App Layout and Environment

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Create production and development app slots with the exact path pattern used by deployment scripts.

Prefer the provisioning script:

```bash
sudo APP_SLUG=<app-name> \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.example.com \
  PORT=3600 \
  DB_ENGINE=postgres \
  DB_PASS='<SET_A_REAL_PASSWORD>' \
  ./provision-app.sh
```

Development:

```bash
sudo APP_SLUG=<app-name> \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api-dev.example.com \
  PORT=3601 \
  DB_ENGINE=postgres \
  DB_PASS='<SET_A_REAL_PASSWORD>' \
  ./provision-app.sh
```

## Production layout

Create:

```bash
sudo mkdir -p /opt/apps/<app-name>/shared/uploads
sudo mkdir -p /opt/apps/<app-name>/shared/data
sudo mkdir -p /opt/apps/<app-name>/shared/log
sudo mkdir -p /opt/apps/<app-name>/shared/static
sudo mkdir -p /opt/apps/<app-name>/stack
sudo mkdir -p /etc/apps/<app-name>
```

Production env file:

- `/etc/apps/<app-name>/<app-name>.env`

## Development layout

Create:

```bash
sudo mkdir -p /opt/apps/<app-name>-dev/shared/uploads
sudo mkdir -p /opt/apps/<app-name>-dev/shared/data
sudo mkdir -p /opt/apps/<app-name>-dev/shared/log
sudo mkdir -p /opt/apps/<app-name>-dev/shared/static
sudo mkdir -p /opt/apps/<app-name>-dev/stack
sudo mkdir -p /etc/apps/<app-name>-dev
```

Development env file:

- `/etc/apps/<app-name>-dev/<app-name>.env`

## Environment file content

The exact app-specific values depend on the application, but the deployment path expects the env files to exist before deploy runs.

At minimum, ensure the backend has what it needs for:

- database connection
- app runtime port
- upload location if applicable
- secrets
- allowed origins if applicable

Common generated values:

```text
APP_ENV=production
PORT=3600
UPLOADS_DIR=/opt/apps/<app-name>/shared/uploads
DATA_DIR=/opt/apps/<app-name>/shared/data
LOG_DIR=/opt/apps/<app-name>/shared/log
DATABASE_URL=postgres://...
```

## Important runtime model

This deployment now uses host networking for app containers.

That means:

- production runtime port: `3600`
- development runtime port: `3601`
- host PostgreSQL remains reachable via `localhost:5432`

Do not expect ordinary Docker bridge publish semantics here. The compose/deploy path was adjusted specifically for this host-managed PostgreSQL pattern.
