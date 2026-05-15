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
- one production/development slot per app

Each app owns:

- source code
- Dockerfile
- app compose file
- migrations
- deployment workflow
- app-specific secrets and env values

## Deployment Contract

For new backend repositories, use:

- [DEPLOYMENT_CONTRACT.md](DEPLOYMENT_CONTRACT.md)
- [../templates/github-actions/deploy-backend-oracle.yml](../templates/github-actions/deploy-backend-oracle.yml)
- [../templates/oracle/compose.api.yml](../templates/oracle/compose.api.yml)

The preferred model is frontend on Cloudflare Pages and backend on this host through an API subdomain.

Example:

```text
my-app.example.com      -> Cloudflare Pages
api.my-app.example.com  -> Caddy on this host -> 127.0.0.1:<app-port>
dev.my-app.example.com      -> Cloudflare Pages
api.dev.my-app.example.com  -> Caddy on this host -> 127.0.0.1:<dev-app-port>
```

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
api.my-app.example.com -> 127.0.0.1:3610
api.dev.my-app.example.com -> 127.0.0.1:3611
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
  PUBLIC_DOMAIN=api.my-app.example.com \
  PORT=3610 \
  DB_ENGINE=postgres \
  DB_NAME=my_app \
  DB_PASS='choose-a-real-url-safe-password' \
  ./provision-app.sh
```

Development API with PostgreSQL:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.dev.my-app.example.com \
  PORT=3611 \
  DB_ENGINE=postgres \
  DB_NAME=my_app_dev \
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
