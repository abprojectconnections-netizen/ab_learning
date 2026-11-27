package employer

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"

	"github.com/ablearning/api/internal/platform"
)

const employerLookup = "SELECT id, company_name FROM employers"

func newSvc(t *testing.T) (*Service, sqlmock.Sqlmock) {
	t.Helper()
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return NewService(NewRepository(db)), mock
}

func appErr(t *testing.T, err error) *platform.AppError {
	t.Helper()
	var ae *platform.AppError
	if !errors.As(err, &ae) {
		t.Fatalf("want *AppError, got %T %v", err, err)
	}
	return ae
}

func TestUnlinkedAccountIsNotFound(t *testing.T) {
	ctx := context.Background()
	calls := map[string]func(*Service) error{
		"dashboard":    func(s *Service) error { _, e := s.Dashboard(ctx, 1); return e },
		"jobs":         func(s *Service) error { _, e := s.Jobs(ctx, 1); return e },
		"applications": func(s *Service) error { _, e := s.Applications(ctx, 1); return e },
		"create job":   func(s *Service) error { _, e := s.CreateJob(ctx, 1, CreateJobInput{Title: "Backend dev"}); return e },
	}
	for name, call := range calls {
		s, mock := newSvc(t)
		mock.ExpectQuery(employerLookup).WithArgs(int64(1)).WillReturnError(sql.ErrNoRows)
		if ae := appErr(t, call(s)); ae.Status != 404 {
			t.Errorf("%s: status %d, want 404", name, ae.Status)
		}
	}
}

func TestDatabaseFailureBecomesInternalError(t *testing.T) {
	s, mock := newSvc(t)
	mock.ExpectQuery(employerLookup).WillReturnError(errors.New("connection refused"))
	ae := appErr(t, func() error { _, e := s.Dashboard(context.Background(), 1); return e }())
	if ae.Status != 500 || strings.Contains(ae.Message, "connection refused") {
		t.Fatalf("internal errors must not leak details: %+v", ae)
	}
}

func TestTopApplicantsUnlinkedReturnsEmptyList(t *testing.T) {
	s, mock := newSvc(t)
	mock.ExpectQuery(employerLookup).WillReturnError(sql.ErrNoRows)
	list, err := s.TopApplicants(context.Background(), 1)
	if err != nil || list == nil || len(list) != 0 {
		t.Fatalf("TopApplicants = %#v, %v; want empty non-nil list", list, err)
	}
}

func TestCreateJobValidation(t *testing.T) {
	s := NewService(nil) // must fail before touching the repository
	for name, in := range map[string]CreateJobInput{
		"short title":   {Title: " ab "},
		"long title":    {Title: strings.Repeat("t", 201)},
		"long location": {Title: "Valid title", Location: strings.Repeat("l", 151)},
		"long desc":     {Title: "Valid title", Description: strings.Repeat("d", 20001)},
	} {
		if ae := appErr(t, func() error { _, e := s.CreateJob(context.Background(), 1, in); return e }()); ae.Status != 400 {
			t.Errorf("%s: status %d, want 400", name, ae.Status)
		}
	}
}

func TestUpdateApplicationRejectsUnknownStatus(t *testing.T) {
	s := NewService(nil)
	for _, st := range []string{"", "pending", "HIRED", "deleted"} {
		if ae := appErr(t, s.UpdateApplication(context.Background(), 1, 2, st)); ae.Status != 400 {
			t.Errorf("status %q: got %d, want 400", st, ae.Status)
		}
	}
}

func TestUpdateApplicationNotFound(t *testing.T) {
	s, mock := newSvc(t)
	mock.ExpectQuery(employerLookup).WillReturnError(sql.ErrNoRows)
	if ae := appErr(t, s.UpdateApplication(context.Background(), 1, 2, "hired")); ae.Status != 404 {
		t.Fatalf("status %d, want 404", ae.Status)
	}
}
