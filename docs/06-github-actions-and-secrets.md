# 06 - GitHub Actions and Secrets

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Set up GitHub so the repo can deploy to Oracle over SSH.

## Environments

In GitHub:

1. open the repository
2. `Settings`
3. `Environments`
4. create:
   - `staging`
   - `production`

## Secrets to add to both environments

- `ORACLE_HOST`
- `ORACLE_USER`
- `ORACLE_SSH_KEY`

Example values:

- `ORACLE_HOST=<public-ip>`
- `ORACLE_USER=ubuntu`

Important:

- use the private key file, not the `.pub` key
- paste the whole private key into the GitHub environment secret
- never commit the key into this repository

## Production variables

Add:

```text
ORACLE_APP_DIR=/opt/apps/<app-name>
ORACLE_ENV_FILE=/etc/apps/<app-name>/<app-name>.env
ORACLE_STACK_NAME=<app-name>
ORACLE_CONTAINER_NAME=<app-name>-api
ORACLE_HOST_PORT=3600
```

## Staging variables

Add:

```text
ORACLE_STAGING_APP_DIR=/opt/apps/<app-name>-staging
ORACLE_STAGING_ENV_FILE=/etc/apps/<app-name>-staging/<app-name>.env
ORACLE_STAGING_STACK_NAME=<app-name>-staging
ORACLE_STAGING_CONTAINER_NAME=<app-name>-staging-api
ORACLE_STAGING_HOST_PORT=3601
```

## Branch model used here

- `develop` -> staging lane
- `main` -> production source lane

## Workflow shape

This repo now expects:

- `Backend CI`
- `Publish Backend Toolchain`
- `Deploy Backend Staging`
- `Deploy Backend Production`

## Manual deploy note

The deploy workflows were updated to use explicit repo lookups through `gh`, so they do not depend on a local `.git` checkout just to find CI artifacts.
