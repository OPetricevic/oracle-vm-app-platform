#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

if ! command -v mysql >/dev/null 2>&1 || ! command -v mysqldump >/dev/null 2>&1; then
  echo "MySQL/MariaDB tools are not installed; skipping backup." >&2
  exit 0
fi

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/apps/mysql}"
RETENTION_DAYS="${RETENTION_DAYS:-60}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST_DIR="${BACKUP_ROOT}/${STAMP}"
TMP_DIR="$(mktemp -d)"

cleanup_tmp() {
  rm -rf "${TMP_DIR}"
}
trap cleanup_tmp EXIT

install -d -m 0750 "${DEST_DIR}"

mysql --batch --skip-column-names -e \
  "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema','mysql','performance_schema','sys') ORDER BY schema_name;" \
  > "${TMP_DIR}/databases.txt"

if [[ ! -s "${TMP_DIR}/databases.txt" ]]; then
  echo "No MySQL/MariaDB databases found to back up."
  exit 0
fi

while IFS= read -r db_name; do
  [[ -n "${db_name}" ]] || continue
  mysqldump \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    "${db_name}" | gzip -9 > "${DEST_DIR}/${db_name}.sql.gz"
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

echo "MySQL/MariaDB backups written to ${DEST_DIR}"
