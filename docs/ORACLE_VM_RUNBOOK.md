# Oracle VM Runbook

This is the concrete Oracle OCI runbook for recreating this style of VM setup from zero.

Use this if you want the literal path:

- what to click
- what to name things
- what values to enter
- what commands to run
- what order to do it in

If you want the big-picture explanation first, read:

- [README.md](README.md)
- [ZERO_TO_PRODUCTION.md](ZERO_TO_PRODUCTION.md)

If you want the concrete implementation path, follow this document and the linked step files in order.

## What this runbook builds

- Oracle VM host
- public networking
- SSH access
- PostgreSQL
- Docker
- Caddy
- staging and production backend slots
- GitHub deploy integration
- Cloudflare `/api` proxy target

## Reference values used in this guide

This guide uses sanitized placeholders rather than the real identifiers from the original deployment.

Suggested pattern:

- VCN: `<vcn-name>`
- public subnet: `<public-subnet-name>`
- internet gateway: `<internet-gateway-name>`
- VM name: `<vm-name>`
- SSH user: `ubuntu`
- production app dir: `/opt/apps/<app-name>`
- staging app dir: `/opt/apps/<app-name>-staging`
- production port: `3600`
- staging port: `3601`

## Read in this order

1. [01-vm-creation.md](01-vm-creation.md)
2. [02-networking.md](02-networking.md)
3. [03-first-ssh-and-host-setup.md](03-first-ssh-and-host-setup.md)
4. [APP_PLATFORM.md](APP_PLATFORM.md)
5. [04-database-and-backups.md](04-database-and-backups.md)
6. [05-app-layout-and-env.md](05-app-layout-and-env.md)
7. [06-github-actions-and-secrets.md](06-github-actions-and-secrets.md)
8. [07-public-routing-and-cloudflare.md](07-public-routing-and-cloudflare.md)
9. [08-verification-and-debugging.md](08-verification-and-debugging.md)

## Important operator note

There are two separate success states:

1. the infrastructure path works
2. the application is safe to leave open to the public

This runbook covers the infrastructure path completely.

Whether the app should remain publicly open depends on the app's auth and trust model.
