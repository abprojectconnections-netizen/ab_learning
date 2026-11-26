package admin

import (
	"errors"
	"strings"
	"testing"

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
