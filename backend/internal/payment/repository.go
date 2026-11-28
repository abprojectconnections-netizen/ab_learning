package payment

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"
)

var (
	ErrValidation          = errors.New("validation failed")
	ErrCourseUnavailable   = errors.New("one or more courses are not available for purchase")
	ErrAlreadyEnrolled     = errors.New("you are already enrolled in one or more of these courses")
	ErrFreeOrder           = errors.New("free courses do not need checkout; enroll directly")
	ErrIdempotencyConflict = errors.New("this Idempotency-Key was already used with a different request")
)

const (
	checkoutEndpoint = "POST /checkout"
	idempotencyTTL   = 24 * time.Hour
)

// CheckoutInput is the validated purchase request.
type CheckoutInput struct {
	CourseIDs []int64 `json:"course_ids"`
	Method    string  `json:"method"`
}

// CheckoutResult is returned to the client (and replayed for the same key).
type CheckoutResult struct {
	OrderID     int64   `json:"order_id"`
	OrderCode   string  `json:"order_code"`
	PaymentID   int64   `json:"payment_id"`
	ProviderRef string  `json:"provider_ref"`
	Amount      float64 `json:"amount"`
	Currency    string  `json:"currency"`
	Status      string  `json:"status"`
	Sandbox     bool    `json:"sandbox"`
}

// Outcome describes what a webhook delivery did.
type Outcome string

const (
	OutcomeProcessed Outcome = "processed"
	OutcomeDuplicate Outcome = "duplicate"
	OutcomeIgnored   Outcome = "ignored"
	OutcomeRejected  Outcome = "rejected"
)

type Repository struct {
	db  *sql.DB
	now func() time.Time
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db, now: func() time.Time { return time.Now().UTC() }}
}

func hashHex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

// requestHash is stable for the same set of courses and method.
func requestHash(in CheckoutInput) string {
	ids := append([]int64(nil), in.CourseIDs...)
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	return hashHex(fmt.Sprint(ids, "|", in.Method))
}

func cents(v float64) int64 { return int64(math.Round(v * 100)) }

func placeholders(n int) string { return strings.TrimSuffix(strings.Repeat("?,", n), ",") }

func newOrderCode() (string, error) {
	b := make([]byte, 6)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return "ORD-" + strings.ToUpper(hex.EncodeToString(b)), nil
}

// Checkout creates a pending order and payment. Prices always come from the
// database. The same (user, Idempotency-Key, request) replays the first
// response instead of creating a second order.
func (r *Repository) Checkout(ctx context.Context, userID int64, key string, in CheckoutInput, providerRef string) (CheckoutResult, bool, error) {
	var zero CheckoutResult
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return zero, false, err
	}
	defer tx.Rollback()

	keyHash, reqHash, now := hashHex(key), requestHash(in), r.now()
	if _, err := tx.ExecContext(ctx, `DELETE FROM idempotency_keys WHERE user_id = ? AND endpoint = ? AND key_hash = ? AND expires_at < ?`,
		userID, checkoutEndpoint, keyHash, now); err != nil {
		return zero, false, err
	}
	res, err := tx.ExecContext(ctx, `INSERT IGNORE INTO idempotency_keys (user_id, endpoint, key_hash, request_hash, expires_at) VALUES (?,?,?,?,?)`,
		userID, checkoutEndpoint, keyHash, reqHash, now.Add(idempotencyTTL))
	if err != nil {
		return zero, false, err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		var storedHash string
		var body []byte
		if err := tx.QueryRowContext(ctx, `SELECT request_hash, response_body FROM idempotency_keys WHERE user_id = ? AND endpoint = ? AND key_hash = ? FOR UPDATE`,
			userID, checkoutEndpoint, keyHash).Scan(&storedHash, &body); err != nil {
			return zero, false, err
		}
		if storedHash != reqHash || len(body) == 0 {
			return zero, false, ErrIdempotencyConflict
		}
		var prev CheckoutResult
		if err := json.Unmarshal(body, &prev); err != nil {
			return zero, false, err
		}
		return prev, true, nil
	}

	args := make([]any, len(in.CourseIDs))
	for i, id := range in.CourseIDs {
		args[i] = id
	}
	rows, err := tx.QueryContext(ctx, `SELECT id, price, COALESCE(discount_price, price) FROM courses WHERE status = 'published' AND id IN (`+placeholders(len(args))+`)`, args...)
	if err != nil {
		return zero, false, err
	}
	type line struct {
		id               int64
		price, effective int64
	}
	var lines []line
	for rows.Next() {
		var id int64
		var price, eff float64
		if err := rows.Scan(&id, &price, &eff); err != nil {
			rows.Close()
			return zero, false, err
		}
		lines = append(lines, line{id, cents(price), cents(eff)})
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return zero, false, err
	}
	rows.Close()
	if len(lines) != len(in.CourseIDs) {
		return zero, false, ErrCourseUnavailable
	}

	var owned int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM enrollments WHERE user_id = ? AND course_id IN (`+placeholders(len(args))+`)`,
		append([]any{userID}, args...)...).Scan(&owned); err != nil {
		return zero, false, err
	}
	if owned > 0 {
		return zero, false, ErrAlreadyEnrolled
	}

	var subtotal, total int64
	for _, l := range lines {
		subtotal += l.price
		total += l.effective
	}
	if total <= 0 {
		return zero, false, ErrFreeOrder
	}

	code, err := newOrderCode()
	if err != nil {
		return zero, false, err
	}
	orderRes, err := tx.ExecContext(ctx, `INSERT INTO orders (order_code, user_id, subtotal, discount_total, grand_total, status) VALUES (?,?,?,?,?,'pending')`,
		code, userID, float64(subtotal)/100, float64(subtotal-total)/100, float64(total)/100)
	if err != nil {
		return zero, false, err
	}
	orderID, err := orderRes.LastInsertId()
	if err != nil {
		return zero, false, err
	}
	for _, l := range lines {
		if _, err := tx.ExecContext(ctx, `INSERT INTO order_items (order_id, course_id, price) VALUES (?,?,?)`, orderID, l.id, float64(l.effective)/100); err != nil {
			return zero, false, err
		}
	}
	payRes, err := tx.ExecContext(ctx, `INSERT INTO payments (order_id, method, provider_ref, amount, status) VALUES (?,?,?,?,'pending')`,
		orderID, in.Method, providerRef, float64(total)/100)
	if err != nil {
		return zero, false, err
	}
	paymentID, err := payRes.LastInsertId()
	if err != nil {
		return zero, false, err
	}

	out := CheckoutResult{OrderID: orderID, OrderCode: code, PaymentID: paymentID, ProviderRef: providerRef,
		Amount: float64(total) / 100, Currency: Currency, Status: "pending", Sandbox: true}
	body, err := json.Marshal(out)
	if err != nil {
		return zero, false, err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE idempotency_keys SET response_status = 201, response_body = ? WHERE user_id = ? AND endpoint = ? AND key_hash = ?`,
		body, userID, checkoutEndpoint, keyHash); err != nil {
		return zero, false, err
	}
	if err := tx.Commit(); err != nil {
		return zero, false, err
	}
	return out, false, nil
}

// ApplyEvent records a verified webhook event exactly once and applies it.
// A duplicate delivery (same provider + event id) changes nothing.
func (r *Repository) ApplyEvent(ctx context.Context, provider string, ev Event, raw []byte) (Outcome, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()

	res, err := tx.ExecContext(ctx, `INSERT IGNORE INTO payment_events (provider, event_id, event_type, livemode, signature_valid, payload) VALUES (?,?,?,0,1,?)`,
		provider, ev.ID, ev.Type, raw)
	if err != nil {
		return "", err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return OutcomeDuplicate, nil
	}
	eventRowID, err := res.LastInsertId()
	if err != nil {
		return "", err
	}

	finish := func(outcome Outcome, paymentID sql.NullInt64, note string) (Outcome, error) {
		var errText sql.NullString
		if note != "" {
			errText = sql.NullString{String: note, Valid: true}
		}
		if _, err := tx.ExecContext(ctx, `UPDATE payment_events SET payment_id = ?, processed_at = ?, error = ? WHERE id = ?`,
			paymentID, r.now(), errText, eventRowID); err != nil {
			return "", err
		}
		if err := tx.Commit(); err != nil {
			return "", err
		}
		return outcome, nil
	}

	var paymentID, orderID int64
	var amount float64
	var status string
	err = tx.QueryRowContext(ctx, `SELECT id, order_id, amount, status FROM payments WHERE provider_ref = ? FOR UPDATE`, ev.Data.Reference).
		Scan(&paymentID, &orderID, &amount, &status)
	if errors.Is(err, sql.ErrNoRows) {
		return finish(OutcomeIgnored, sql.NullInt64{}, "unknown payment reference")
	}
	if err != nil {
		return "", err
	}
	pid := sql.NullInt64{Int64: paymentID, Valid: true}

	switch ev.Type {
	case "payment.succeeded":
		if status != "pending" {
			return finish(OutcomeIgnored, pid, "payment is not pending (status: "+status+")")
		}
		if ev.Data.Amount != cents(amount) || ev.Data.Currency != Currency {
			return finish(OutcomeRejected, pid, "amount or currency does not match the payment")
		}
		if _, err := tx.ExecContext(ctx, `UPDATE payments SET status = 'success', paid_at = ? WHERE id = ?`, r.now(), paymentID); err != nil {
			return "", err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE orders SET status = 'paid' WHERE id = ?`, orderID); err != nil {
			return "", err
		}
		if _, err := tx.ExecContext(ctx, `INSERT IGNORE INTO enrollments (user_id, course_id, progress_pct, status)
			SELECT o.user_id, oi.course_id, 0, 'in_progress' FROM order_items oi JOIN orders o ON o.id = oi.order_id WHERE oi.order_id = ?`, orderID); err != nil {
			return "", err
		}
		return finish(OutcomeProcessed, pid, "")
	case "payment.failed":
		if status != "pending" {
			return finish(OutcomeIgnored, pid, "payment is not pending (status: "+status+")")
		}
		if _, err := tx.ExecContext(ctx, `UPDATE payments SET status = 'failed' WHERE id = ?`, paymentID); err != nil {
			return "", err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE orders SET status = 'failed' WHERE id = ?`, orderID); err != nil {
			return "", err
		}
		return finish(OutcomeProcessed, pid, "")
	default:
		return finish(OutcomeIgnored, pid, "unsupported event type")
	}
}
