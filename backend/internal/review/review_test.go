package review

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestInputValidate(t *testing.T) {
	for _, in := range []Input{{Rating: 0}, {Rating: 6}, {Rating: 3, Comment: strings.Repeat("ก", 2001)}} {
		in := in
		if err := in.Validate(); !errors.Is(err, ErrValidation) {
			t.Fatalf("Validate(%d, %d chars) = %v, want ErrValidation", in.Rating, len(in.Comment), err)
		}
	}
	ok := Input{Rating: 5, Comment: "  great  "}
	if err := ok.Validate(); err != nil || ok.Comment != "great" {
		t.Fatalf("Validate ok input: %v, comment=%q", err, ok.Comment)
	}
}

func TestUpsertRequiresEnrollment(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT COUNT\\(\\*\\) FROM enrollments").WithArgs(int64(7), int64(3)).
		WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(0))
	mock.ExpectRollback()
	if err := NewRepository(db).Upsert(3, 7, Input{Rating: 5}); !errors.Is(err, ErrNotEnrolled) {
		t.Fatalf("Upsert = %v, want ErrNotEnrolled", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestUpsertSavesAndRefreshesCourseStats(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT COUNT\\(\\*\\) FROM enrollments").WithArgs(int64(7), int64(3)).
		WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(1))
	mock.ExpectExec("INSERT INTO reviews .* ON DUPLICATE KEY UPDATE").
		WithArgs(int64(3), int64(7), 4, "good").WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectExec("UPDATE courses SET rating_avg").
		WithArgs(int64(3), int64(3), int64(3)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
	if err := NewRepository(db).Upsert(3, 7, Input{Rating: 4, Comment: "good"}); err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestListRejectsUnpublishedCourse(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("SELECT COUNT\\(\\*\\) FROM courses WHERE id = \\? AND status = 'published'").
		WithArgs(int64(3)).WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(0))
	if _, err := NewRepository(db).List(3, 20, 0); !errors.Is(err, ErrNotFound) {
		t.Fatalf("List = %v, want ErrNotFound", err)
	}
}

func TestListReturnsSummaryAndReviews(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("FROM courses WHERE id").WithArgs(int64(3)).WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(1))
	mock.ExpectQuery("SELECT COALESCE\\(AVG").WithArgs(int64(3)).
		WillReturnRows(sqlmock.NewRows([]string{"avg", "n"}).AddRow(4.5, 2))
	mock.ExpectQuery("SELECT r.id, r.rating").WithArgs(int64(3), 20, 0).
		WillReturnRows(sqlmock.NewRows([]string{"id", "rating", "comment", "name", "created_at"}).
			AddRow(int64(2), 5, "great", "Anan S", time.Now()).AddRow(int64(1), 4, "", "Mali K", time.Now()))
	out, err := NewRepository(db).List(3, 20, 0)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if out.RatingAvg != 4.5 || out.RatingCount != 2 || len(out.Items) != 2 || out.Items[0].ReviewerName != "Anan S" {
		t.Fatalf("unexpected listing: %+v", out)
	}
}

func TestModerateDeletesAndAudits(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT course_id FROM reviews WHERE id = \\? FOR UPDATE").WithArgs(int64(9)).
		WillReturnRows(sqlmock.NewRows([]string{"course_id"}).AddRow(int64(3)))
	mock.ExpectExec("DELETE FROM reviews WHERE id").WithArgs(int64(9)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("UPDATE courses SET rating_avg").WithArgs(int64(3), int64(3), int64(3)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT INTO audit_logs").WithArgs(int64(1), int64(9), int64(3)).WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()
	if err := NewRepository(db).Moderate(9, 1); err != nil {
		t.Fatalf("Moderate: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestDeleteOwnMissingReview(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM reviews WHERE course_id").WithArgs(int64(3), int64(7)).WillReturnResult(sqlmock.NewResult(0, 0))
	mock.ExpectRollback()
	if err := NewRepository(db).DeleteOwn(3, 7); !errors.Is(err, ErrNotFound) {
		t.Fatalf("DeleteOwn = %v, want ErrNotFound", err)
	}
}
