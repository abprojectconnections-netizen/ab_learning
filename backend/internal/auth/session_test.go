package auth

import (
	"errors"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"

	"github.com/ablearning/api/internal/security"
)

var userCols = []string{"id", "email", "code", "first", "last", "avatar", "hash", "status", "instructor_verified"}

func activeUserRows(hash string) *sqlmock.Rows {
	return sqlmock.NewRows(userCols).
		AddRow(int64(7), "a@x.test", "LEARNER", "Anan", "S", "", hash, "active", false)
}

func newMockService(t *testing.T) (*Service, sqlmock.Sqlmock) {
	t.Helper()
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return NewService(NewRepository(db), "test-secret-test-secret-test-secret"), mock
}

func TestRefreshRotatesAndReturnsNewPair(t *testing.T) {
	svc, mock := newMockService(t)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, family_id").
		WithArgs(hashToken("old-token")).
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "family_id", "expires_at", "revoked"}).
			AddRow(int64(1), int64(7), "fam-1", time.Now().UTC().Add(time.Hour), false))
	mock.ExpectExec("INSERT INTO refresh_tokens").
		WithArgs(int64(7), sqlmock.AnyArg(), "fam-1", sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(2, 1))
	mock.ExpectExec("UPDATE refresh_tokens SET revoked_at = NOW\\(\\), replaced_by").
		WithArgs(int64(2), int64(1)).
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
	mock.ExpectQuery("SELECT u.id").WithArgs(int64(7)).WillReturnRows(activeUserRows("h"))

	resp, err := svc.Refresh("old-token", clientMeta{})
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if resp.RefreshToken == "" || resp.RefreshToken == "old-token" || resp.AccessToken == "" {
		t.Fatalf("expected a new token pair, got %+v", resp)
	}
	if _, err := security.ParseToken("test-secret-test-secret-test-secret", resp.AccessToken, "access"); err != nil {
		t.Fatalf("access token invalid: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestRefreshReuseRevokesWholeFamily(t *testing.T) {
	svc, mock := newMockService(t)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, family_id").
		WithArgs(hashToken("used-token")).
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "family_id", "expires_at", "revoked"}).
			AddRow(int64(1), int64(7), "fam-1", time.Now().UTC().Add(time.Hour), true))
	mock.ExpectExec("UPDATE refresh_tokens SET revoked_at = NOW\\(\\) WHERE family_id").
		WithArgs("fam-1").
		WillReturnResult(sqlmock.NewResult(0, 2))
	mock.ExpectCommit()

	if _, err := svc.Refresh("used-token", clientMeta{}); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("Refresh = %v, want ErrInvalidCredentials", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestRefreshRejectsExpiredAndUnknownTokens(t *testing.T) {
	svc, mock := newMockService(t)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, family_id").
		WithArgs(hashToken("expired")).
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "family_id", "expires_at", "revoked"}).
			AddRow(int64(1), int64(7), "fam-1", time.Now().UTC().Add(-time.Minute), false))
	mock.ExpectRollback()
	if _, err := svc.Refresh("expired", clientMeta{}); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("expired token: %v", err)
	}

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, family_id").
		WithArgs(hashToken("unknown")).
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "family_id", "expires_at", "revoked"}))
	mock.ExpectRollback()
	if _, err := svc.Refresh("unknown", clientMeta{}); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("unknown token: %v", err)
	}

	if _, err := svc.Refresh("", clientMeta{}); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("empty token: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestLogoutIsIdempotentForUnknownToken(t *testing.T) {
	svc, mock := newMockService(t)
	mock.ExpectQuery("SELECT family_id FROM refresh_tokens").
		WithArgs(hashToken("nope")).
		WillReturnRows(sqlmock.NewRows([]string{"family_id"}))
	if err := svc.Logout("nope"); err != nil {
		t.Fatalf("Logout: %v", err)
	}
	if err := svc.Logout(""); err != nil {
		t.Fatalf("Logout empty: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestForgotPasswordDoesNotRevealUnknownEmail(t *testing.T) {
	svc, mock := newMockService(t)
	called := false
	svc.WithResetNotifier(func(string, string) { called = true })

	mock.ExpectQuery("SELECT u.id").WithArgs("nobody@x.test").WillReturnRows(sqlmock.NewRows(userCols))
	if err := svc.ForgotPassword("  Nobody@X.test "); err != nil {
		t.Fatalf("ForgotPassword: %v", err)
	}
	if called {
		t.Fatal("notifier must not be called for an unknown email")
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestForgotPasswordStoresHashAndNotifiesOwner(t *testing.T) {
	svc, mock := newMockService(t)
	var gotEmail, gotToken string
	svc.WithResetNotifier(func(email, token string) { gotEmail, gotToken = email, token })

	mock.ExpectQuery("SELECT u.id").WithArgs("a@x.test").WillReturnRows(activeUserRows("h"))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE password_resets SET used_at = NOW\\(\\)").
		WithArgs(int64(7)).WillReturnResult(sqlmock.NewResult(0, 0))
	mock.ExpectExec("INSERT INTO password_resets").
		WithArgs(int64(7), sqlmock.AnyArg(), sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()

	if err := svc.ForgotPassword("a@x.test"); err != nil {
		t.Fatalf("ForgotPassword: %v", err)
	}
	if gotEmail != "a@x.test" || len(gotToken) < 40 {
		t.Fatalf("notifier got email=%q token length=%d", gotEmail, len(gotToken))
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestResetPasswordValidatesInput(t *testing.T) {
	svc := NewService(NewRepository(nil), "s")
	if err := svc.ResetPassword("tok", "short"); !errors.Is(err, ErrValidation) {
		t.Fatalf("short password: %v", err)
	}
	if err := svc.ResetPassword("", "long-enough-password"); !errors.Is(err, ErrInvalidResetToken) {
		t.Fatalf("empty token: %v", err)
	}
}

func TestChangePasswordRequiresCurrentPassword(t *testing.T) {
	svc, mock := newMockService(t)
	hash, err := security.HashPassword("current-password")
	if err != nil {
		t.Fatal(err)
	}
	mock.ExpectQuery("SELECT u.id").WithArgs(int64(7)).WillReturnRows(activeUserRows(hash))
	if err := svc.ChangePassword(7, "wrong-password", "brand-new-password"); !errors.Is(err, ErrWrongPassword) {
		t.Fatalf("ChangePassword = %v, want ErrWrongPassword", err)
	}
	if err := svc.ChangePassword(7, "current-password", "short"); !errors.Is(err, ErrValidation) {
		t.Fatalf("weak new password = %v, want ErrValidation", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestChangePasswordStoresNewHashAndRevokesSessions(t *testing.T) {
	svc, mock := newMockService(t)
	hash, _ := security.HashPassword("current-password")
	mock.ExpectQuery("SELECT u.id").WithArgs(int64(7)).WillReturnRows(activeUserRows(hash))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE users SET password_hash").
		WithArgs(sqlmock.AnyArg(), int64(7)).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("UPDATE refresh_tokens SET revoked_at = NOW\\(\\) WHERE user_id").
		WithArgs(int64(7)).WillReturnResult(sqlmock.NewResult(0, 3))
	mock.ExpectCommit()
	if err := svc.ChangePassword(7, "current-password", "brand-new-password"); err != nil {
		t.Fatalf("ChangePassword: %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestNewUUIDAndHashToken(t *testing.T) {
	re := regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
	a, err := newUUID()
	if err != nil || !re.MatchString(a) {
		t.Fatalf("newUUID = %q, %v", a, err)
	}
	if b, _ := newUUID(); a == b {
		t.Fatal("UUIDs must differ")
	}
	if h := hashToken("x"); len(h) != 64 || h == hashToken("y") {
		t.Fatalf("hashToken output unexpected: %q", h)
	}
}
