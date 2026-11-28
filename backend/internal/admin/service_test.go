package admin

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func sp(s string) *string   { return &s }
func fp(f float64) *float64 { return &f }

// Every case here must be rejected before any database access (repo is nil).
func TestServiceValidationRejectsBadInput(t *testing.T) {
	s := &Service{}
	cases := map[string]func() error{
		"moderation status": func() error { _, e := s.Moderation("deleted"); return e },
		"reject no reason":  func() error { return s.Reject(1, 2, "  ") },
		"reject too short":  func() error { return s.Reject(1, 2, "ab") },
		"reject too long":   func() error { return s.Reject(1, 2, strings.Repeat("x", 501)) },
		"users status":      func() error { _, e := s.ListUsers(UserFilter{Status: "banned"}); return e },
		"update nothing":    func() error { _, e := s.UpdateUser(1, 2, UserUpdate{}); return e },
		"update bad status": func() error { _, e := s.UpdateUser(1, 2, UserUpdate{Status: sp("gone")}); return e },
		"payments status":   func() error { _, e := s.ListPayments("refunded"); return e },
		"refund no reason":  func() error { _, e := s.Refund(1, 2, RefundRequest{Reason: " "}); return e },
		"refund zero":       func() error { _, e := s.Refund(1, 2, RefundRequest{Reason: "duplicate", Amount: fp(0)}); return e },
		"refund negative":   func() error { _, e := s.Refund(1, 2, RefundRequest{Reason: "duplicate", Amount: fp(-5)}); return e },
		"approve instr id":  func() error { return s.ApproveInstructor(0, 2) },
	}
	for name, fn := range cases {
		if err := fn(); !errors.Is(err, ErrValidation) {
			t.Errorf("%s: got %v, want ErrValidation", name, err)
		}
	}
}

func TestServiceForbidsActingOnOwnAccount(t *testing.T) {
	s := &Service{}
	if _, err := s.UpdateUser(5, 5, UserUpdate{Role: sp("LEARNER")}); !errors.Is(err, ErrSelf) {
		t.Fatalf("UpdateUser self = %v", err)
	}
	if _, err := s.Suspend(5, 5, "x"); !errors.Is(err, ErrSelf) {
		t.Fatalf("Suspend self = %v", err)
	}
}

func TestUpdateUserRejectsUnknownRole(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("SELECT COUNT\\(\\*\\) FROM roles").WithArgs("HACKER").
		WillReturnRows(sqlmock.NewRows([]string{"n"}).AddRow(0))
	s := NewService(NewRepository(db))
	if _, err := s.UpdateUser(1, 2, UserUpdate{Role: sp("HACKER")}); !errors.Is(err, ErrValidation) {
		t.Fatalf("UpdateUser unknown role = %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestModerationDefaultsToPendingReview(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("WHERE c.status = \\?").WithArgs("pending_review").
		WillReturnRows(sqlmock.NewRows([]string{"id"}))
	out, err := NewService(NewRepository(db)).Moderation("")
	if err != nil || out == nil {
		t.Fatalf("Moderation default = %v, %v", out, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestReconcileMapsIssuesAndCounts(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("UNION ALL").WithArgs(0.005, 0.005, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"issue", "payment_id", "order_code", "detail"}).
			AddRow(IssuePaidOrderNoPayment, nil, "ORD-1", "no payment").
			AddRow(IssueStalePending, int64(7), "ORD-2", "old").
			AddRow(IssueStalePending, int64(8), "ORD-3", "old").
			AddRow(IssueWebhookEventError, nil, nil, nil))
	out, err := NewRepository(db).Reconcile(time.Now())
	if err != nil {
		t.Fatalf("Reconcile: %v", err)
	}
	if out.Total != 4 || out.ByType[IssueStalePending] != 2 || out.ByType[IssuePaidOrderNoPayment] != 1 || out.Truncated {
		t.Fatalf("unexpected report: %+v", out)
	}
	if out.Issues[0].PaymentID != nil || out.Issues[1].PaymentID == nil || *out.Issues[1].PaymentID != 7 {
		t.Fatalf("payment ids mapped wrongly: %+v", out.Issues)
	}
	if out.Issues[3].OrderCode != "" || out.Issues[3].Detail != "" {
		t.Fatalf("NULL columns must map to empty strings: %+v", out.Issues[3])
	}
}

func TestReconcileReportsTruncation(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	rows := sqlmock.NewRows([]string{"issue", "payment_id", "order_code", "detail"})
	for i := 0; i <= reconciliationMaxIssues; i++ {
		rows.AddRow(IssueStalePending, int64(i+1), "ORD", "old")
	}
	mock.ExpectQuery("UNION ALL").WillReturnRows(rows)
	out, err := NewRepository(db).Reconcile(time.Now())
	if err != nil || !out.Truncated || out.Total != reconciliationMaxIssues {
		t.Fatalf("Reconcile = total %d truncated %v err %v", out.Total, out.Truncated, err)
	}
}
