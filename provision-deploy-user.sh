#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

APP_ID="${APP_ID:-}"
DEPLOY_USER="${DEPLOY_USER:-}"
DEPLOY_PUBLIC_KEY="${DEPLOY_PUBLIC_KEY:-}"
DEPLOY_PUBLIC_KEY_FILE="${DEPLOY_PUBLIC_KEY_FILE:-}"

if [[ -z "$APP_ID" ]]; then
  echo "Required: APP_ID" >&2
  exit 1
fi

if [[ ! "$APP_ID" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
  echo "APP_ID must use lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen." >&2
  exit 1
fi

DEPLOY_USER="${DEPLOY_USER:-deploy-${APP_ID}}"

if [[ ! "$DEPLOY_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "DEPLOY_USER is not a valid Linux user name." >&2
  exit 1
fi

if [[ -z "$DEPLOY_PUBLIC_KEY" && -n "$DEPLOY_PUBLIC_KEY_FILE" ]]; then
  DEPLOY_PUBLIC_KEY="$(cat "$DEPLOY_PUBLIC_KEY_FILE")"
fi

if [[ -z "$DEPLOY_PUBLIC_KEY" ]]; then
  echo "Required: DEPLOY_PUBLIC_KEY or DEPLOY_PUBLIC_KEY_FILE" >&2
  exit 1
fi

case "$DEPLOY_PUBLIC_KEY" in
  ssh-ed25519\ *|ssh-rsa\ *) ;;
  *)
    echo "DEPLOY_PUBLIC_KEY must be an OpenSSH public key." >&2
    exit 1
    ;;
esac

HOME_DIR="/var/lib/oracle-deploy/${APP_ID}"

if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "$HOME_DIR" --shell /bin/bash "$DEPLOY_USER"
fi

install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" -m 0750 "$HOME_DIR"
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" -m 0700 "$HOME_DIR/.ssh"
printf '%s\n' "$DEPLOY_PUBLIC_KEY" > "$HOME_DIR/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "$HOME_DIR/.ssh/authorized_keys"
chmod 0600 "$HOME_DIR/.ssh/authorized_keys"

SUDOERS_FILE="/etc/sudoers.d/oracle-deploy-${APP_ID}"
cat > "$SUDOERS_FILE" <<EOF
${DEPLOY_USER} ALL=(root) NOPASSWD: /usr/local/sbin/deploy-oracle-app ${APP_ID} *
EOF
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" >/dev/null

echo "Provisioned deploy user: ${DEPLOY_USER}"
echo "Allowed app id: ${APP_ID}"
echo "Home: ${HOME_DIR}"
