package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/ablearning/api/internal/security"
)

const secret = "middleware-test-secret-middleware-test"

func serve(t *testing.T, h http.Handler, authz string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	if authz != "" {
		req.Header.Set("Authorization", authz)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func token(t *testing.T, role, typ string, ttl time.Duration) string {
	t.Helper()
	tok, err := security.IssueToken(secret, 7, role, typ, ttl)
	if err != nil {
		t.Fatal(err)
	}
	return "Bearer " + tok
}

func TestGuardAuthentication(t *testing.T) {
	var seen Principal
	h := Guard{Secret: secret}.Require(func(w http.ResponseWriter, r *http.Request) {
		seen, _ = PrincipalFrom(r.Context())
		w.WriteHeader(http.StatusOK)
	})

	cases := []struct {
		name  string
		authz string
		want  int
	}{
		{"no header", "", 401},
		{"not a bearer scheme", "Basic abc", 401},
		{"garbage token", "Bearer nope", 401},
		{"expired token", token(t, "LEARNER", "access", -time.Minute), 401},
		{"refresh token is not accepted", token(t, "LEARNER", "refresh", time.Minute), 401},
		{"valid token", token(t, "LEARNER", "access", time.Minute), 200},
	}
	for _, c := range cases {
		if got := serve(t, h, c.authz).Code; got != c.want {
			t.Errorf("%s: status %d, want %d", c.name, got, c.want)
		}
	}
	if seen.UserID != 7 || seen.Role != "LEARNER" {
		t.Fatalf("principal not placed in context: %+v", seen)
	}
}

func TestGuardRoleAuthorization(t *testing.T) {
	h := Guard{Secret: secret}.Require(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}, RoleAdmin, RoleSuperAdmin)

	for role, want := range map[string]int{
		RoleAdmin: 204, RoleSuperAdmin: 204,
		RoleLearner: 403, RoleInstructor: 403, RoleEmployer: 403, RoleCorpAdmin: 403, RoleCorpManager: 403,
	} {
		if got := serve(t, h, token(t, role, "access", time.Minute)).Code; got != want {
			t.Errorf("role %s: status %d, want %d", role, got, want)
		}
	}
}

func TestCommonSetsCORSAndHandlesPreflight(t *testing.T) {
	called := false
	h := Common("https://app.example.test", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodOptions, "/x", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent || called {
		t.Fatalf("preflight: status %d, handler called=%v", rec.Code, called)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://app.example.test" {
		t.Fatalf("Allow-Origin = %q", got)
	}
	if !strings.Contains(rec.Header().Get("Access-Control-Allow-Headers"), "Authorization") {
		t.Fatal("Authorization must be an allowed header")
	}
}

func TestCommonRecoversFromPanic(t *testing.T) {
	h := Common("*", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { panic("boom") }))
	rec := serve(t, h, "")
	if rec.Code != http.StatusInternalServerError || !strings.Contains(rec.Body.String(), "internal error") {
		t.Fatalf("panic must become a JSON 500, got %d %q", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), "boom") {
		t.Fatal("panic details must not leak to the client")
	}
}
