# App Platform Model

This host is meant to be a small reusable production platform, not a single-app server.

## Responsibilities

The host owns:

- Docker and Docker Compose
- Caddy routing
- PostgreSQL
- optional MySQL/MariaDB
- backups
- firewall baseline
- `/opt/apps`, `/etc/apps`, and `/var/backups/apps`
- one production/development/staging slot per app

Each app owns:

- source code
- Dockerfile
- app compose file
- migrations
- deployment workflow
- app-specific secrets and env values

## Standard App Slots

Production:

```text
/opt/apps/<app-slug>
/etc/apps/<app-slug>/<app-slug>.env
```

Development:

```text
/opt/apps/<app-slug>-dev
/etc/apps/<app-slug>-dev/<app-slug>.env
```

Staging, for GitHub Actions workflows that use that word:

```text
/opt/apps/<app-slug>-staging
/etc/apps/<app-slug>-staging/<app-slug>.env
```

Inside each app directory:

```text
releases/
stack/
shared/
  data/
  log/
  static/
  uploads/
```

## Routing

Caddy imports app snippets from:

```text
/etc/caddy/apps/*.caddy
```

API apps usually route to a local port:

```text
api.example.com -> 127.0.0.1:3600
api-dev.example.com -> 127.0.0.1:3601
```

Static apps can be served from:

```text
/opt/apps/<app-slug>/shared/static
```

For most frontend apps, prefer Cloudflare Pages or Worker assets for static files and use the VM for API, database, uploaded files, and background jobs.

## Provision Examples

Production API with PostgreSQL:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.example.com \
  PORT=3600 \
  DB_ENGINE=postgres \
  DB_PASS='choose-a-real-url-safe-password' \
  ./provision-app.sh
```

Development API with PostgreSQL:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api-dev.example.com \
  PORT=3601 \
  DB_ENGINE=postgres \
  DB_PASS='choose-a-real-url-safe-password' \
  ./provision-app.sh
```

Static origin:

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
sudo INSTALL_MYSQL=1 ./bootstrap-host.sh

sudo APP_SLUG=legacy-cms \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=cms.example.com \
  PORT=3700 \
  DB_ENGINE=mysql \
  DB_PASS='choose-a-real-url-safe-password' \
  ./provision-app.sh
```

## Production Checklist

- Oracle security list allows 22, 80, and 443 only.
- UFW allows OpenSSH, 80, and 443 only.
- Caddy has a valid public domain for each app.
- Production and development use separate app dirs, env files, databases, and ports.
- Backups are enabled and at least one restore has been tested.
- Admin tools are private behind Tailscale/SSH or protected by strong auth.
- App deploys are repeatable from CI artifacts, not manual server builds.
