#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="${APP_ROOT:-/opt/apps}"
ENV_ROOT="${ENV_ROOT:-/etc/apps}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/apps}"
INSTALL_MYSQL="${INSTALL_MYSQL:-0}"

apt-get update -y
apt-get upgrade -y
apt-get install -y \
  ca-certificates \
  caddy \
  curl \
  docker.io \
  fail2ban \
  gnupg \
  postgresql \
  postgresql-client \
  postgresql-contrib \
  ufw \
  unattended-upgrades \
  unzip

if ! apt-get install -y docker-compose-plugin; then
  if ! apt-get install -y docker-compose-v2; then
    apt-get install -y docker-compose
  fi
fi

if [[ "$INSTALL_MYSQL" == "1" ]]; then
  apt-get install -y mariadb-server mariadb-client
fi

install -d -m 0755 "$APP_ROOT"
install -d -m 0750 "$ENV_ROOT"
install -d -m 0750 "$BACKUP_ROOT"
install -d -m 0750 "${BACKUP_ROOT}/postgres"
install -d -m 0750 "${BACKUP_ROOT}/mysql"
install -d -m 0755 /etc/caddy/apps

install -m 0755 \
  "${ROOT_DIR}/backup-postgres.sh" \
  /usr/local/sbin/oracle-postgres-backup.sh
install -m 0755 \
  "${ROOT_DIR}/backup-mysql.sh" \
  /usr/local/sbin/oracle-mysql-backup.sh
install -m 0644 \
  "${ROOT_DIR}/oracle-postgres-backup.service" \
  /etc/systemd/system/oracle-postgres-backup.service
install -m 0644 \
  "${ROOT_DIR}/oracle-postgres-backup.timer" \
  /etc/systemd/system/oracle-postgres-backup.timer
install -m 0644 \
  "${ROOT_DIR}/oracle-mysql-backup.service" \
  /etc/systemd/system/oracle-mysql-backup.service
install -m 0644 \
  "${ROOT_DIR}/oracle-mysql-backup.timer" \
  /etc/systemd/system/oracle-mysql-backup.timer

if [[ ! -f /etc/caddy/Caddyfile ]]; then
  cat > /etc/caddy/Caddyfile <<'EOF'
import /etc/caddy/apps/*.caddy
EOF
elif ! grep -q "import /etc/caddy/apps/\\*.caddy" /etc/caddy/Caddyfile; then
  printf '\nimport /etc/caddy/apps/*.caddy\n' >> /etc/caddy/Caddyfile
fi

systemctl enable postgresql
systemctl start postgresql
if [[ "$INSTALL_MYSQL" == "1" ]]; then
  systemctl enable mariadb
  systemctl start mariadb
fi
systemctl enable docker
systemctl start docker
systemctl enable caddy
systemctl start caddy
systemctl daemon-reload
systemctl enable oracle-postgres-backup.timer
systemctl start oracle-postgres-backup.timer
if [[ "$INSTALL_MYSQL" == "1" ]]; then
  systemctl enable oracle-mysql-backup.timer
  systemctl start oracle-mysql-backup.timer
fi

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "Oracle host bootstrap complete."
echo "App root: $APP_ROOT"
echo "Env root: $ENV_ROOT"
echo "Backup root: $BACKUP_ROOT"
echo "MySQL/MariaDB installed: $INSTALL_MYSQL"
