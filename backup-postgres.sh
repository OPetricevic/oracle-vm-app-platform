#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/apps/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-60}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST_DIR="${BACKUP_ROOT}/${STAMP}"
TMP_DIR="$(mktemp -d)"

cleanup_tmp() {
  rm -rf "${TMP_DIR}"
}
trap cleanup_tmp EXIT

install -d -m 0750 "${DEST_DIR}"

runuser -u postgres -- psql -At -c \
  "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true ORDER BY datname;" \
  > "${TMP_DIR}/databases.txt"

if [[ ! -s "${TMP_DIR}/databases.txt" ]]; then
  echo "No databases found to back up." >&2
  exit 1
fi

runuser -u postgres -- pg_dumpall --globals-only \
  | gzip -9 > "${DEST_DIR}/globals.sql.gz"

while IFS= read -r db_name; do
  [[ -n "${db_name}" ]] || continue
  runuser -u postgres -- pg_dump \
    --format=custom \
    "${db_name}" > "${DEST_DIR}/${db_name}.dump"
done < "${TMP_DIR}/databases.txt"

cp "${TMP_DIR}/databases.txt" "${DEST_DIR}/databases.txt"

(
  cd "${DEST_DIR}"
  sha256sum ./* > SHA256SUMS
)

find "${BACKUP_ROOT}" \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -mtime +"${RETENTION_DAYS}" \
  -exec rm -rf {} +

echo "PostgreSQL backups written to ${DEST_DIR}"
