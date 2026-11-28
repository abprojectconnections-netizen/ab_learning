package admin

import (
	"database/sql"
	"time"
)

// Issue types reported by the payment reconciliation.
const (
	IssuePaidOrderNoPayment    = "paid_order_without_successful_payment"
	IssueSuccessOrderNotPaid   = "successful_payment_order_not_paid"
	IssueAmountMismatch        = "payment_amount_differs_from_order_total"
	IssueRefundExceedsPayment  = "refunds_exceed_payment_amount"
	IssueStalePending          = "pending_payment_older_than_1h"
	IssueWebhookEventError     = "webhook_event_with_error"
	reconciliationMaxIssues    = 500
	stalePendingAfter          = time.Hour
	reconciliationAmountMargin = 0.005
)

// ReconciliationIssue is one discrepancy between orders, payments, refunds and webhook events.
type ReconciliationIssue struct {
	Type      string `json:"type"`
	OrderCode string `json:"order_code"`
	PaymentID *int64 `json:"payment_id"`
	Detail    string `json:"detail"`
}

// Reconciliation is read-only: it reports problems and never changes data.
type Reconciliation struct {
	GeneratedAt time.Time             `json:"generated_at"`
	Total       int                   `json:"total"`
	ByType      map[string]int        `json:"by_type"`
	Issues      []ReconciliationIssue `json:"issues"`
	Truncated   bool                  `json:"truncated"`
}

const reconciliationQuery = `
SELECT 'paid_order_without_successful_payment' AS issue, CAST(NULL AS UNSIGNED) AS payment_id, o.order_code AS order_code,
       'order is paid but has no successful payment' AS detail
  FROM orders o LEFT JOIN payments p ON p.order_id = o.id AND p.status = 'success'
 WHERE o.status = 'paid' AND p.id IS NULL
UNION ALL
SELECT 'successful_payment_order_not_paid', p.id, o.order_code, 'payment succeeded but the order is neither paid nor refunded'
  FROM payments p JOIN orders o ON o.id = p.order_id
 WHERE p.status = 'success' AND o.status NOT IN ('paid','refunded')
UNION ALL
SELECT 'payment_amount_differs_from_order_total', p.id, o.order_code, 'payment amount does not equal the order grand total'
  FROM payments p JOIN orders o ON o.id = p.order_id
 WHERE p.status = 'success' AND ABS(p.amount - o.grand_total) > ?
UNION ALL
SELECT 'refunds_exceed_payment_amount', p.id, o.order_code, 'processed refunds are larger than the payment'
  FROM payments p JOIN orders o ON o.id = p.order_id
 WHERE (SELECT COALESCE(SUM(r.amount),0) FROM refunds r WHERE r.payment_id = p.id AND r.status = 'processed') > p.amount + ?
UNION ALL
SELECT 'pending_payment_older_than_1h', p.id, o.order_code, 'payment has been pending for more than an hour'
  FROM payments p JOIN orders o ON o.id = p.order_id
 WHERE p.status = 'pending' AND o.created_at < ?
UNION ALL
SELECT 'webhook_event_with_error', e.payment_id, COALESCE(o.order_code, ''), e.error
  FROM payment_events e LEFT JOIN payments p ON p.id = e.payment_id LEFT JOIN orders o ON o.id = p.order_id
 WHERE e.error IS NOT NULL
ORDER BY 1, 3
LIMIT 501` // one more than reconciliationMaxIssues, to detect truncation

// Reconcile finds payment inconsistencies. now is injected for testing.
func (r *Repository) Reconcile(now time.Time) (Reconciliation, error) {
	out := Reconciliation{GeneratedAt: now.UTC(), ByType: map[string]int{}, Issues: []ReconciliationIssue{}}
	rows, err := r.db.Query(reconciliationQuery, reconciliationAmountMargin, reconciliationAmountMargin, now.UTC().Add(-stalePendingAfter))
	if err != nil {
		return out, err
	}
	defer rows.Close()
	for rows.Next() {
		var it ReconciliationIssue
		var pid sql.NullInt64
		var code, detail sql.NullString
		if err := rows.Scan(&it.Type, &pid, &code, &detail); err != nil {
			return out, err
		}
		if pid.Valid {
			v := pid.Int64
			it.PaymentID = &v
		}
		it.OrderCode, it.Detail = code.String, detail.String
		if len(out.Issues) == reconciliationMaxIssues {
			out.Truncated = true
			break
		}
		out.Issues = append(out.Issues, it)
		out.ByType[it.Type]++
	}
	out.Total = len(out.Issues)
	return out, rows.Err()
}

// Reconciliation reports payment discrepancies for the admin console.
func (s *Service) Reconciliation() (Reconciliation, error) { return s.repo.Reconcile(time.Now()) }
