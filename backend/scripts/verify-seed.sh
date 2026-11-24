#!/usr/bin/env sh
# Asserts the demo seed gave every module at least 20 rows.
# Usage: MYSQL_DATABASE=ab_test [MYSQL_HOST/PORT/USER/MYSQL_PWD] sh scripts/verify-seed.sh
set -eu
: "${MYSQL_DATABASE:?set MYSQL_DATABASE}"
M="mysql -h ${MYSQL_HOST:-127.0.0.1} -P ${MYSQL_PORT:-3306} -u ${MYSQL_USER:-root} -N $MYSQL_DATABASE"

check() { # label, SQL, minimum
  n=$($M -e "$2")
  if [ "$n" -ge "$3" ]; then echo "ok   $1 ($n)"; else echo "FAIL $1: got $n, want >= $3" >&2; exit 1; fi
}

check "learners"               "SELECT COUNT(*) FROM users u JOIN roles r ON r.id=u.role_id WHERE r.code='LEARNER' AND u.email LIKE 'demo.%'" 25
check "users (admin list)"     "SELECT COUNT(*) FROM users WHERE email LIKE 'demo.%'" 30
check "categories"             "SELECT COUNT(*) FROM categories" 20
check "published courses"      "SELECT COUNT(*) FROM courses WHERE status='published' AND slug LIKE 'demo-course-%'" 20
check "pending courses"        "SELECT COUNT(*) FROM courses WHERE status='pending_review' AND slug LIKE 'demo-course-%'" 5
check "lessons"                "SELECT COUNT(*) FROM lessons" 20
check "quizzes"                "SELECT COUNT(*) FROM quizzes" 20
check "quiz questions"         "SELECT COUNT(*) FROM quiz_questions" 20
check "quiz attempts"          "SELECT COUNT(*) FROM quiz_attempts" 20
check "enrollments"            "SELECT COUNT(*) FROM enrollments" 20
check "lesson progress"        "SELECT COUNT(*) FROM lesson_progress" 20
check "certificates"           "SELECT COUNT(*) FROM certificates" 20
check "reviews"                "SELECT COUNT(*) FROM reviews" 20
check "coupons"                "SELECT COUNT(*) FROM coupons" 20
check "orders"                 "SELECT COUNT(*) FROM orders" 20
check "payments"               "SELECT COUNT(*) FROM payments" 20
check "refunds"                "SELECT COUNT(*) FROM refunds" 20
check "instructor payouts"     "SELECT COUNT(*) FROM creator_payouts" 20
check "notifications"          "SELECT COUNT(*) FROM notifications" 20
check "organization employees" "SELECT COUNT(*) FROM organization_users" 20
check "learning paths"         "SELECT COUNT(*) FROM learning_paths" 20
check "learning path courses"  "SELECT COUNT(*) FROM learning_path_courses" 20
check "job postings"           "SELECT COUNT(*) FROM jobs" 20
check "job applications"       "SELECT COUNT(*) FROM job_applications" 20
check "audit log"              "SELECT COUNT(*) FROM audit_logs" 20

# Integrity: no demo order without a payment, no enrollment without an order.
orphans=$($M -e "SELECT COUNT(*) FROM orders o LEFT JOIN payments p ON p.order_id=o.id WHERE o.order_code LIKE 'DEMO-ORD-%' AND p.id IS NULL")
[ "$orphans" = "0" ] || { echo "FAIL orders without payments: $orphans" >&2; exit 1; }
echo "ok   every demo order has a payment"
echo "seed verified"
