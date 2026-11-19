package instructor

import (
	"errors"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestInstructorIDRejectsUnverifiedAccountWithoutCreatingRow(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	mock.ExpectQuery("SELECT id FROM instructors").
		WithArgs(int64(42)).
		WillReturnRows(sqlmock.NewRows([]string{"id"}))

	_, err = NewRepository(db).InstructorID(42)
	if !errors.Is(err, ErrInstructorPending) {
		t.Fatalf("InstructorID error = %v, want ErrInstructorPending", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
