package notification

import (
	"errors"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestListReturnsItemsAndUnreadCount(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	repo := NewRepository(db)
	mock.ExpectQuery("SELECT id, type, title").WithArgs(int64(7), 30, 0).
		WillReturnRows(sqlmock.NewRows([]string{"id", "type", "title", "body", "is_read", "created_at"}).
			AddRow(int64(2), "order_paid", "Paid", "", false, time.Now()).
			AddRow(int64(1), "welcome", "Hi", "Hello", true, time.Now()))
	mock.ExpectQuery("SELECT COUNT").WithArgs(int64(7)).
		WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(1))

	out, err := repo.List(7, false, 30, 0)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(out.Items) != 2 || out.UnreadCount != 1 || out.Items[0].IsRead {
		t.Fatalf("unexpected result: %+v", out)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestListUnreadOnlyAddsFilter(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("is_read = 0 ORDER BY id DESC").WithArgs(int64(7), 10, 20).
		WillReturnRows(sqlmock.NewRows([]string{"id", "type", "title", "body", "is_read", "created_at"}))
	mock.ExpectQuery("SELECT COUNT").WithArgs(int64(7)).WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(0))
	out, err := NewRepository(db).List(7, true, 10, 20)
	if err != nil || out.Items == nil || len(out.Items) != 0 {
		t.Fatalf("List = %+v, %v (items must be an empty slice, not null)", out, err)
	}
}

func TestMarkReadIsScopedToOwnerAndIdempotent(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	repo := NewRepository(db)

	// Changed one row.
	mock.ExpectExec("UPDATE notifications SET is_read = 1 WHERE id = \\? AND user_id = \\?").
		WithArgs(int64(5), int64(7)).WillReturnResult(sqlmock.NewResult(0, 1))
	if err := repo.MarkRead(7, 5); err != nil {
		t.Fatalf("MarkRead: %v", err)
	}

	// Already read: zero rows changed, but it exists.
	mock.ExpectExec("UPDATE notifications").WithArgs(int64(5), int64(7)).WillReturnResult(sqlmock.NewResult(0, 0))
	mock.ExpectQuery("SELECT COUNT").WithArgs(int64(5), int64(7)).WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(1))
	if err := repo.MarkRead(7, 5); err != nil {
		t.Fatalf("MarkRead (already read): %v", err)
	}

	// Someone else's notification looks absent.
	mock.ExpectExec("UPDATE notifications").WithArgs(int64(9), int64(7)).WillReturnResult(sqlmock.NewResult(0, 0))
	mock.ExpectQuery("SELECT COUNT").WithArgs(int64(9), int64(7)).WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(0))
	if err := repo.MarkRead(7, 9); !errors.Is(err, ErrNotFound) {
		t.Fatalf("MarkRead other user's = %v, want ErrNotFound", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
