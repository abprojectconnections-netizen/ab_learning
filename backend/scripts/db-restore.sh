#!/usr/bin/env sh
# Restore a backup made by db-backup.sh into an EMPTY database.
# It never overwrites existing data: it aborts if the target already has tables.
#
#   RESTORE_CONFIRM=yes MYSQL_DATABASE=ab_restore sh scripts/db-restore.sh backups/file.sql.gz
#   RESTORE_CONFIRM=yes VIA_DOCKER=1 sh scripts/db-restore.sh backups/file.sql.gz   (make restore FILE=...)
set -eu
cd "$(dirname "$0")/.."

FILE="${1:?usage: db-restore.sh <backup.sql.gz>}"
[ -f "$FILE" ] || { echo "no such file: $FILE" >&2; exit 1; }
[ "${RESTORE_CONFIRM:-}" = "yes" ] || { echo "set RESTORE_CONFIRM=yes to restore" >&2; exit 1; }
case "${APP_ENV:-dev}" in
  production|staging) echo "refusing to restore while APP_ENV=${APP_ENV}" >&2; exit 1 ;;
esac
gzip -t "$FILE"

if [ "${VIA_DOCKER:-0}" = "1" ]; then
  tables=$(docker compose exec -T mysql sh -c \
    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()" "$MYSQL_DATABASE"')
  [ "$tables" = "0" ] || { echo "target database is not empty ($tables tables); restore aborted" >&2; exit 1; }
  gzip -dc "$FILE" | docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE"'
else
  : "${MYSQL_DATABASE:?set MYSQL_DATABASE}"
  M="mysql -h ${MYSQL_HOST:-127.0.0.1} -P ${MYSQL_PORT:-3306} -u ${MYSQL_USER:-root}"
  tables=$($M -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$MYSQL_DATABASE'")
  [ "$tables" = "0" ] || { echo "target database is not empty ($tables tables); restore aborted" >&2; exit 1; }
  gzip -dc "$FILE" | $M "$MYSQL_DATABASE"
fi
echo "restore OK"
