# Second Brain

This is the canonical working memory for the reusable host and the apps that deploy onto it.

Use this file as the first stop when you need context that is stable enough to reuse:

- host layout and invariants
- deployment contract
- app inventory
- decisions already made
- open questions and follow-up work

Keep it short, factual, and current. If a fact changes, update this file before or alongside the code change.

## How To Read This

Start here:

1. `README.md`
2. `docs/APP_PLATFORM.md`
3. `docs/SECOND_BRAIN.md`
4. `docs/REBUILD_FROM_SCRATCH.md`
5. the relevant app dossier, if one exists

## Canonical Facts

- This repository is the reusable host/platform repo.
- Application repositories own app code, Dockerfiles, migrations, deploy workflows, and app-specific runtime behavior.
- The host owns the shared Linux machine, Docker, Caddy, PostgreSQL, backups, and per-app slots.
- The host layout is intentionally reusable across unrelated apps.
- Production and development live in separate app directories, env files, ports, databases, deploy users, and domains.
- Use placeholder domains in this public repo. Keep live domain/IP/app inventory in a private repo or private notes.
- A public health endpoint can be exposed as `https://api.<base-domain>/health` when a private deployment chooses to publish it.

## Current Host Model

- Current host IP, hostname, operator users, and exact app inventory are deployment-specific and should not be committed here.
- App directories live under `/opt/apps/<app-slug>`.
- Env files live under `/etc/apps/<app-slug>/<app-slug>.env`.
- Caddy imports snippets from `/etc/caddy/apps/*.caddy`.
- Backups live under `/var/backups/apps`.
- App releases use `releases/`, `stack/`, and `shared/` inside each app directory.
- Platform status command: `sudo platform-status`.
- Safe non-secret state snapshot command: `sudo snapshot-platform-state`.
- Optional health endpoint command: `sudo INSTALL_PLATFORM_HEALTH=1 PLATFORM_HEALTH_DOMAIN=api.example.com ./bootstrap-host.sh`.

## Domain Model

Use this pattern:

```text
<app>.<base-domain>          -> production frontend on Cloudflare Pages/Workers
api.<app>.<base-domain>      -> production API on the host through Caddy
dev.<app>.<base-domain>      -> development frontend on Cloudflare Pages/Workers
api.dev.<app>.<base-domain>  -> development API on the host through Caddy
```

The database remains private on the Oracle host.

## Deployment Contract

The current app deployment model is:

- GitHub Actions builds and pushes a backend container image to GHCR.
- Each app/environment gets a narrow deploy user created by `provision-deploy-user`.
- CI connects over SSH as that deploy user.
- The deploy user may only run `/usr/local/sbin/deploy-oracle-app <app-id> <image-ref>` for its app.
- `deploy-oracle-app` updates `/opt/apps/<app-id>/stack/.deploy.env`, runs Docker Compose, and verifies `/api/health`.
- Secrets stay in `/etc/apps/<app-id>/<app-slug>.env` or GitHub environment secrets, never in Git.

## Slot Model

Production:

```text
/opt/apps/<app>
/etc/apps/<app>/<app>.env
database: <app>
domain: api.<app>.<base-domain>
```

Development:

```text
/opt/apps/<app>-dev
/etc/apps/<app>-dev/<app>.env
database: <app>_dev
domain: api.dev.<app>.<base-domain>
```

## App Inventory

Track one short dossier per app. Keep only the facts we need to deploy or debug it.

Current apps belong in private deployment inventory, not this public repo.

## App Dossier Template

Copy this into a new file for each app:

```markdown
# <app-slug>

## Purpose

## Runtime

## Database

## Storage

## Domains

## Deploy Path

## Secrets / Env

## Known Risks

## Last Verified
```

## Decision Log

Add one line per meaningful platform decision.

- Host repo is provider-neutral even though the historical name says Oracle.
- PostgreSQL remains the primary database choice for Physio and future apps that fit that stack.
- Small low-power machines are preferred for home hosting.
- Use development and production as the default app environments; staging can be a project-specific synonym but is not the platform default.
- For safety, expose only intentionally published Caddy routes and Cloudflare DNS records.
- The server is a portfolio/demo/playground platform, not the sole home for serious customer data unless off-server backups and restore drills are added.
- Frontends should usually live on Cloudflare Pages/Workers; Oracle hosts APIs, databases, uploads, and background jobs.

## Current Security Baseline

- UFW default denies incoming traffic and allows only SSH, HTTP, and HTTPS.
- SSH is key-only; password login and root login are disabled.
- SSH hardening lives in `/etc/ssh/sshd_config.d/99-platform-hardening.conf`.
- fail2ban is enabled for SSH.
- unattended upgrades are enabled.
- PostgreSQL and MariaDB are bound to localhost.
- `rpcbind` and `nfs-client.target` are disabled.
- Docker log rotation is configured in `/etc/docker/daemon.json` with `max-size=10m` and `max-file=5`.
- Nightly PostgreSQL and MySQL/MariaDB backup timers are enabled.

## Rebuild Model

- This repo is the safe-keep source for host layout, scripts, docs, and deployment conventions.
- `docs/REBUILD_FROM_SCRATCH.md` is the rebuild path for a clean VM.
- `snapshot-platform-state` records non-secret live server inventory for comparison and recovery planning.
- This repo does not replace off-server backups for database dumps or uploaded files.
- Keep deployment-specific domains, IPs, hostnames, app inventories, and state snapshots in private notes or a private infra repository.

## Open Questions

- Which apps need object storage for uploads instead of local disk?
- When should SSH be restricted to a fixed IP or private access layer?
- Which off-server backup target should be used if any app starts holding valuable data?
- Which first app should be onboarded into the new dev/prod deploy flow?

## Update Rule

If you change a host convention, update this file in the same change set.
