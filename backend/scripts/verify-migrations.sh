#!/usr/bin/env sh
# Asserts that migration 003 produced the expected schema and reference data.
# Usage: MYSQL_DATABASE=ab_upgrade [MYSQL_HOST/PORT/USER/MYSQL_PWD] sh scripts/verify-migrations.sh
set -eu
: "${MYSQL_DATABASE:?set MYSQL_DATABASE}"
M="mysql -h ${MYSQL_HOST:-127.0.0.1} -P ${MYSQL_PORT:-3306} -u ${MYSQL_USER:-root} -N $MYSQL_DATABASE"

q() { $M -e "$1"; }
expect() { # description, actual, minimum
  if [ "$2" -ge "$3" ]; then echo "ok   $1 ($2)"; else echo "FAIL $1: got $2, want >= $3" >&2; exit 1; fi
}

for t in permissions role_permissions menu_items menu_item_roles refresh_tokens payment_events idempotency_keys app_settings; do
  expect "table $t" "$(q "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='$t'")" 1
done
expect "migrations recorded" "$(q "SELECT COUNT(*) FROM schema_migrations")" 3
expect "role SUPER_ADMIN" "$(q "SELECT COUNT(*) FROM roles WHERE code='SUPER_ADMIN'")" 1
expect "permissions" "$(q "SELECT COUNT(*) FROM permissions")" 15
expect "super admin has every permission" "$(q "SELECT COUNT(*) FROM role_permissions rp JOIN roles r ON r.id=rp.role_id WHERE r.code='SUPER_ADMIN'")" 15
expect "menu items" "$(q "SELECT COUNT(*) FROM menu_items")" 30
expect "active menu items" "$(q "SELECT COUNT(*) FROM menu_items WHERE is_active=1")" 15
expect "app settings" "$(q "SELECT COUNT(*) FROM app_settings")" 7
# Every menu item must be visible to at least one role.
orphans=$(q "SELECT COUNT(*) FROM menu_items m LEFT JOIN menu_item_roles mr ON mr.menu_item_id=m.id WHERE mr.menu_item_id IS NULL")
[ "$orphans" = "0" ] || { echo "FAIL menu items without roles: $orphans" >&2; exit 1; }
echo "ok   every menu item has a role"
# Payments must stay in sandbox by default.
mode=$(q "SELECT setting_value FROM app_settings WHERE setting_key='payments.mode'")
[ "$mode" = '"sandbox"' ] || { echo "FAIL payments.mode is $mode" >&2; exit 1; }
echo "ok   payments.mode is sandbox"
echo "migrations verified"
