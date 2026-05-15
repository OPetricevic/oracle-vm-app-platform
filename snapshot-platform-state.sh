#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

APP_ROOT="${APP_ROOT:-/opt/apps}"
ENV_ROOT="${ENV_ROOT:-/etc/apps}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/apps}"

section() {
  printf '\n## %s\n\n' "$1"
}

echo "# Oracle Host Platform State Snapshot"
echo
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
echo "This report intentionally excludes secret values, private keys, database passwords, and full env file contents."

section "Host"
hostnamectl 2>/dev/null || hostname
uname -a

section "Resources"
free -h
df -hT / "$APP_ROOT" "$ENV_ROOT" "$BACKUP_ROOT" 2>/dev/null || df -hT /

section "Core Services"
systemctl --no-pager --plain --type=service --all \
  | grep -E 'caddy|docker|containerd|postgresql|mariadb|mysql|fail2ban|unattended|platform-health|oracle-.*backup' || true

section "Timers"
systemctl list-timers --all --no-pager | grep -E 'oracle|backup|postgres|mysql|maria' || true

section "Firewall"
ufw status verbose || true

section "SSH Effective Settings"
sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|clientaliveinterval|clientalivecountmax|x11forwarding|permituserenvironment) ' || true

section "Listening Ports"
ss -tulpn || true

section "Docker"
docker version 2>/dev/null || true
docker info --format 'LoggingDriver={{.LoggingDriver}} DockerRootDir={{.DockerRootDir}}' 2>/dev/null || true
if [[ -f /etc/docker/daemon.json ]]; then
  echo
  echo "/etc/docker/daemon.json:"
  sed -n '1,120p' /etc/docker/daemon.json
fi

section "Containers"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true

section "Caddy"
caddy version 2>/dev/null || true
echo
echo "/etc/caddy/Caddyfile:"
sed -n '1,200p' /etc/caddy/Caddyfile 2>/dev/null || true
echo
echo "/etc/caddy/apps:"
find /etc/caddy/apps -maxdepth 1 -type f -name '*.caddy' -print -exec sed -n '1,200p' {} \; 2>/dev/null || true

section "App Layout"
find "$APP_ROOT" -maxdepth 3 -printf '%M %u %g %p\n' 2>/dev/null | sort || true

section "Env Files Present"
find "$ENV_ROOT" -maxdepth 3 -type f -name '*.env' -printf '%M %u %g %p\n' 2>/dev/null | sort || true

section "Databases"
if command -v psql >/dev/null 2>&1; then
  runuser -u postgres -- psql -tAc "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" 2>/dev/null || true
fi

section "Backup Inventory"
du -sh "$BACKUP_ROOT" 2>/dev/null || true
find "$BACKUP_ROOT" -maxdepth 3 -type d -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort | tail -n 80 || true

section "Installed Platform Commands"
ls -l /usr/local/sbin/platform-status /usr/local/sbin/platform-health /usr/local/sbin/deploy-oracle-app /usr/local/sbin/provision-deploy-user /usr/local/sbin/oracle-postgres-backup.sh /usr/local/sbin/oracle-mysql-backup.sh 2>/dev/null || true
