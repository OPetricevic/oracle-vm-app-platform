# 03 - First SSH and Host Setup

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Get onto the VM, install the host packages, enable the host firewall, and prepare the shared machine.

## First SSH

From your local machine:

```bash
ssh ubuntu@<PUBLIC_IP>
```

Example from this deployment:

```bash
ssh ubuntu@<public-ip>
```

If it hangs:

- go back to [02-networking.md](02-networking.md)
- check SSH ingress and route table

## Baseline host bootstrap

On the VM:

```bash
sudo ./bootstrap-host.sh
```

That installs and enables:

- Docker and Docker Compose
- Caddy
- PostgreSQL
- UFW
- fail2ban
- unattended upgrades
- nightly PostgreSQL backups
- `/opt/apps`, `/etc/apps`, and `/var/backups/apps`

If an app needs MySQL/MariaDB:

```bash
sudo INSTALL_MYSQL=1 ./bootstrap-host.sh
```

That also installs MariaDB and enables nightly MySQL/MariaDB backups.

Optional Docker convenience:

```bash
sudo usermod -aG docker ubuntu
```

If you do that, log out and back in later for group membership to apply.

## UFW setup

The bootstrap enables UFW with only:

- SSH
- HTTP
- HTTPS

Verify:

```bash
sudo ufw status
```

## Shared host layout

The bootstrap creates:

```text
/opt/apps
/etc/apps
/var/backups/apps
/etc/caddy/apps
```

Caddy imports one snippet per app from `/etc/caddy/apps/*.caddy`.

## Oracle image firewall trap

This matters enough to repeat here.

Even if:

- Oracle security lists are correct
- UFW says `80` and `443` are allowed

public traffic can still fail because of old image-level `iptables` rules.

Inspect:

```bash
sudo iptables -L INPUT --line-numbers
sudo iptables -L FORWARD --line-numbers
sudo iptables-save
```

If you see stale rules before UFW chains, remove them carefully and then persist the good state:

```bash
sudo iptables-save > /etc/iptables/rules.v4
```

That exact issue blocked public HTTP in the real deployment even after all the obvious settings looked correct.
