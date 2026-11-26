package admin

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestListAuditRejectsOversizedAction(t *testing.T) {
	s := &Service{}
	if _, err := s.ListAudit(AuditFilter{Action: strings.Repeat("a", 101)}); !errors.Is(err, ErrValidation) {
		t.Fatalf("ListAudit = %v, want ErrValidation", err)
	}
}

func TestListAuditFiltersAndMapsRows(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	repo := &Repository{db: db}
	mock.ExpectQuery("a.action = \\? AND a.actor_id = \\? ORDER BY a.id DESC").
		WithArgs("course.approve", 1, 50, 0).
		WillReturnRows(sqlmock.NewRows([]string{"id", "actor", "email", "action", "ttype", "tid", "meta", "created"}).
			AddRow(int64(2), int64(1), "admin@x.test", "course.approve", "course", int64(3), []byte(`{"n":1}`), time.Now()).
			AddRow(int64(1), nil, "", "system.start", "", nil, nil, time.Now()))
	out, err := repo.ListAudit(AuditFilter{Action: "course.approve", ActorID: 1, Limit: 50})
	if err != nil {
		t.Fatalf("ListAudit: %v", err)
	}
	if len(out) != 2 || out[0].ActorEmail != "admin@x.test" || string(out[0].Metadata) != `{"n":1}` {
		t.Fatalf("unexpected rows: %+v", out)
	}
	if out[1].ActorID != nil || out[1].TargetID != nil || string(out[1].Metadata) != "null" {
		t.Fatalf("NULL columns must map to nil/null: %+v", out[1])
	}
}
