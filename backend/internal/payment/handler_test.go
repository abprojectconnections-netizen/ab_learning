package payment

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/ablearning/api/internal/middleware"
	"github.com/ablearning/api/internal/security"
)

const jwtSecret = "handler-test-jwt-secret-handler-test-jwt"

func testMux(t *testing.T) *http.ServeMux {
	t.Helper()
	mux := http.NewServeMux()
	// The repository is nil: every request below must be rejected before any database access.
	Register(mux, middleware.Guard{Secret: jwtSecret}, NewService(nil, newGW(t)))
	return mux
}

func do(mux *http.ServeMux, method, path, body string, hdr map[string]string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func bearer(t *testing.T) map[string]string {
	t.Helper()
	tok, err := security.IssueToken(jwtSecret, 5, "LEARNER", "access", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	return map[string]string{"Authorization": "Bearer " + tok}
}

func TestCheckoutRequiresAuthentication(t *testing.T) {
	rec := do(testMux(t), "POST", "/api/v1/checkout", `{"course_ids":[1]}`, nil)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status %d, want 401", rec.Code)
	}
}

func TestCheckoutValidationErrors(t *testing.T) {
	mux := testMux(t)
	auth := bearer(t)
	withKey := func(k string) map[string]string {
		h := map[string]string{"Idempotency-Key": k}
		for a, b := range auth {
			h[a] = b
		}
		return h
	}
	cases := map[string]struct {
		body string
		hdr  map[string]string
		want int
	}{
		"invalid json":       {`{nope`, withKey("idem-key-123"), 400},
		"missing key":        {`{"course_ids":[1]}`, auth, 422},
		"no courses":         {`{"course_ids":[]}`, withKey("idem-key-123"), 422},
		"duplicate courses":  {`{"course_ids":[1,1]}`, withKey("idem-key-123"), 422},
		"unsupported method": {`{"course_ids":[1],"method":"bitcoin"}`, withKey("idem-key-123"), 422},
	}
	for name, c := range cases {
		if rec := do(mux, "POST", "/api/v1/checkout", c.body, c.hdr); rec.Code != c.want {
			t.Errorf("%s: status %d, want %d (%s)", name, rec.Code, c.want, rec.Body.String())
		}
	}
}

func TestWebhookRejectsBadSignaturesWithoutTouchingDatabase(t *testing.T) {
	mux := testMux(t)
	body := validBody
	for name, hdr := range map[string]map[string]string{
		"no signature":    nil,
		"wrong signature": {SignatureHeader: Sign([]byte("another-secret-another-secret-12"), time.Now(), []byte(body))},
		"stale signature": {SignatureHeader: Sign([]byte(testSecret), time.Now().Add(-time.Hour), []byte(body))},
	} {
		if rec := do(mux, "POST", "/api/v1/webhooks/payments", body, hdr); rec.Code != http.StatusBadRequest {
			t.Errorf("%s: status %d, want 400", name, rec.Code)
		}
	}
}

func TestWebhookRejectsLiveModeEvenWhenCorrectlySigned(t *testing.T) {
	live := `{"id":"evt_live","type":"payment.succeeded","livemode":true,"data":{"reference":"sbx_abc","amount":1,"currency":"THB"}}`
	hdr := map[string]string{SignatureHeader: Sign([]byte(testSecret), time.Now(), []byte(live))}
	rec := do(testMux(t), "POST", "/api/v1/webhooks/payments", live, hdr)
	if rec.Code != http.StatusBadRequest || !strings.Contains(rec.Body.String(), "sandbox only") {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
}

func TestWebhookBodyTooLarge(t *testing.T) {
	big := strings.Repeat("x", maxWebhookBody+10)
	if rec := do(testMux(t), "POST", "/api/v1/webhooks/payments", big, nil); rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status %d, want 413", rec.Code)
	}
}
