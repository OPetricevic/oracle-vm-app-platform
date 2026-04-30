# Zero to Production Guide

This guide turns an application repository into a staged, repeatable production deployment on a single Oracle VM.

It is based on the setup we actually built, not a theoretical clean-room version.

## Who this is for

Use this guide if you want:

- one shared Linux host
- host-managed PostgreSQL, Caddy, backups, firewalling
- app-level container deployments
- `develop` as staging
- `main` as production source
- staging deploys on push
- production deploys on tag

## Final architecture

### Host owns

- Ubuntu VM
- UFW
- fail2ban
- PostgreSQL
- Caddy
- nightly backups
- Docker Engine
- Docker Compose plugin

### App owns

- Docker image
- Go backend binary
- migrations
- runtime process

### Traffic flow

```text
Browser
  -> Cloudflare / DNS
  -> Caddy on Oracle VM (:80/:443)
  -> app container on localhost port
  -> PostgreSQL on localhost
```

### One important reality check

There are two different questions:

1. can the app be deployed live on the internet?
2. is the app's auth and trust model actually ready for open public use?

Those are not the same thing.

In this project, the live path was proven end to end, and then public access was intentionally restricted again because the original application trust model came from a controlled offline-first workflow.

## Branch and release model

- `develop` -> staging
- `main` -> production source branch
- push to `develop` -> staging deploy workflow
- tag like `v1.0.0` -> production deploy workflow
- manual workflow dispatch is also allowed

## What "done" looks like

You are done when:

1. the VM is reachable over SSH
2. PostgreSQL, Caddy, Docker, backups, and firewalling are in place
3. the app has both production and staging slots on the VM
4. GitHub Actions can build and deploy staging from `develop`
5. GitHub Actions can deploy production from a release tag
6. the public domain reaches Caddy and Caddy reaches the container

## Phase 1: Oracle VM and networking

### 1. Create the VM

Target VM shape:

- `VM.Standard.A1.Flex`
- `2 OCPU`
- `12 GB RAM`
- `50 GB boot volume`

If Oracle Free capacity is blocked:

- create `VM.Standard.A2.Flex` with trial credits
- stop it
- reshape it to `VM.Standard.A1.Flex`
- start it again

That was the practical workaround that got this host online.

### 2. Create the VCN and public subnet

VCN:

- name: `<vcn-name>`
- CIDR: `10.0.0.0/16`

Public subnet:

- name: `<public-subnet-name>`
- CIDR: `10.0.0.0/24`
- public subnet

### 3. Internet access must exist in all three places

These three things are all required:

1. public IP on the VM
2. security list ingress rule for port `22`
3. route table rule:

```text
0.0.0.0/0 -> Internet Gateway
```

Important Oracle trap:

- create the Internet Gateway
- do **not** attach the route table to the gateway itself
- edit the subnet route table rules directly

If you attach the route table to the gateway, Oracle treats it like an ingress-routing table and refuses normal internet gateway targets.

## Phase 2: Initial host hardening

SSH into the server:

```bash
ssh ubuntu@<public-ip>
```

Baseline setup:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y ufw fail2ban postgresql postgresql-client caddy docker.io docker-compose-plugin
```

Firewall:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Later, tighten SSH to your IP only.

### Oracle image firewall trap

On this VM image, there may already be old `iptables` rules saved in:

- `/etc/iptables/rules.v4`

and reloaded by:

- `netfilter-persistent`

Those rules can silently sit **in front of** UFW and block public traffic even when:

- Oracle security lists are correct
- UFW shows `80` and `443` allowed
- Caddy is working locally

If public traffic reaches the VM but times out anyway, inspect:

```bash
sudo iptables -L INPUT --line-numbers
sudo iptables -L FORWARD --line-numbers
sudo iptables-save
```

If you find stale manual `ACCEPT/REJECT` rules above the UFW chains, remove them and then resave the good state:

```bash
sudo iptables-save > /etc/iptables/rules.v4
```

This was the final blocker for public HTTP in the real deployment.

## Phase 3: Shared host layout

Create the shared layout:

- `/opt/apps`
- `/etc/apps`
- `/var/backups/apps`

Per-app layout pattern:

- `/opt/apps/<app>`
- `/opt/apps/<app>/shared/uploads`
- `/opt/apps/<app>/stack/compose.yaml`
- `/etc/apps/<app>/<app>.env`

This is the reusable part for future repositories.

## Phase 4: Database and backups

### Production DB

Create:

- DB: `<app-db-name>`
- user: `<app-db-user>`

### Staging DB

Create:

- DB: `<staging-db-name>`
- user: `<staging-db-user>`

### Backups

Install nightly PostgreSQL backups with:

- compressed dump output
- 60-day local retention
- backup root: `/var/backups/apps/postgres`

Minimum professional rule:

- never call the system production-safe until restore has been tested once

## Phase 5: Containerize the backend

This repo now uses:

- `backend/Dockerfile`
- `backend/Dockerfile.toolchain`
- `backend/scripts/generate_protos.sh`

The image build now has two layers of responsibility:

1. `backend/Dockerfile.toolchain`
   - installs `protoc`
   - installs Go codegen tools
   - persists validate includes in a stable path
   - publishes a reusable ARM64 toolchain image
2. `backend/Dockerfile`
   - uses the toolchain image as the builder base
   - generates protobuf and gorm code
   - builds the backend for Linux ARM64
   - packages runtime files into a small Debian image

Why this matters:

- the Oracle VM is ARM64
- local x64 assumptions will betray you if you don't build for the real target
- reinstalling the protobuf toolchain on every CI run wastes a lot of time
- separating the toolchain makes the normal app pipeline faster and more repeatable

### Runtime networking choice

For this setup, the app containers run with:

- `network_mode: host`

instead of ordinary Docker bridge port publishing.

Why:

- PostgreSQL is host-managed and listens on `localhost:5432`
- the app already expects local DB access
- production and staging can still coexist safely by using different host ports
  - production: `3600`
  - staging: `3601`

This avoids making container-to-host database access more awkward than it needs to be on a single shared VM.

## Phase 6: Deployment contract

This repo now follows a repeatable deployment contract.

### Staging

- workflow: `.github/workflows/deploy-backend-staging.yml`
- trigger: push to `develop`
- environment: `staging`
- app dir: `/opt/apps/<app-name>-staging`
- env file: `/etc/apps/<app-name>-staging/<app-name>.env`
- host port: `3601`

### Production

- workflow: `.github/workflows/deploy-backend-container.yml`
- trigger: tag like `v1.0.0` or manual dispatch
- environment: `production`
- app dir: `/opt/apps/<app-name>`
- env file: `/etc/apps/<app-name>/<app-name>.env`
- host port: `3600`

### How deploys work

The server does **not** watch Git directly.

GitHub Actions does this:

1. `Backend CI`
   - checkout repo
   - generate protos
   - run tests
   - build ARM64 image
   - package a deploy artifact
2. deploy workflow
   - download the already-built artifact
   - upload it to Oracle over SSH
   - run deploy script on the server
   - run migrations
   - restart the app container
   - health-check `/api/health`

This is normal production behavior.

## Phase 7: GitHub setup

Create GitHub environments:

- `staging`
- `production`

### Secrets

Add to both environments:

- `ORACLE_HOST`
- `ORACLE_USER`
- `ORACLE_SSH_KEY`

`ORACLE_SSH_KEY` must contain the full private key, copied from your local private key file.

Never commit that key to this repository.

### Production variables

```text
ORACLE_APP_DIR=/opt/apps/<app-name>
ORACLE_ENV_FILE=/etc/apps/<app-name>/<app-name>.env
ORACLE_STACK_NAME=<app-name>
ORACLE_CONTAINER_NAME=<app-name>-api
ORACLE_HOST_PORT=3600
```

### Staging variables

```text
ORACLE_STAGING_APP_DIR=/opt/apps/<app-name>-staging
ORACLE_STAGING_ENV_FILE=/etc/apps/<app-name>-staging/<app-name>.env
ORACLE_STAGING_STACK_NAME=<app-name>-staging
ORACLE_STAGING_CONTAINER_NAME=<app-name>-staging-api
ORACLE_STAGING_HOST_PORT=3601
```

## Phase 8: Public routing

Caddy stays on the host.

It should reverse proxy to local app ports only, for example:

- production -> `127.0.0.1:3600`
- staging -> `127.0.0.1:3601`

That means:

- the app containers do not need direct public exposure
- PostgreSQL never becomes public

### Temporary public lock-down

If you prove the public path works but decide the application should not remain open yet, the simplest safe move is to lock access at Caddy.

Example temporary lock:

```caddy
:80 {
    handle /api/* {
        respond 403
    }

    respond 403
}
```

That keeps the infrastructure path intact while preventing public use until auth and product behavior are truly ready.

## Phase 9: CI vs CD

A healthy production setup has both:

### CI

Runs on PRs and checks:

- proto generation
- tests
- build
- maybe image build

If CI fails:

- red `X`
- no confident merge

### CD

Runs after merge or release and does:

- build image
- upload artifact
- deploy
- migrate
- health check

This repo now has both:

- `Backend CI`
- `Deploy Backend Staging`
- `Deploy Backend Production`
- `Publish Backend Toolchain`

The important split is:

- CI proves the code and packages the artifact
- CD deploys that already-proven artifact

That keeps deploy failures from forcing the entire build and test sequence to rerun unnecessarily.

## Phase 10: Verify the path in layers

Do not debug the whole internet path as one opaque thing. Prove it in layers:

### 1. app locally

```bash
curl -i http://127.0.0.1:3600/api/health
curl -i http://127.0.0.1:3601/api/health
```

### 2. Caddy locally

```bash
curl -i http://127.0.0.1/api/health
curl -i http://10.0.0.79/api/health
```

### 3. public IP directly

From your own machine:

```bash
curl -i http://<public-ip>/api/health
```

### 4. Cloudflare/public host

```bash
curl -i https://<frontend-host>/api/health
```

Only move to the next layer after the previous one is proven.

This sequence prevented a lot of blind guessing in the real deployment.

## Troubleshooting lessons from this setup

### "SSH hangs forever"

Usually means:

- no route rule to Internet Gateway
- or no ingress rule for port 22

### "Cloudflare says 523 Origin is unreachable"

Check the path in this order:

1. app local health
2. Caddy local health
3. direct public IP health
4. Cloudflare origin health

If Cloudflare fails with `523`, do **not** assume Cloudflare is the problem first.

In this deployment, the real issue turned out to be stale host firewall rules, not the worker proxy itself.

### "Cloudflare worker proxy to raw IP behaves badly"

If a `workers.dev` setup rejects a naked origin IP, use a hostname origin instead.

For a temporary setup, a hostname such as `nip.io` can help. Long-term, a real domain or subdomain is cleaner.

The important point is:

- Cloudflare `/api` proxying can work well
- but the backend origin still must be reachable from the internet first

### "Public traffic still times out even though OCI and UFW look correct"

Use packet capture to stop guessing:

```bash
sudo timeout 15 tcpdump -n -l -i any 'tcp port 80'
```

Then hit the public URL once from your machine.

Interpretation:

- if you see no packets, Oracle/network path is still wrong
- if you see SYN packets arrive but no successful response, the bug is on the VM itself

This was the turning point that separated OCI problems from host firewall problems.

### "Public HTTP reaches the VM but never completes"

Check for stale `iptables` rules ahead of UFW.

That exact problem happened here:

- OCI security list was correct
- UFW showed `80/443` allowed
- Caddy was healthy locally
- but an old saved `iptables` `REJECT` rule was still blocking public HTTP

### "Oracle says you must use Private IP as route target"

That usually means:

- you accidentally turned a normal route table into an Internet Gateway ingress-routing table

Fix:

- remove the gateway route-table association
- add the route rule on the subnet route table directly

### "A1 capacity unavailable"

Real answer:

- Oracle Free A1 capacity is often unavailable
- A2 -> A1 reshape with trial credits may be the practical escape hatch

### "Why isn't deploy automatic on production pushes?"

Because production is intentionally safer:

- staging auto-deploys from `develop`
- production deploys only on tag or manual approval

## Reusable pattern for future apps

For a new app, repeat this:

1. create app slot on host
2. create env file
3. create uploads dir if needed
4. create DB/user if needed
5. assign host port
6. add Dockerfile
7. reuse deploy script pattern
8. add Caddy route
9. add GitHub workflow

That is the whole point of this foundation.

You are not rebuilding infrastructure from zero each time anymore. You are onboarding new apps into a known pattern.

## What still makes this "real production"

Even for a small system, don't skip:

- backups
- restore testing
- SSH restriction to your IP
- system updates
- separate staging and production configs
- health checks
- non-public database
- repeatable deploys

## Recommended next improvements

After the first live deploy works:

1. add CI workflow for PRs
2. add staging public route or staging domain
3. add uploads backup and off-box backup copy
4. test restore
5. tighten SSH ingress
6. add branch protection for required CI
7. add lightweight monitoring and alerts

Do not start with Grafana just because it looks grown-up. Start with reliable deploys and recovery.
