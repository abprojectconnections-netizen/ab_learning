package payment

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func newRepo(t *testing.T) (*Repository, sqlmock.Sqlmock) {
	t.Helper()
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	r := NewRepository(db)
	r.now = func() time.Time { return t0 }
	return r, mock
}

func evt(typ string, amount int64) Event {
	return Event{ID: "evt_1", Type: typ, Data: EventData{Reference: "sbx_abc", Amount: amount, Currency: "THB"}}
}

func expectEventInsert(mock sqlmock.Sqlmock, affected int64) {
	mock.ExpectBegin()
	mock.ExpectExec("INSERT IGNORE INTO payment_events").
		WithArgs("sandbox", "evt_1", sqlmock.AnyArg(), sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(5, affected))
}

func expectPayment(mock sqlmock.Sqlmock, status string) {
	mock.ExpectQuery("SELECT id, order_id, amount, status FROM payments").WithArgs("sbx_abc").
		WillReturnRows(sqlmock.NewRows([]string{"id", "order_id", "amount", "status"}).AddRow(int64(3), int64(4), 100.5, status))
}

func expectEventDone(mock sqlmock.Sqlmock) {
	mock.ExpectExec("UPDATE payment_events SET payment_id").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), int64(5)).
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
}

func TestApplyEventSucceededFulfilsOrderAndEnrolls(t *testing.T) {
	r, mock := newRepo(t)
	expectEventInsert(mock, 1)
	expectPayment(mock, "pending")
	mock.ExpectExec("UPDATE payments SET status = 'success'").WithArgs(sqlmock.AnyArg(), int64(3)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("UPDATE orders SET status = 'paid'").WithArgs(int64(4)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT IGNORE INTO enrollments").WithArgs(int64(4)).WillReturnResult(sqlmock.NewResult(0, 2))
	expectEventDone(mock)

	out, err := r.ApplyEvent(context.Background(), "sandbox", evt("payment.succeeded", 10050), []byte(`{}`))
	if err != nil || out != OutcomeProcessed {
		t.Fatalf("ApplyEvent = %q, %v", out, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestApplyEventDuplicateDeliveryChangesNothing(t *testing.T) {
	r, mock := newRepo(t)
	expectEventInsert(mock, 0) // unique (provider, event_id) already present
	mock.ExpectRollback()
	out, err := r.ApplyEvent(context.Background(), "sandbox", evt("payment.succeeded", 10050), []byte(`{}`))
	if err != nil || out != OutcomeDuplicate {
		t.Fatalf("ApplyEvent = %q, %v", out, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestApplyEventAmountMismatchIsRejectedAndNotFulfilled(t *testing.T) {
	for name, ev := range map[string]Event{
		"wrong amount":   evt("payment.succeeded", 1),
		"wrong currency": {ID: "evt_1", Type: "payment.succeeded", Data: EventData{Reference: "sbx_abc", Amount: 10050, Currency: "USD"}},
	} {
		r, mock := newRepo(t)
		expectEventInsert(mock, 1)
		expectPayment(mock, "pending")
		expectEventDone(mock) // only the audit row is written; no payment/order/enrollment updates
		out, err := r.ApplyEvent(context.Background(), "sandbox", ev, []byte(`{}`))
		if err != nil || out != OutcomeRejected {
			t.Errorf("%s: ApplyEvent = %q, %v", name, out, err)
		}
		if err := mock.ExpectationsWereMet(); err != nil {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestApplyEventOnlyPendingPaymentsTransition(t *testing.T) {
	for _, st := range []string{"success", "failed"} {
		r, mock := newRepo(t)
		expectEventInsert(mock, 1)
		expectPayment(mock, st)
		expectEventDone(mock)
		out, err := r.ApplyEvent(context.Background(), "sandbox", evt("payment.succeeded", 10050), []byte(`{}`))
		if err != nil || out != OutcomeIgnored {
			t.Errorf("status %s: ApplyEvent = %q, %v", st, out, err)
		}
		if err := mock.ExpectationsWereMet(); err != nil {
			t.Errorf("status %s: %v", st, err)
		}
	}
}

func TestApplyEventUnknownReferenceIsIgnored(t *testing.T) {
	r, mock := newRepo(t)
	expectEventInsert(mock, 1)
	mock.ExpectQuery("SELECT id, order_id, amount, status FROM payments").WithArgs("sbx_abc").
		WillReturnRows(sqlmock.NewRows([]string{"id", "order_id", "amount", "status"}))
	expectEventDone(mock)
	out, err := r.ApplyEvent(context.Background(), "sandbox", evt("payment.succeeded", 10050), []byte(`{}`))
	if err != nil || out != OutcomeIgnored {
		t.Fatalf("ApplyEvent = %q, %v", out, err)
	}
}

func TestApplyEventFailedMarksPaymentAndOrderFailed(t *testing.T) {
	r, mock := newRepo(t)
	expectEventInsert(mock, 1)
	expectPayment(mock, "pending")
	mock.ExpectExec("UPDATE payments SET status = 'failed'").WithArgs(int64(3)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("UPDATE orders SET status = 'failed'").WithArgs(int64(4)).WillReturnResult(sqlmock.NewResult(0, 1))
	expectEventDone(mock)
	out, err := r.ApplyEvent(context.Background(), "sandbox", evt("payment.failed", 0), []byte(`{}`))
	if err != nil || out != OutcomeProcessed {
		t.Fatalf("ApplyEvent = %q, %v", out, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestApplyEventUnsupportedTypeIsIgnored(t *testing.T) {
	r, mock := newRepo(t)
	expectEventInsert(mock, 1)
	expectPayment(mock, "pending")
	expectEventDone(mock)
	out, err := r.ApplyEvent(context.Background(), "sandbox", evt("charge.dispute.created", 0), []byte(`{}`))
	if err != nil || out != OutcomeIgnored {
		t.Fatalf("ApplyEvent = %q, %v", out, err)
	}
}

func TestApplyEventDatabaseErrorRollsBack(t *testing.T) {
	r, mock := newRepo(t)
	expectEventInsert(mock, 1)
	expectPayment(mock, "pending")
	boom := errors.New("deadlock")
	mock.ExpectExec("UPDATE payments SET status = 'success'").WillReturnError(boom)
	mock.ExpectRollback()
	if _, err := r.ApplyEvent(context.Background(), "sandbox", evt("payment.succeeded", 10050), []byte(`{}`)); !errors.Is(err, boom) {
		t.Fatalf("got %v, want the database error (so the provider retries)", err)
	}
}

// ---- checkout ----------------------------------------------------------

const (
	idemKey = "idem-key-123"
	endpt   = "POST /checkout"
)

func expectIdempotencyInsert(mock sqlmock.Sqlmock, in CheckoutInput, affected int64) {
	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM idempotency_keys").WithArgs(int64(1), endpt, hashHex(idemKey), sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(0, 0))
	mock.ExpectExec("INSERT IGNORE INTO idempotency_keys").
		WithArgs(int64(1), endpt, hashHex(idemKey), requestHash(in), sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(1, affected))
}

func courseRows(prices ...[3]float64) *sqlmock.Rows {
	rows := sqlmock.NewRows([]string{"id", "price", "eff"})
	for _, p := range prices {
		rows.AddRow(int64(p[0]), p[1], p[2])
	}
	return rows
}

var two = CheckoutInput{CourseIDs: []int64{10, 11}, Method: "card"}

func TestCheckoutCreatesPendingOrderAtServerSidePrices(t *testing.T) {
	r, mock := newRepo(t)
	expectIdempotencyInsert(mock, two, 1)
	mock.ExpectQuery("FROM courses WHERE status = 'published'").WithArgs(int64(10), int64(11)).
		WillReturnRows(courseRows([3]float64{10, 500, 400}, [3]float64{11, 300, 300}))
	mock.ExpectQuery("SELECT COUNT").WithArgs(int64(1), int64(10), int64(11)).
		WillReturnRows(sqlmock.NewRows([]string{"n"}).AddRow(0))
	// subtotal 800.00, discount 100.00, total 700.00 (baht) — computed from the database, not the request.
	mock.ExpectExec("INSERT INTO orders").WithArgs(sqlmock.AnyArg(), int64(1), 800.0, 100.0, 700.0).WillReturnResult(sqlmock.NewResult(50, 1))
	mock.ExpectExec("INSERT INTO order_items").WithArgs(int64(50), int64(10), 400.0).WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectExec("INSERT INTO order_items").WithArgs(int64(50), int64(11), 300.0).WillReturnResult(sqlmock.NewResult(2, 1))
	mock.ExpectExec("INSERT INTO payments").WithArgs(int64(50), "card", "sbx_ref", 700.0).WillReturnResult(sqlmock.NewResult(60, 1))
	mock.ExpectExec("UPDATE idempotency_keys SET response_status").WithArgs(sqlmock.AnyArg(), int64(1), endpt, hashHex(idemKey)).
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()

	out, replayed, err := r.Checkout(context.Background(), 1, idemKey, two, "sbx_ref")
	if err != nil || replayed {
		t.Fatalf("Checkout = %+v, replayed=%v, %v", out, replayed, err)
	}
	if out.OrderID != 50 || out.PaymentID != 60 || out.Amount != 700.0 || out.Status != "pending" || !out.Sandbox || out.Currency != "THB" {
		t.Fatalf("unexpected result: %+v", out)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestCheckoutReplaysStoredResponseForSameKeyAndRequest(t *testing.T) {
	r, mock := newRepo(t)
	expectIdempotencyInsert(mock, two, 0)
	first, _ := json.Marshal(CheckoutResult{OrderID: 50, PaymentID: 60, Amount: 7, Status: "pending"})
	mock.ExpectQuery("SELECT request_hash, response_body FROM idempotency_keys").WithArgs(int64(1), endpt, hashHex(idemKey)).
		WillReturnRows(sqlmock.NewRows([]string{"request_hash", "response_body"}).AddRow(requestHash(two), first))
	mock.ExpectRollback() // nothing is written on a replay

	out, replayed, err := r.Checkout(context.Background(), 1, idemKey, two, "sbx_other")
	if err != nil || !replayed || out.OrderID != 50 || out.PaymentID != 60 {
		t.Fatalf("Checkout = %+v, replayed=%v, %v", out, replayed, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestCheckoutSameKeyDifferentRequestConflicts(t *testing.T) {
	r, mock := newRepo(t)
	expectIdempotencyInsert(mock, two, 0)
	mock.ExpectQuery("SELECT request_hash, response_body FROM idempotency_keys").
		WillReturnRows(sqlmock.NewRows([]string{"request_hash", "response_body"}).AddRow("some-other-hash", []byte(`{}`)))
	mock.ExpectRollback()
	if _, _, err := r.Checkout(context.Background(), 1, idemKey, two, "sbx_ref"); !errors.Is(err, ErrIdempotencyConflict) {
		t.Fatalf("got %v, want ErrIdempotencyConflict", err)
	}
}

func TestCheckoutRejectsUnavailableOwnedAndFreeCourses(t *testing.T) {
	t.Run("unpublished or unknown course", func(t *testing.T) {
		r, mock := newRepo(t)
		expectIdempotencyInsert(mock, two, 1)
		mock.ExpectQuery("FROM courses WHERE status = 'published'").WillReturnRows(courseRows([3]float64{10, 500, 500}))
		mock.ExpectRollback()
		if _, _, err := r.Checkout(context.Background(), 1, idemKey, two, "sbx_ref"); !errors.Is(err, ErrCourseUnavailable) {
			t.Fatalf("got %v", err)
		}
	})
	t.Run("already enrolled", func(t *testing.T) {
		r, mock := newRepo(t)
		expectIdempotencyInsert(mock, two, 1)
		mock.ExpectQuery("FROM courses WHERE status = 'published'").
			WillReturnRows(courseRows([3]float64{10, 500, 500}, [3]float64{11, 300, 300}))
		mock.ExpectQuery("SELECT COUNT").WillReturnRows(sqlmock.NewRows([]string{"n"}).AddRow(1))
		mock.ExpectRollback()
		if _, _, err := r.Checkout(context.Background(), 1, idemKey, two, "sbx_ref"); !errors.Is(err, ErrAlreadyEnrolled) {
			t.Fatalf("got %v", err)
		}
	})
	t.Run("free order", func(t *testing.T) {
		r, mock := newRepo(t)
		expectIdempotencyInsert(mock, two, 1)
		mock.ExpectQuery("FROM courses WHERE status = 'published'").
			WillReturnRows(courseRows([3]float64{10, 0, 0}, [3]float64{11, 0, 0}))
		mock.ExpectQuery("SELECT COUNT").WillReturnRows(sqlmock.NewRows([]string{"n"}).AddRow(0))
		mock.ExpectRollback()
		if _, _, err := r.Checkout(context.Background(), 1, idemKey, two, "sbx_ref"); !errors.Is(err, ErrFreeOrder) {
			t.Fatalf("got %v", err)
		}
	})
}
