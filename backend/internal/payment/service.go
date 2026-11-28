package payment

import (
	"context"
	"fmt"
	"strings"
	"time"
)

const maxCoursesPerOrder = 20

var allowedMethods = map[string]bool{"card": true, "promptpay": true}

type Service struct {
	repo *Repository
	gw   Gateway
	now  func() time.Time
}

func NewService(repo *Repository, gw Gateway) *Service {
	return &Service{repo: repo, gw: gw, now: func() time.Time { return time.Now().UTC() }}
}

func invalid(msg string) error { return fmt.Errorf("%w: %s", ErrValidation, msg) }

// ValidateCheckout normalises and checks a purchase request.
func ValidateCheckout(key string, in *CheckoutInput) error {
	key = strings.TrimSpace(key)
	if len(key) < 8 || len(key) > 128 {
		return invalid("Idempotency-Key header (8-128 characters) is required")
	}
	if len(in.CourseIDs) == 0 || len(in.CourseIDs) > maxCoursesPerOrder {
		return invalid(fmt.Sprintf("course_ids must contain 1-%d courses", maxCoursesPerOrder))
	}
	seen := map[int64]bool{}
	for _, id := range in.CourseIDs {
		if id <= 0 {
			return invalid("course_ids must be positive")
		}
		if seen[id] {
			return invalid("course_ids must not contain duplicates")
		}
		seen[id] = true
	}
	if in.Method == "" {
		in.Method = "card"
	}
	if !allowedMethods[in.Method] {
		return invalid("method must be card or promptpay")
	}
	return nil
}

func (s *Service) Checkout(ctx context.Context, userID int64, key string, in CheckoutInput) (CheckoutResult, bool, error) {
	if err := ValidateCheckout(key, &in); err != nil {
		return CheckoutResult{}, false, err
	}
	ref, err := s.gw.NewReference()
	if err != nil {
		return CheckoutResult{}, false, err
	}
	return s.repo.Checkout(ctx, userID, strings.TrimSpace(key), in, ref)
}

// HandleWebhook authenticates the delivery, then applies it exactly once.
func (s *Service) HandleWebhook(ctx context.Context, body []byte, signature string) (Outcome, error) {
	ev, err := s.gw.ParseWebhook(body, signature, s.now())
	if err != nil {
		return "", err
	}
	return s.repo.ApplyEvent(ctx, s.gw.Name(), ev, body)
}
