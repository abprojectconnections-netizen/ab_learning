#!/usr/bin/env sh
# End-to-end SANDBOX payment flow against a running API seeded with demo data:
# checkout, idempotency, webhook signature, duplicate delivery, amount check,
# failure handling, enrollment and admin refund. No real money is involved.
# Usage: BASE_URL=... PAYMENT_WEBHOOK_SECRET=... COURSE_A=<id> COURSE_B=<id> sh scripts/payment-flow.sh
# COURSE_A and COURSE_B must be published, paid courses.
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8080/api/v1}"
SECRET="${PAYMENT_WEBHOOK_SECRET:?set PAYMENT_WEBHOOK_SECRET}"
COURSE_A="${COURSE_A:?set COURSE_A}"
COURSE_B="${COURSE_B:?set COURSE_B}"
PW="${DEMO_PASSWORD:-Password123!}"
EMAIL="pay.$(date +%s)@example.test"
BODY="$(mktemp)"

# call METHOD PATH TOKEN JSON [extra curl args...] -> prints the HTTP status; body in $BODY
call() {
  m="$1"; p="$2"; tok="$3"; data="$4"; shift 4
  if [ -n "$data" ]; then
    curl -sS -o "$BODY" -w '%{http_code}' -X "$m" "$BASE_URL$p" -H 'Content-Type: application/json' ${tok:+-H "Authorization: Bearer $tok"} "$@" -d "$data"
  else
    curl -sS -o "$BODY" -w '%{http_code}' -X "$m" "$BASE_URL$p" ${tok:+-H "Authorization: Bearer $tok"} "$@"
  fi
}
jq_() { python3 -c 'import sys,json; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$BODY" "$1"; }
expect() { [ "$2" = "$3" ] && echo "ok   $1 ($2)" || { echo "FAIL $1: got '$2', want '$3'" >&2; cat "$BODY" >&2; exit 1; }; }

# webhook BODY [TS] [SECRET] -> status. Signature: HMAC-SHA256 over "<ts>.<body>".
webhook() {
  ts="${2:-$(date +%s)}"; key="${3:-$SECRET}"
  sig=$(printf '%s.%s' "$ts" "$1" | openssl dgst -sha256 -hmac "$key" -hex | sed 's/^.* //')
  curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE_URL/webhooks/payments" \
    -H "Payment-Signature: t=$ts,v1=$sig" -H 'Content-Type: application/json' -d "$1"
}
event() { # id type livemode ref amount_minor
  printf '{"id":"%s","type":"%s","livemode":%s,"data":{"reference":"%s","amount":%s,"currency":"THB"}}' "$1" "$2" "$3" "$4" "$5"
}
RUN="$(date +%s)"

echo "account..."
expect "register" "$(call POST /auth/register "" "{\"first_name\":\"Pay\",\"last_name\":\"Flow\",\"email\":\"$EMAIL\",\"password\":\"$PW\"}")" 201
TOKEN=$(jq_ "d['access_token']")
call POST /auth/login "" '{"identifier":"demo.admin@example.test","password":"'"$PW"'"}' >/dev/null
ADMIN=$(jq_ "d['access_token']")

echo "checkout..."
expect "checkout needs login" "$(call POST /checkout "" "{\"course_ids\":[$COURSE_A]}")" 401
expect "checkout needs Idempotency-Key" "$(call POST /checkout "$TOKEN" "{\"course_ids\":[$COURSE_A]}")" 422
expect "unknown course" "$(call POST /checkout "$TOKEN" '{"course_ids":[999999999]}' -H "Idempotency-Key: unknown-$RUN")" 404
expect "create order" "$(call POST /checkout "$TOKEN" "{\"course_ids\":[$COURSE_A],\"method\":\"card\"}" -H "Idempotency-Key: order-a-$RUN")" 201
OID=$(jq_ "d['order_id']"); PID=$(jq_ "d['payment_id']"); REF=$(jq_ "d['provider_ref']")
MINOR=$(jq_ "round(d['amount']*100)")
expect "starts pending" "$(jq_ "d['status']")" pending
expect "sandbox flag" "$(jq_ "d['sandbox']")" True

echo "idempotency..."
expect "same key + same request replays" "$(call POST /checkout "$TOKEN" "{\"course_ids\":[$COURSE_A],\"method\":\"card\"}" -H "Idempotency-Key: order-a-$RUN")" 201
expect "replay returns the same order" "$(jq_ "d['order_id']")" "$OID"
expect "same key + different request conflicts" "$(call POST /checkout "$TOKEN" "{\"course_ids\":[$COURSE_B]}" -H "Idempotency-Key: order-a-$RUN")" 409
expect "order is pending" "$(call GET /orders/$OID "$TOKEN" "")" 200
expect "payment is pending" "$(jq_ "d['payment']['status']")" pending

echo "webhook security..."
EV=$(event "evt-$RUN-1" payment.succeeded false "$REF" "$MINOR")
expect "bad signature" "$(webhook "$EV" "$(date +%s)" wrong-secret-wrong-secret-0000)" 400
expect "stale timestamp" "$(webhook "$EV" "$(( $(date +%s) - 3600 ))")" 400
expect "live-mode event refused" "$(webhook "$(event "evt-$RUN-live" payment.succeeded true "$REF" "$MINOR")")" 400
expect "amount mismatch is rejected" "$(webhook "$(event "evt-$RUN-bad" payment.succeeded false "$REF" 1)")" 200
expect "mismatch outcome" "$(jq_ "d['status']")" rejected
call GET /orders/$OID "$TOKEN" "" >/dev/null
expect "order still pending after mismatch" "$(jq_ "d['status']")" pending

echo "payment success..."
expect "signed success event" "$(webhook "$EV")" 200
expect "processed" "$(jq_ "d['status']")" processed
call GET /orders/$OID "$TOKEN" "" >/dev/null
expect "order paid" "$(jq_ "d['status']")" paid
expect "payment success" "$(jq_ "d['payment']['status']")" success
expect "duplicate delivery changes nothing" "$(webhook "$EV")" 200
expect "duplicate outcome" "$(jq_ "d['status']")" duplicate
expect "already enrolled blocks a second purchase" "$(call POST /checkout "$TOKEN" "{\"course_ids\":[$COURSE_A]}" -H "Idempotency-Key: order-a2-$RUN")" 409

echo "payment failure..."
expect "second order" "$(call POST /checkout "$TOKEN" "{\"course_ids\":[$COURSE_B],\"method\":\"promptpay\"}" -H "Idempotency-Key: order-b-$RUN")" 201
OID2=$(jq_ "d['order_id']"); REF2=$(jq_ "d['provider_ref']"); MINOR2=$(jq_ "round(d['amount']*100)")
expect "failure event" "$(webhook "$(event "evt-$RUN-2" payment.failed false "$REF2" 0)")" 200
expect "failure processed" "$(jq_ "d['status']")" processed
call GET /orders/$OID2 "$TOKEN" "" >/dev/null
expect "order failed" "$(jq_ "d['status']")" failed
expect "late success after failure is ignored" "$(webhook "$(event "evt-$RUN-3" payment.succeeded false "$REF2" "$MINOR2")")" 200
expect "ignored outcome" "$(jq_ "d['status']")" ignored
call GET /orders/$OID2 "$TOKEN" "" >/dev/null
expect "order stays failed" "$(jq_ "d['status']")" failed

echo "refund..."
expect "learner cannot refund" "$(call POST /admin/payments/$PID/refund "$TOKEN" '{"reason":"nope"}')" 403
expect "refund needs a reason" "$(call POST /admin/payments/$PID/refund "$ADMIN" '{}')" 422
expect "admin refund" "$(call POST /admin/payments/$PID/refund "$ADMIN" '{"reason":"sandbox flow test"}')" 200
expect "order refunded" "$(jq_ "d['order_status']")" refunded
expect "double refund refused" "$(call POST /admin/payments/$PID/refund "$ADMIN" '{"reason":"again"}')" 409

echo "payment flow OK"
