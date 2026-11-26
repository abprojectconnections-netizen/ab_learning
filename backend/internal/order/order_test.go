package order

import (
	"errors"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestListRejectsUnknownStatus(t *testing.T) {
	db, _, _ := sqlmock.New()
	defer db.Close()
	if _, err := NewRepository(db).List(7, "bogus", 20, 0); !errors.Is(err, ErrValidation) {
		t.Fatalf("List = %v, want ErrValidation", err)
	}
}

func TestListIsScopedToUserAndFiltersStatus(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("WHERE o.user_id = \\? AND o.status = \\? ORDER BY o.id DESC").
		WithArgs(int64(7), "paid", 20, 0).
		WillReturnRows(sqlmock.NewRows([]string{"id", "code", "status", "total", "items", "created"}).
			AddRow(int64(1), "DEMO-ORD-000001", "paid", 390.0, 1, time.Now()))
	out, err := NewRepository(db).List(7, "paid", 20, 0)
	if err != nil || len(out) != 1 || out[0].GrandTotal != 390 || out[0].ItemCount != 1 {
		t.Fatalf("List = %+v, %v", out, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestGetOtherUsersOrderIsNotFound(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("WHERE o.id = \\? AND o.user_id = \\?").WithArgs(int64(5), int64(7)).
		WillReturnRows(sqlmock.NewRows([]string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"}))
	if _, err := NewRepository(db).Get(7, 5); !errors.Is(err, ErrNotFound) {
		t.Fatalf("Get = %v, want ErrNotFound", err)
	}
}

func TestGetReturnsItemsAndPayment(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	paid := time.Now()
	mock.ExpectQuery("WHERE o.id = \\? AND o.user_id = \\?").WithArgs(int64(5), int64(7)).
		WillReturnRows(sqlmock.NewRows([]string{"id", "code", "status", "grand", "sub", "disc", "created", "method", "pstatus", "paid_at"}).
			AddRow(int64(5), "DEMO-ORD-000005", "paid", 390.0, 390.0, 0.0, time.Now(), "card", "success", paid))
	mock.ExpectQuery("FROM order_items i").WithArgs(int64(5)).
		WillReturnRows(sqlmock.NewRows([]string{"course_id", "title", "price"}).AddRow(int64(3), "Demo Course 03", 390.0))
	d, err := NewRepository(db).Get(7, 5)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if d.Payment == nil || d.Payment.Status != "success" || len(d.Items) != 1 || d.ItemCount != 1 {
		t.Fatalf("unexpected detail: %+v", d)
	}
}

func TestGetOrderWithoutPaymentHasNilPayment(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	mock.ExpectQuery("WHERE o.id = \\? AND o.user_id = \\?").WithArgs(int64(5), int64(7)).
		WillReturnRows(sqlmock.NewRows([]string{"id", "code", "status", "grand", "sub", "disc", "created", "method", "pstatus", "paid_at"}).
			AddRow(int64(5), "X", "pending", 100.0, 100.0, 0.0, time.Now(), nil, nil, nil))
	mock.ExpectQuery("FROM order_items i").WithArgs(int64(5)).
		WillReturnRows(sqlmock.NewRows([]string{"course_id", "title", "price"}))
	d, err := NewRepository(db).Get(7, 5)
	if err != nil || d.Payment != nil || d.Items == nil {
		t.Fatalf("Get = %+v, %v", d, err)
	}
}
