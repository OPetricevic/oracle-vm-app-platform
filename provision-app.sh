#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

APP_SLUG="${APP_SLUG:-}"
ENVIRONMENT="${ENVIRONMENT:-production}"
APP_TYPE="${APP_TYPE:-api}"
DB_ENGINE="${DB_ENGINE:-postgres}"
DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-}"
DB_PASS="${DB_PASS:-}"
APP_ROOT="${APP_ROOT:-/opt/apps}"
ENV_ROOT="${ENV_ROOT:-/etc/apps}"
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-}"
PORT="${PORT:-}"
FRONTEND_ORIGIN="${FRONTEND_ORIGIN:-}"

if [[ -z "$APP_SLUG" ]]; then
  echo "Required: APP_SLUG" >&2
  exit 1
fi
case "$APP_TYPE" in
  api|static) ;;
  *)
    echo "APP_TYPE must be api or static" >&2
    exit 1
    ;;
esac
if [[ ! "$APP_SLUG" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
  echo "APP_SLUG must use lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen." >&2
  exit 1
fi
if [[ -n "$DB_NAME" && ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "DB_NAME must contain only letters, numbers, and underscores." >&2
  exit 1
fi
if [[ -n "$DB_USER" && ! "$DB_USER" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "DB_USER must contain only letters, numbers, and underscores." >&2
  exit 1
fi
if [[ -n "$DB_PASS" && ! "$DB_PASS" =~ ^[A-Za-z0-9._~!+-]+$ ]]; then
  echo "DB_PASS must be URL-safe: letters, numbers, dot, underscore, tilde, exclamation, plus, or hyphen." >&2
  exit 1
fi

case "$ENVIRONMENT" in
  production|prod)
    SLOT="production"
    APP_ID="$APP_SLUG"
    DEFAULT_PORT="3600"
    ;;
  development|dev)
    SLOT="development"
    APP_ID="${APP_SLUG}-dev"
    DEFAULT_PORT="3601"
    ;;
  staging|stage)
    SLOT="staging"
    APP_ID="${APP_SLUG}-staging"
    DEFAULT_PORT="3601"
    ;;
  *)
    echo "ENVIRONMENT must be production, development, or staging" >&2
    exit 1
    ;;
esac

PORT="${PORT:-$DEFAULT_PORT}"
APP_DIR="${APP_ROOT}/${APP_ID}"
APP_ENV_DIR="${ENV_ROOT}/${APP_ID}"
APP_ENV_FILE="${APP_ENV_DIR}/${APP_SLUG}.env"
APP_USER="${APP_USER:-$APP_ID}"
SAFE_DB_BASE="$(printf '%s' "$APP_ID" | tr '-' '_')"
if [[ ! "$APP_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "APP_USER is not a valid Linux system user name." >&2
  exit 1
fi

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi

install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/releases"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/stack"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/shared"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/shared/data"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/shared/log"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/shared/static"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/shared/uploads"
install -d -m 0750 "$APP_ENV_DIR"

case "$DB_ENGINE" in
  postgres)
    DB_NAME="${DB_NAME:-$SAFE_DB_BASE}"
    DB_USER="${DB_USER:-${SAFE_DB_BASE}_app}"
    if [[ -z "$DB_PASS" ]]; then
      echo "Required for PostgreSQL apps: DB_PASS" >&2
      exit 1
    fi
    su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'\"" | grep -q 1 || \
      su - postgres -c "psql -c \"CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';\""
    su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'\"" | grep -q 1 || \
      su - postgres -c "psql -c \"CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};\""
    DB_URL="postgres://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?sslmode=disable"
    ;;
  mysql|mariadb)
    DB_NAME="${DB_NAME:-$SAFE_DB_BASE}"
    DB_USER="${DB_USER:-${SAFE_DB_BASE}_app}"
    if [[ -z "$DB_PASS" ]]; then
      echo "Required for MySQL/MariaDB apps: DB_PASS" >&2
      exit 1
    fi
    command -v mysql >/dev/null 2>&1 || {
      echo "mysql client is not installed. Re-run bootstrap with INSTALL_MYSQL=1." >&2
      exit 1
    }
    mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
    DB_URL="mysql://${DB_USER}:${DB_PASS}@localhost:3306/${DB_NAME}"
    ;;
  none)
    DB_NAME=""
    DB_USER=""
    DB_URL=""
    ;;
  *)
    echo "DB_ENGINE must be postgres, mysql, mariadb, or none" >&2
    exit 1
    ;;
esac

if [[ ! -f "$APP_ENV_FILE" ]]; then
  cat > "$APP_ENV_FILE" <<EOF
APP_ENV=${SLOT}
PORT=${PORT}
UPLOADS_DIR=${APP_DIR}/shared/uploads
DATA_DIR=${APP_DIR}/shared/data
LOG_DIR=${APP_DIR}/shared/log
EOF
  if [[ -n "$DB_URL" ]]; then
    if [[ "$DB_ENGINE" == "postgres" ]]; then
      echo "DATABASE_URL=${DB_URL}" >> "$APP_ENV_FILE"
    else
      echo "MYSQL_URL=${DB_URL}" >> "$APP_ENV_FILE"
    fi
  fi
  if [[ -n "$FRONTEND_ORIGIN" ]]; then
    echo "CORS_ALLOWED_ORIGINS=${FRONTEND_ORIGIN}" >> "$APP_ENV_FILE"
  fi
  chmod 0640 "$APP_ENV_FILE"
fi

if [[ -n "$PUBLIC_DOMAIN" ]]; then
  install -d -m 0755 /etc/caddy/apps
  CADDY_SNIPPET="/etc/caddy/apps/${APP_ID}.caddy"
  if [[ "$APP_TYPE" == "static" ]]; then
    cat > "$CADDY_SNIPPET" <<EOF
${PUBLIC_DOMAIN} {
    encode gzip zstd
    root * ${APP_DIR}/shared/static
    file_server
}
EOF
  else
    cat > "$CADDY_SNIPPET" <<EOF
${PUBLIC_DOMAIN} {
    encode gzip zstd
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "no-referrer"
        -Server
    }
    reverse_proxy 127.0.0.1:${PORT}
}
EOF
  fi
  caddy fmt --overwrite "$CADDY_SNIPPET"
  systemctl reload caddy
fi

echo "Provisioned app host layout for ${APP_ID}"
echo "Environment: $SLOT"
echo "App directory: $APP_DIR"
echo "Env file: $APP_ENV_FILE"
echo "Runtime port: $PORT"
echo "Database engine: $DB_ENGINE"
echo "Database: ${DB_NAME:-none}"
if [[ -n "$PUBLIC_DOMAIN" ]]; then
  echo "Public domain: $PUBLIC_DOMAIN"
fi
