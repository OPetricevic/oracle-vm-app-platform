#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root or with sudo." >&2
  exit 1
fi

APP_ID="${1:-}"
IMAGE_REF="${2:-}"
APP_ROOT="${APP_ROOT:-/opt/apps}"

if [[ -z "$APP_ID" || -z "$IMAGE_REF" ]]; then
  echo "Usage: deploy-oracle-app <app-id> <image-ref>" >&2
  exit 1
fi

if [[ ! "$APP_ID" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
  echo "Invalid app id: $APP_ID" >&2
  exit 1
fi

APP_DIR="${APP_ROOT}/${APP_ID}"
STACK_DIR="${APP_DIR}/stack"
DEPLOY_ENV="${STACK_DIR}/.deploy.env"
COMPOSE_FILE="${STACK_DIR}/compose.yaml"

if [[ ! -d "$STACK_DIR" || ! -f "$DEPLOY_ENV" || ! -f "$COMPOSE_FILE" ]]; then
  echo "App stack is not provisioned correctly: $STACK_DIR" >&2
  exit 1
fi

if [[ ! "$IMAGE_REF" =~ ^ghcr\.io/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+$ ]]; then
  echo "Image ref must be a tagged GHCR image." >&2
  exit 1
fi

tmp_env="$(mktemp)"
awk -v image_ref="$IMAGE_REF" '
  BEGIN { updated = 0 }
  /^IMAGE_REF=/ {
    print "IMAGE_REF=" image_ref
    updated = 1
    next
  }
  { print }
  END {
    if (!updated) {
      print "IMAGE_REF=" image_ref
    }
  }
' "$DEPLOY_ENV" > "$tmp_env"

install -o root -g root -m 0644 "$tmp_env" "$DEPLOY_ENV"
rm -f "$tmp_env"

docker pull "$IMAGE_REF"
docker compose --env-file "$DEPLOY_ENV" -f "$COMPOSE_FILE" up -d --remove-orphans

set -a
source "$DEPLOY_ENV"
set +a

curl --fail --silent "http://127.0.0.1:${PORT}/api/health" >/dev/null
echo "Deployed ${APP_ID} -> ${IMAGE_REF}"
