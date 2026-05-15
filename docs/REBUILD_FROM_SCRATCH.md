# Rebuild From Scratch

This document describes how to recreate the Oracle host platform from a clean Ubuntu VM.

It is a rebuild guide for layout and configuration. It is not a secret store and not a data backup.

## What Can Be Rebuilt From This Repo

This repository can recreate:

- package baseline: Docker, Docker Compose, Caddy, PostgreSQL, optional MariaDB, UFW, fail2ban
- host directories: `/opt/apps`, `/etc/apps`, `/var/backups/apps`
- backup scripts and systemd timers
- deployment commands: `deploy-oracle-app`, `provision-deploy-user`
- Caddy app route convention
- per-app folder layout
- GitHub Actions deploy contract

This repository must not contain:

- SSH private keys
- database passwords
- full `.env` files
- application uploads
- database dumps
- Cloudflare tokens
- GitHub tokens

## Current Platform Identity

```text
base domain: <base-domain>
public health API: https://api.<base-domain>/health
host pattern: Oracle Ubuntu VM
frontend hosting: Cloudflare Pages/Workers
backend hosting: Oracle VM behind Caddy
database: local PostgreSQL per app/environment
```

## Rebuild Inputs

Before rebuilding, collect:

- new public server IP
- SSH public key for operator access
- Cloudflare account access
- app list to restore
- database dump files, if restoring data
- uploaded files, if restoring data
- per-app env secrets from a secure source

## Fresh VM Steps

1. Create a clean Ubuntu VM.
2. Open only SSH, HTTP, and HTTPS in the cloud firewall/security list.
3. SSH in as the initial user.
4. Clone this repository onto the server.
5. Run:

```bash
sudo ./bootstrap-host.sh
```

If MariaDB is needed:

```bash
sudo INSTALL_MYSQL=1 ./bootstrap-host.sh
```

6. Install or verify SSH hardening:

```text
/etc/ssh/sshd_config.d/99-platform-hardening.conf
```

Expected values:

```text
PermitRootLogin no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

7. Install Docker log rotation:

```text
/etc/docker/daemon.json
```

Expected values:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
```

Restart Docker after validating the config:

```bash
sudo dockerd --validate --config-file /etc/docker/daemon.json
sudo systemctl restart docker
```

8. Disable unused NFS/RPC services unless a future app explicitly needs them:

```bash
sudo systemctl disable --now rpcbind.socket rpcbind.service nfs-client.target
```

The current `bootstrap-host.sh` applies the SSH hardening, Docker log rotation, and RPC/NFS disablement baseline automatically. These steps remain here as a verification checklist.

## Platform Health API

Optionally install the platform health service during bootstrap:

```bash
sudo INSTALL_PLATFORM_HEALTH=1 \
  PLATFORM_HEALTH_DOMAIN=api.example.com \
  ./bootstrap-host.sh
```

Installed files:

```text
/usr/local/sbin/platform-health
/etc/systemd/system/platform-health.service
/etc/caddy/apps/platform-health.caddy
```

It should bind only to:

```text
127.0.0.1:3500
```

Caddy route:

```text
api.example.com -> 127.0.0.1:3500
```

Cloudflare DNS:

```text
Type: A
Name: api
Content: <server-public-ip>
Proxy: enabled
```

Verify:

```bash
curl --fail https://api.example.com/health
```

## App Slot Rebuild

Production:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.my-app.example.com \
  PORT=3610 \
  DB_ENGINE=postgres \
  DB_NAME=my_app \
  DB_PASS='restore-from-secret-store' \
  ./provision-app.sh
```

Development:

```bash
sudo APP_SLUG=my-app \
  ENVIRONMENT=development \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.dev.my-app.example.com \
  PORT=3611 \
  DB_ENGINE=postgres \
  DB_NAME=my_app_dev \
  DB_PASS='restore-from-secret-store' \
  ./provision-app.sh
```

After provisioning:

1. restore `/etc/apps/<app-id>/<app>.env` values from a secure source
2. restore database dump if needed
3. restore uploads if needed
4. install `/opt/apps/<app-id>/stack/compose.yaml`
5. install `/opt/apps/<app-id>/stack/.deploy.env`
6. create deploy user with `provision-deploy-user`
7. deploy latest image with `deploy-oracle-app`
8. add Cloudflare DNS only when intentionally publishing the app

## Safe State Snapshot

Run this on the live server to record non-secret platform state:

```bash
sudo ./snapshot-platform-state.sh > platform-state-$(date -u +%Y%m%dT%H%M%SZ).md
```

The snapshot includes:

- services
- firewall rules
- SSH effective settings
- listening ports
- Docker config
- Caddy routes
- app directory inventory
- env file paths only
- database names only
- backup inventory

It intentionally excludes secret values.

## Data Recovery Boundary

This repo rebuilds the machine shape. It does not preserve data.

For serious apps, add an off-server backup target and test restore. Without that, a VM loss means local database dumps and uploaded files may be lost with the VM.

## Final Verification

Run:

```bash
sudo platform-status
curl --fail https://api.example.com/health
sudo systemctl list-timers oracle-postgres-backup.timer oracle-mysql-backup.timer
sudo ufw status verbose
```
