package payment

import (
	"errors"
	"strings"
	"testing"
	"time"
)

const testSecret = "sandbox-webhook-secret-for-tests-123456"

var t0 = time.Date(2026, 11, 27, 12, 0, 0, 0, time.UTC)

func newGW(t *testing.T) *SandboxGateway {
	t.Helper()
	g, err := NewSandboxGateway("sandbox", testSecret)
	if err != nil {
		t.Fatal(err)
	}
	return g
}

const validBody = `{"id":"evt_1","type":"payment.succeeded","livemode":false,"data":{"reference":"sbx_abc","amount":10050,"currency":"THB"}}`

func TestGatewayRefusesLiveModeAndWeakSecrets(t *testing.T) {
	for _, mode := range []string{"live", "production", "", "SANDBOX", "test"} {
		if _, err := NewSandboxGateway(mode, testSecret); err == nil {
			t.Errorf("mode %q must be refused", mode)
		}
	}
	if _, err := NewSandboxGateway("sandbox", "short"); err == nil {
		t.Error("short secret must be refused")
	}
}

func TestNewReferenceIsUnique(t *testing.T) {
	g := newGW(t)
	a, _ := g.NewReference()
	b, _ := g.NewReference()
	if a == b || !strings.HasPrefix(a, "sbx_") || len(a) != 28 {
		t.Fatalf("references: %q %q", a, b)
	}
}

func TestParseWebhookAcceptsValidSignature(t *testing.T) {
	g := newGW(t)
	ev, err := g.ParseWebhook([]byte(validBody), Sign([]byte(testSecret), t0, []byte(validBody)), t0.Add(time.Second))
	if err != nil {
		t.Fatalf("ParseWebhook: %v", err)
	}
	if ev.ID != "evt_1" || ev.Type != "payment.succeeded" || ev.Data.Amount != 10050 || ev.Data.Reference != "sbx_abc" {
		t.Fatalf("event: %+v", ev)
	}
}

func TestParseWebhookRejectsBadSignatures(t *testing.T) {
	g := newGW(t)
	good := Sign([]byte(testSecret), t0, []byte(validBody))
	other := Sign([]byte("a-different-secret-entirely-000000"), t0, []byte(validBody))
	stale := Sign([]byte(testSecret), t0.Add(-10*time.Minute), []byte(validBody))
	future := Sign([]byte(testSecret), t0.Add(10*time.Minute), []byte(validBody))
	cases := map[string]struct {
		body, header string
	}{
		"empty header":      {validBody, ""},
		"garbage header":    {validBody, "nonsense"},
		"missing v1":        {validBody, "t=" + strings.Split(strings.Split(good, ",")[0], "=")[1]},
		"missing timestamp": {validBody, "v1=" + strings.Split(good, "v1=")[1]},
		"wrong secret":      {validBody, other},
		"tampered body":     {strings.Replace(validBody, "10050", "1", 1), good},
		"stale timestamp":   {validBody, stale},
		"future timestamp":  {validBody, future},
		"non-hex signature": {validBody, "t=1,v1=zzzz"},
	}
	for name, c := range cases {
		if _, err := g.ParseWebhook([]byte(c.body), c.header, t0); !errors.Is(err, ErrInvalidSignature) {
			t.Errorf("%s: got %v, want ErrInvalidSignature", name, err)
		}
	}
}

func TestParseWebhookAcceptsRotatedSecondSignature(t *testing.T) {
	g := newGW(t)
	good := Sign([]byte(testSecret), t0, []byte(validBody))
	header := good + ",v1=" + strings.Repeat("0", 64) // an extra, invalid v1 must not hide the valid one
	if _, err := g.ParseWebhook([]byte(validBody), header, t0); err != nil {
		t.Fatalf("got %v", err)
	}
}

func TestParseWebhookRejectsLiveModeAndMalformedEvents(t *testing.T) {
	g := newGW(t)
	sign := func(body string) string { return Sign([]byte(testSecret), t0, []byte(body)) }

	live := `{"id":"evt_2","type":"payment.succeeded","livemode":true,"data":{}}`
	if _, err := g.ParseWebhook([]byte(live), sign(live), t0); !errors.Is(err, ErrLiveMode) {
		t.Errorf("live-mode event: %v", err)
	}
	for name, body := range map[string]string{
		"not json":   `{nope`,
		"no id":      `{"type":"payment.succeeded"}`,
		"no type":    `{"id":"evt_3"}`,
		"huge id":    `{"id":"` + strings.Repeat("x", 151) + `","type":"t"}`,
		"empty body": ``,
	} {
		if _, err := g.ParseWebhook([]byte(body), sign(body), t0); !errors.Is(err, ErrInvalidEvent) {
			t.Errorf("%s: got %v, want ErrInvalidEvent", name, err)
		}
	}
}

func TestValidateCheckout(t *testing.T) {
	in := CheckoutInput{CourseIDs: []int64{1, 2}}
	if err := ValidateCheckout("idem-key-123", &in); err != nil || in.Method != "card" {
		t.Fatalf("valid request: %v %+v", err, in)
	}
	bad := map[string]struct {
		key string
		in  CheckoutInput
	}{
		"no key":       {"", CheckoutInput{CourseIDs: []int64{1}}},
		"short key":    {"abc", CheckoutInput{CourseIDs: []int64{1}}},
		"long key":     {strings.Repeat("k", 129), CheckoutInput{CourseIDs: []int64{1}}},
		"no courses":   {"idem-key-123", CheckoutInput{}},
		"too many":     {"idem-key-123", CheckoutInput{CourseIDs: make([]int64, 21)}},
		"zero id":      {"idem-key-123", CheckoutInput{CourseIDs: []int64{0}}},
		"negative id":  {"idem-key-123", CheckoutInput{CourseIDs: []int64{-4}}},
		"duplicate id": {"idem-key-123", CheckoutInput{CourseIDs: []int64{3, 3}}},
		"bad method":   {"idem-key-123", CheckoutInput{CourseIDs: []int64{1}, Method: "bitcoin"}},
	}
	for name, c := range bad {
		c := c
		if err := ValidateCheckout(c.key, &c.in); !errors.Is(err, ErrValidation) {
			t.Errorf("%s: got %v, want ErrValidation", name, err)
		}
	}
}

func TestRequestHashIgnoresCourseOrderButNotContent(t *testing.T) {
	a := requestHash(CheckoutInput{CourseIDs: []int64{1, 2}, Method: "card"})
	if a != requestHash(CheckoutInput{CourseIDs: []int64{2, 1}, Method: "card"}) {
		t.Error("course order must not change the hash")
	}
	if a == requestHash(CheckoutInput{CourseIDs: []int64{1, 3}, Method: "card"}) ||
		a == requestHash(CheckoutInput{CourseIDs: []int64{1, 2}, Method: "promptpay"}) {
		t.Error("different requests must hash differently")
	}
}
