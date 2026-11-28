// Package payment implements checkout and payment webhooks in SANDBOX mode only.
//
// The Gateway interface isolates the payment provider. The only implementation
// shipped here is SandboxGateway, which signs and verifies webhooks with
// HMAC-SHA256 (Stripe-style "t=<unix>,v1=<hex>" header). It refuses to start in
// any mode other than "sandbox", so live payments cannot be enabled by
// configuration alone: that requires a new, separately reviewed gateway.
package payment

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

const (
	// SandboxProvider is stored in payment_events.provider.
	SandboxProvider = "sandbox"
	// Currency is the only currency supported by the platform.
	Currency = "THB"
	// SignatureHeader carries the webhook signature.
	SignatureHeader = "Payment-Signature"
	// SignatureTolerance bounds how old a signed webhook may be (replay window).
	SignatureTolerance = 5 * time.Minute
	minSecretLength    = 16
)

var (
	ErrInvalidSignature = errors.New("invalid webhook signature")
	ErrLiveMode         = errors.New("live-mode events are not accepted: sandbox only")
	ErrInvalidEvent     = errors.New("invalid webhook event")
)

// Event is the provider-neutral webhook payload.
type Event struct {
	ID       string    `json:"id"`
	Type     string    `json:"type"`
	Livemode bool      `json:"livemode"`
	Data     EventData `json:"data"`
}

// EventData identifies the payment and the amount the provider says it moved.
type EventData struct {
	Reference string `json:"reference"`
	Amount    int64  `json:"amount"` // minor units (satang)
	Currency  string `json:"currency"`
}

// Gateway is the boundary to a payment provider.
type Gateway interface {
	Name() string
	NewReference() (string, error)
	ParseWebhook(body []byte, signature string, now time.Time) (Event, error)
}

// SandboxGateway is the test-mode gateway.
type SandboxGateway struct{ secret []byte }

// NewSandboxGateway refuses any mode but "sandbox" and weak secrets.
func NewSandboxGateway(mode, secret string) (*SandboxGateway, error) {
	if mode != "sandbox" {
		return nil, fmt.Errorf("PAYMENT_MODE=%q is not supported: only \"sandbox\" is allowed until live payments are explicitly authorized", mode)
	}
	if len(secret) < minSecretLength {
		return nil, fmt.Errorf("PAYMENT_WEBHOOK_SECRET must contain at least %d characters", minSecretLength)
	}
	return &SandboxGateway{secret: []byte(secret)}, nil
}

func (g *SandboxGateway) Name() string { return SandboxProvider }

func (g *SandboxGateway) NewReference() (string, error) {
	b := make([]byte, 12)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return "sbx_" + hex.EncodeToString(b), nil
}

// Sign returns the header value for body at time ts. Used by tests and tooling.
func Sign(secret []byte, ts time.Time, body []byte) string {
	t := strconv.FormatInt(ts.Unix(), 10)
	return "t=" + t + ",v1=" + hex.EncodeToString(mac(secret, t, body))
}

func mac(secret []byte, t string, body []byte) []byte {
	m := hmac.New(sha256.New, secret)
	m.Write([]byte(t))
	m.Write([]byte("."))
	m.Write(body)
	return m.Sum(nil)
}

// ParseWebhook verifies the signature BEFORE looking at the body, rejects
// stale timestamps and live-mode events, then decodes the event.
func (g *SandboxGateway) ParseWebhook(body []byte, header string, now time.Time) (Event, error) {
	if err := verify(g.secret, header, body, now); err != nil {
		return Event{}, err
	}
	var ev Event
	if err := json.Unmarshal(body, &ev); err != nil {
		return Event{}, fmt.Errorf("%w: %v", ErrInvalidEvent, err)
	}
	if ev.Livemode {
		return Event{}, ErrLiveMode
	}
	if ev.ID == "" || len(ev.ID) > 150 || ev.Type == "" || len(ev.Type) > 100 {
		return Event{}, fmt.Errorf("%w: id and type are required", ErrInvalidEvent)
	}
	return ev, nil
}

func verify(secret []byte, header string, body []byte, now time.Time) error {
	var ts string
	var sigs []string
	for _, part := range strings.Split(header, ",") {
		k, v, ok := strings.Cut(strings.TrimSpace(part), "=")
		if !ok {
			continue
		}
		switch k {
		case "t":
			ts = v
		case "v1":
			sigs = append(sigs, v)
		}
	}
	unix, err := strconv.ParseInt(ts, 10, 64)
	if err != nil || len(sigs) == 0 {
		return ErrInvalidSignature
	}
	age := now.Sub(time.Unix(unix, 0))
	if age > SignatureTolerance || age < -SignatureTolerance {
		return ErrInvalidSignature
	}
	want := mac(secret, ts, body)
	for _, s := range sigs {
		got, err := hex.DecodeString(s)
		if err == nil && hmac.Equal(got, want) {
			return nil
		}
	}
	return ErrInvalidSignature
}
