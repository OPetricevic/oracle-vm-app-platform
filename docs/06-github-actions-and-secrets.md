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
   - `dev`
   - `production`

## Secrets to add to both environments

- `ORACLE_HOST`
- `ORACLE_USER`
- `ORACLE_SSH_KEY`

Example values:

- `ORACLE_HOST=<public-ip>`
- `ORACLE_USER=deploy-<app-id>`

Important:

- use the private key file, not the `.pub` key
- paste the whole private key into the GitHub environment secret
- never commit the key into this repository

## Production variables

Add:

```text
ORACLE_APP_ID=<app-name>
ORACLE_API_DOMAIN=api.<app-name>.example.com
ORACLE_PORT=3610
GHCR_IMAGE=ghcr.io/<owner>/<repo>/backend
```

## Development variables

Add:

```text
ORACLE_APP_ID=<app-name>-dev
ORACLE_API_DOMAIN=api.dev.<app-name>.example.com
ORACLE_PORT=3611
GHCR_IMAGE=ghcr.io/<owner>/<repo>/backend
```

## Branch model used here

- `develop` -> dev lane
- `main` -> production source lane
- production can also be promoted manually through the workflow dispatch control

## Workflow shape

New backend repos should use:

- `templates/github-actions/deploy-backend-oracle.yml`
- GitHub environment `dev` for development deploys
- GitHub environment `production` for production deploys

## Manual deploy note

The deploy workflows were updated to use explicit repo lookups through `gh`, so they do not depend on a local `.git` checkout just to find CI artifacts.
