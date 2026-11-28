#!/usr/bin/env sh
# End-to-end check of notifications, orders, reviews and the admin audit log
# against a running API seeded with demo data (local/test only).
# Usage: BASE_URL=... COURSE_A=<id of demo-course-01> COURSE_B=<id of demo-course-02> \
#        COURSE_X=<id of a course demo.learner01 is NOT enrolled in> sh scripts/api-flow.sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8080/api/v1}"
COURSE_A="${COURSE_A:?set COURSE_A}"
COURSE_B="${COURSE_B:?set COURSE_B}"
COURSE_X="${COURSE_X:?set COURSE_X}"
PW="${DEMO_PASSWORD:-Password123!}"
BODY="$(mktemp)"

# call METHOD PATH [TOKEN] [JSON]  -> prints the HTTP status; body in $BODY
call() {
  if [ -n "${4:-}" ]; then
    curl -sS -o "$BODY" -w '%{http_code}' -X "$1" "$BASE_URL$2" -H 'Content-Type: application/json' ${3:+-H "Authorization: Bearer $3"} -d "$4"
  else
    curl -sS -o "$BODY" -w '%{http_code}' -X "$1" "$BASE_URL$2" ${3:+-H "Authorization: Bearer $3"}
  fi
}
jq_() { python3 -c 'import sys,json; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$BODY" "$1"; }
expect() { [ "$2" = "$3" ] && echo "ok   $1 ($2)" || { echo "FAIL $1: got '$2', want '$3'" >&2; cat "$BODY" >&2; exit 1; }; }
atleast() { [ "$2" -ge "$3" ] && echo "ok   $1 ($2)" || { echo "FAIL $1: got $2, want >= $3" >&2; cat "$BODY" >&2; exit 1; }; }
login() { call POST /auth/login "" "{\"identifier\":\"$1\",\"password\":\"$PW\"}" >/dev/null; jq_ "d['access_token']"; }

L1=$(login demo.learner01@example.test)
L2=$(login demo.learner02@example.test)
ADM=$(login demo.admin@example.test)

echo "notifications..."
expect "unauthenticated list" "$(call GET /notifications)" 401
expect "list" "$(call GET /notifications "$L1")" 200
UNREAD=$(jq_ "d['unread_count']"); atleast "has unread" "$UNREAD" 1
NID=$(jq_ "d['items'][0]['id']")
expect "mark read" "$(call POST /notifications/$NID/read "$L1")" 204
expect "mark read again (idempotent)" "$(call POST /notifications/$NID/read "$L1")" 204
expect "other user's notification is 404" "$(call POST /notifications/$NID/read "$L2")" 404
expect "unknown notification is 404" "$(call POST /notifications/999999999/read "$L1")" 404
expect "read-all" "$(call POST /notifications/read-all "$L1")" 204
call GET "/notifications?unread=true" "$L1" >/dev/null; expect "no unread left" "$(jq_ "d['unread_count']")" 0

echo "orders..."
expect "orders require login" "$(call GET /orders)" 401
expect "list orders" "$(call GET /orders "$L1")" 200
atleast "learner01 orders" "$(jq_ 'len(d)')" 2
OID=$(jq_ "d[0]['id']")
expect "order detail" "$(call GET /orders/$OID "$L1")" 200
atleast "order items" "$(jq_ "len(d['items'])")" 1
expect "payment recorded" "$(jq_ "d['payment']['status']")" success
expect "other user's order is 404" "$(call GET /orders/$OID "$L2")" 404
expect "bad status filter" "$(call GET '/orders?status=bogus' "$L1")" 422
expect "status filter" "$(call GET '/orders?status=paid' "$L1")" 200

echo "reviews..."
expect "public review list" "$(call GET /courses/$COURSE_A/reviews)" 200
atleast "course has reviews" "$(jq_ "d['rating_count']")" 1
expect "review requires login" "$(call PUT /courses/$COURSE_A/reviews/me "" '{"rating":5}')" 401
expect "rating out of range" "$(call PUT /courses/$COURSE_A/reviews/me "$L1" '{"rating":9}')" 422
expect "not enrolled cannot review" "$(call PUT /courses/$COURSE_X/reviews/me "$L1" '{"rating":5,"comment":"x"}')" 403
expect "enrolled learner reviews" "$(call PUT /courses/$COURSE_A/reviews/me "$L1" '{"rating":5,"comment":"e2e review"}')" 204
call GET /courses/$COURSE_A/reviews >/dev/null
expect "review visible" "$(jq_ "any(r['comment']=='e2e review' for r in d['items'])")" True
expect "delete own review" "$(call DELETE /courses/$COURSE_A/reviews/me "$L1")" 204
expect "delete again is 404" "$(call DELETE /courses/$COURSE_A/reviews/me "$L1")" 404
expect "unknown course reviews" "$(call GET /courses/999999999/reviews)" 404

echo "admin audit log and moderation..."
expect "learner cannot read audit log" "$(call GET /admin/audit-logs "$L1")" 403
expect "admin reads audit log" "$(call GET /admin/audit-logs "$ADM")" 200
atleast "audit entries" "$(jq_ 'len(d)')" 20
expect "audit filter" "$(call GET '/admin/audit-logs?action=course.approve' "$ADM")" 200
call GET /courses/$COURSE_B/reviews >/dev/null
RID=$(jq_ "d['items'][0]['id']")
expect "learner cannot moderate" "$(call DELETE /admin/reviews/$RID "$L1")" 403
expect "admin deletes review" "$(call DELETE /admin/reviews/$RID "$ADM")" 204
expect "moderating again is 404" "$(call DELETE /admin/reviews/$RID "$ADM")" 404
call GET '/admin/audit-logs?action=review.delete' "$ADM" >/dev/null
atleast "moderation was audited" "$(jq_ 'len(d)')" 1

echo "payment reconciliation..."
expect "learner cannot reconcile" "$(call GET /admin/payments/reconciliation "$L1")" 403
expect "admin reconciles" "$(call GET /admin/payments/reconciliation "$ADM")" 200
expect "report has an issues list" "$(jq_ "isinstance(d['issues'], list) and d['total'] == len(d['issues'])")" True

echo "public curriculum..."
expect "curriculum is public" "$(call GET /courses/$COURSE_A/curriculum)" 200
expect "paid lessons do not leak video urls" "$(jq_ "all(l['is_preview'] or not l['video_url'] for s in d for l in s['lessons'])")" True

rm -f "$BODY"
echo "api flow OK"
