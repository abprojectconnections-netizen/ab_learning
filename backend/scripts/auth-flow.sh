#!/usr/bin/env sh
# End-to-end check of session security against a running API (dev/test only).
# Needs the API log to read the dev-only password-reset token.
# Usage: BASE_URL=http://127.0.0.1:8080/api/v1 API_LOG=api.log sh scripts/auth-flow.sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8080/api/v1}"
API_LOG="${API_LOG:?set API_LOG to the API's log file}"
EMAIL="flow.$(date +%s)@example.test"
PW1="First-password-1"
PW2="Second-password-2"
PW3="Third-password-3"

json() { python3 -c 'import sys,json; print(json.load(sys.stdin)'"$1"')'; }
post() { # path, body [, bearer]  -> prints "<status> <body>"
  if [ -n "${3:-}" ]; then
    curl -sS -o /tmp/flow.body -w '%{http_code}' -X POST "$BASE_URL$1" -H 'Content-Type: application/json' -H "Authorization: Bearer $3" -d "$2"
  else
    curl -sS -o /tmp/flow.body -w '%{http_code}' -X POST "$BASE_URL$1" -H 'Content-Type: application/json' -d "$2"
  fi
}
expect() { # description, got, want
  if [ "$2" = "$3" ]; then echo "ok   $1 ($2)"; else echo "FAIL $1: got $2, want $3" >&2; cat /tmp/flow.body >&2 2>/dev/null || true; exit 1; fi
}

echo "register..."
code=$(post /auth/register "{\"first_name\":\"Flow\",\"last_name\":\"Test\",\"email\":\"$EMAIL\",\"password\":\"$PW1\"}")
expect "register" "$code" 201
R1=$(json "['refresh_token']" < /tmp/flow.body)

echo "rotate..."
code=$(post /auth/refresh "{\"refresh_token\":\"$R1\"}")
expect "refresh with fresh token" "$code" 200
R2=$(json "['refresh_token']" < /tmp/flow.body)
A2=$(json "['access_token']" < /tmp/flow.body)
[ "$R1" != "$R2" ] || { echo "FAIL refresh token was not rotated" >&2; exit 1; }
echo "ok   refresh token rotated"

echo "reuse detection..."
code=$(post /auth/refresh "{\"refresh_token\":\"$R1\"}")
expect "reusing the old token is rejected" "$code" 401
code=$(post /auth/refresh "{\"refresh_token\":\"$R2\"}")
expect "reuse revoked the whole family" "$code" 401

echo "logout..."
code=$(post /auth/login "{\"identifier\":\"$EMAIL\",\"password\":\"$PW1\"}")
expect "login" "$code" 200
R3=$(json "['refresh_token']" < /tmp/flow.body)
code=$(post /auth/logout "{\"refresh_token\":\"$R3\"}")
expect "logout" "$code" 204
code=$(post /auth/refresh "{\"refresh_token\":\"$R3\"}")
expect "refresh after logout is rejected" "$code" 401
code=$(post /auth/logout "{\"refresh_token\":\"unknown\"}")
expect "logout is idempotent" "$code" 204

echo "forgot/reset password..."
code=$(post /auth/password/forgot '{"email":"nobody-here@example.test"}')
expect "forgot (unknown email) looks identical" "$code" 202
code=$(post /auth/password/forgot "{\"email\":\"$EMAIL\"}")
expect "forgot (known email)" "$code" 202
TOKEN=$(grep "DEV password reset token for $EMAIL" "$API_LOG" | tail -1 | sed 's/.*: //')
[ -n "$TOKEN" ] || { echo "FAIL no reset token in API log" >&2; exit 1; }
code=$(post /auth/password/reset "{\"token\":\"$TOKEN\",\"new_password\":\"short\"}")
expect "weak new password rejected" "$code" 422
code=$(post /auth/password/reset "{\"token\":\"$TOKEN\",\"new_password\":\"$PW2\"}")
expect "reset" "$code" 204
code=$(post /auth/password/reset "{\"token\":\"$TOKEN\",\"new_password\":\"$PW3\"}")
expect "reset token is single-use" "$code" 400
code=$(post /auth/login "{\"identifier\":\"$EMAIL\",\"password\":\"$PW1\"}")
expect "old password no longer works" "$code" 401
code=$(post /auth/login "{\"identifier\":\"$EMAIL\",\"password\":\"$PW2\"}")
expect "new password works" "$code" 200
R4=$(json "['refresh_token']" < /tmp/flow.body)
A4=$(json "['access_token']" < /tmp/flow.body)

echo "change password..."
code=$(curl -sS -o /tmp/flow.body -w '%{http_code}' -X PUT "$BASE_URL/me/password" -H 'Content-Type: application/json' -H "Authorization: Bearer $A4" -d "{\"current_password\":\"wrong\",\"new_password\":\"$PW3\"}")
expect "wrong current password rejected" "$code" 400
code=$(curl -sS -o /tmp/flow.body -w '%{http_code}' -X PUT "$BASE_URL/me/password" -H 'Content-Type: application/json' -H "Authorization: Bearer $A4" -d "{\"current_password\":\"$PW2\",\"new_password\":\"$PW3\"}")
expect "change password" "$code" 204
code=$(post /auth/refresh "{\"refresh_token\":\"$R4\"}")
expect "other sessions are signed out after a password change" "$code" 401

echo "logout-all..."
code=$(post /auth/login "{\"identifier\":\"$EMAIL\",\"password\":\"$PW3\"}")
expect "login with changed password" "$code" 200
R5=$(json "['refresh_token']" < /tmp/flow.body)
A5=$(json "['access_token']" < /tmp/flow.body)
code=$(post /auth/logout-all '{}' "$A5")
expect "logout-all" "$code" 204
code=$(post /auth/refresh "{\"refresh_token\":\"$R5\"}")
expect "refresh after logout-all is rejected" "$code" 401

rm -f /tmp/flow.body
echo "auth flow OK"
