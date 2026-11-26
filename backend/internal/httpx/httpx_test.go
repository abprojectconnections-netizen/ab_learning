package httpx

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestJSONAndErrorShape(t *testing.T) {
	rec := httptest.NewRecorder()
	JSON(rec, http.StatusCreated, map[string]int{"a": 1})
	if rec.Code != 201 || !strings.HasPrefix(rec.Header().Get("Content-Type"), "application/json") ||
		strings.TrimSpace(rec.Body.String()) != `{"a":1}` {
		t.Fatalf("JSON: %d %q %q", rec.Code, rec.Header().Get("Content-Type"), rec.Body.String())
	}

	rec = httptest.NewRecorder()
	Error(rec, http.StatusForbidden, "nope")
	if rec.Code != 403 || strings.TrimSpace(rec.Body.String()) != `{"error":"nope"}` {
		t.Fatalf("Error: %d %q", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	JSON(rec, http.StatusNoContent, nil)
	if rec.Body.Len() != 0 {
		t.Fatal("nil body must write nothing")
	}
}

func TestDecode(t *testing.T) {
	var dst struct {
		N int `json:"n"`
	}
	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{"n":5}`))
	if err := Decode(httptest.NewRecorder(), req, &dst); err != nil || dst.N != 5 {
		t.Fatalf("Decode valid: %v %+v", err, dst)
	}
	req = httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{not json`))
	if err := Decode(httptest.NewRecorder(), req, &dst); err == nil {
		t.Fatal("invalid JSON must fail")
	}
	big := `{"n":1,"pad":"` + strings.Repeat("x", 1<<20+10) + `"}`
	req = httptest.NewRequest(http.MethodPost, "/", strings.NewReader(big))
	if err := Decode(httptest.NewRecorder(), req, &dst); err == nil {
		t.Fatal("body over 1 MiB must be rejected")
	}
}

func TestPathID(t *testing.T) {
	for raw, wantOK := range map[string]bool{"5": true, "0": false, "-3": false, "abc": false, "": false, "9223372036854775807": true} {
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.SetPathValue("id", raw)
		if _, ok := PathID(req, "id"); ok != wantOK {
			t.Errorf("PathID(%q) ok=%v, want %v", raw, ok, wantOK)
		}
	}
}

func TestQueryInt(t *testing.T) {
	get := func(q string) int {
		return QueryInt(httptest.NewRequest(http.MethodGet, "/?"+q, nil), "n", 10, 1, 100)
	}
	if get("") != 10 || get("n=abc") != 10 {
		t.Fatal("missing or invalid values must use the default")
	}
	if get("n=0") != 1 || get("n=-5") != 1 || get("n=1000") != 100 || get("n=50") != 50 {
		t.Fatal("values must be clamped to [min, max]")
	}
}
