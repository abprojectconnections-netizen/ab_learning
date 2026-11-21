#!/usr/bin/env sh
# Logical backup of the application database (gzip-compressed mysqldump).
#
# Direct mode (CI / any reachable MySQL):
#   MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=root MYSQL_PWD=... \
#   MYSQL_DATABASE=ab_learning sh scripts/db-backup.sh
# Docker mode (local compose stack, credentials taken from the container):
#   VIA_DOCKER=1 sh scripts/db-backup.sh        (or: make backup)
set -eu
cd "$(dirname "$0")/.."

OUT_DIR="${BACKUP_DIR:-backups}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

if [ "${VIA_DOCKER:-0}" = "1" ]; then
  NAME="${MYSQL_DATABASE:-ab_learning}"
  FILE="$OUT_DIR/${NAME}_${STAMP}.sql.gz"
  docker compose exec -T mysql sh -c \
    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE"' \
    | gzip > "$FILE"
else
  : "${MYSQL_DATABASE:?set MYSQL_DATABASE}"
  FILE="$OUT_DIR/${MYSQL_DATABASE}_${STAMP}.sql.gz"
  mysqldump -h "${MYSQL_HOST:-127.0.0.1}" -P "${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" \
    --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > "$FILE"
fi

# A truncated dump must never look like a good backup.
gzip -t "$FILE"
[ "$(gzip -dc "$FILE" | grep -c '^CREATE TABLE')" -gt 0 ] || { echo "backup contains no tables" >&2; rm -f "$FILE"; exit 1; }
echo "$FILE"
