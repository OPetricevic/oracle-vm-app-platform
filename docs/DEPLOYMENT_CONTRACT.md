# Deployment Contract

This contract defines how an application repository deploys a backend API to the Oracle host.

The safe default architecture is:

- frontend on Cloudflare Pages
- backend API on the Oracle host
- database on the Oracle host, bound to localhost
- public API exposed by Caddy through an API subdomain
- app secrets stored on the server in `/etc/apps/<app-id>/<app-slug>.env`
- GitHub Actions builds and deploys code, but does not own database passwords

## Naming

Use one app slug per project:

```text
my-app
```

Production slot:

```text
APP_ID=my-app
APP_DIR=/opt/apps/my-app
ENV_FILE=/etc/apps/my-app/my-app.env
FRONTEND_DOMAIN=my-app.example.com
API_DOMAIN=api.my-app.example.com
PORT=3610
DB_NAME=my_app
```

Development slot:

```text
APP_ID=my-app-dev
APP_DIR=/opt/apps/my-app-dev
ENV_FILE=/etc/apps/my-app-dev/my-app.env
FRONTEND_DOMAIN=dev.my-app.example.com
API_DOMAIN=api.dev.my-app.example.com
PORT=3611
DB_NAME=my_app_dev
```

## Repository Requirements

Each backend repository should contain:

```text
Dockerfile
.github/workflows/deploy-backend-oracle.yml
```

The container must:

- listen on the `PORT` environment variable
- expose a health endpoint at `/api/health`
- read database and app secrets from environment variables
- write uploaded files only to the mounted uploads directory

Recommended environment variables:

```text
PORT
DATABASE_URL
UPLOADS_DIR
DATA_DIR
LOG_DIR
CORS_ALLOWED_ORIGINS
APP_ENV
```

## GitHub Environment Variables

Use GitHub Environments named `dev` and `production`.

Required variables:

```text
ORACLE_HOST=<public-ip-or-hostname>
ORACLE_USER=deploy-my-app
ORACLE_APP_ID=my-app
ORACLE_API_DOMAIN=api.my-app.example.com
ORACLE_PORT=3610
GHCR_IMAGE=ghcr.io/<owner>/<repo>/backend
```

Required secrets:

```text
ORACLE_SSH_KEY=<private deploy key>
GHCR_TOKEN=<token with package read access, if the repo/package is private>
```

For public GHCR images, `GHCR_TOKEN` can be omitted if the server can pull anonymously.

Do not put database passwords in GitHub unless the workflow truly needs them. Prefer server-local env files under `/etc/apps`.

## Server Requirements

Provision the app once:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.my-app.example.com \
  PORT=3610 \
  DB_ENGINE=postgres \
  DB_PASS='choose-a-real-url-safe-password' \
  ./provision-app.sh
```

Provision the development slot separately:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.dev.my-app.example.com \
  PORT=3611 \
  DB_ENGINE=postgres \
  DB_NAME=my_app_dev \
  DB_PASS='choose-a-different-url-safe-password' \
  ./provision-app.sh
```

The provisioning step creates:

- app directory under `/opt/apps`
- server env file under `/etc/apps`
- database and database role
- Caddy route snippet
- persistent upload/data/log directories

Production and development should use separate app directories, env files, ports, and databases.

Then create a narrow deploy user for that app:

```bash
sudo APP_ID=my-app \
  DEPLOY_PUBLIC_KEY_FILE=/tmp/my-app-deploy.pub \
  provision-deploy-user
```

That user receives sudo permission only for:

```text
/usr/local/sbin/deploy-oracle-app my-app *
```

## Deploy Behavior

Deploys should:

1. build a backend container image
2. push it to GHCR
3. SSH to the Oracle host
4. update `/opt/apps/<app-id>/stack/.deploy.env`
5. run Docker Compose from `/opt/apps/<app-id>/stack`
6. verify `/api/health`

The deploy should restart only the target app, not the whole server.

## Safety Rules

- Keep Caddy as the only public HTTP/HTTPS entrypoint.
- Keep databases bound to `127.0.0.1`.
- Keep app ports blocked by UFW.
- Use one app slot per app/environment.
- Store secrets on the server or in GitHub environment secrets, never in Git.
- Prefer per-app deploy users over the general `ubuntu` SSH user for CI.
- Test backup restore before treating a project as production-quality.
