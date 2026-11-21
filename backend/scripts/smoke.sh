#!/usr/bin/env sh
# Smoke test against a running API: health, login (seeded learner), /me.
# Usage: BASE_URL=http://127.0.0.1:8080/api/v1 sh scripts/smoke.sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8080/api/v1}"
IDENTIFIER="${SMOKE_IDENTIFIER:-learner@ablearning.co}"
PASSWORD="${SMOKE_PASSWORD:-Password123!}"

echo "health..."
curl -fsS "$BASE_URL/health" | grep -q '"status":"ok"'

echo "login..."
resp=$(curl -fsS -X POST "$BASE_URL/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"identifier\":\"$IDENTIFIER\",\"password\":\"$PASSWORD\"}")
token=$(printf '%s' "$resp" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { echo "no access_token in login response" >&2; exit 1; }

echo "me..."
curl -fsS "$BASE_URL/me" -H "Authorization: Bearer $token" | grep -q '"role":"LEARNER"'

echo "public catalog..."
curl -fsS "$BASE_URL/courses" >/dev/null

echo "smoke OK"
