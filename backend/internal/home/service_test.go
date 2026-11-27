package home

import (
	"context"
	"errors"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestGetFeedPropagatesGreetingError(t *testing.T) {
	db, mock, _ := sqlmock.New()
	defer db.Close()
	boom := errors.New("db down")
	mock.ExpectQuery(".").WillReturnError(boom)
	if _, err := NewService(NewRepository(db)).GetFeed(context.Background(), 1); !errors.Is(err, boom) {
		t.Fatalf("GetFeed = %v, want the repository error", err)
	}
}
