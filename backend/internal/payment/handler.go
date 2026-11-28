package payment

import (
	"errors"
	"io"
	"log"
	"net/http"

	"github.com/ablearning/api/internal/httpx"
	"github.com/ablearning/api/internal/middleware"
)

const maxWebhookBody = 64 << 10

// Register mounts checkout (authenticated) and the provider webhook (public,
// authenticated by signature instead of a bearer token).
func Register(mux *http.ServeMux, guard middleware.Guard, svc *Service) {
	mux.Handle("POST /api/v1/checkout", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		var in CheckoutInput
		if err := httpx.Decode(w, r, &in); err != nil {
			httpx.Error(w, http.StatusBadRequest, "invalid JSON body")
			return
		}
		out, replayed, err := svc.Checkout(r.Context(), p.UserID, r.Header.Get("Idempotency-Key"), in)
		switch {
		case errors.Is(err, ErrValidation):
			httpx.Error(w, http.StatusUnprocessableEntity, err.Error())
		case errors.Is(err, ErrCourseUnavailable):
			httpx.Error(w, http.StatusNotFound, err.Error())
		case errors.Is(err, ErrAlreadyEnrolled), errors.Is(err, ErrIdempotencyConflict):
			httpx.Error(w, http.StatusConflict, err.Error())
		case errors.Is(err, ErrFreeOrder):
			httpx.Error(w, http.StatusUnprocessableEntity, err.Error())
		case err != nil:
			log.Printf("checkout: %v", err)
			httpx.Error(w, http.StatusInternalServerError, "internal error")
		default:
			if replayed {
				w.Header().Set("Idempotent-Replayed", "true")
			}
			httpx.JSON(w, http.StatusCreated, out)
		}
	}))

	mux.HandleFunc("POST /api/v1/webhooks/payments", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxWebhookBody))
		if err != nil {
			httpx.Error(w, http.StatusRequestEntityTooLarge, "body too large")
			return
		}
		outcome, err := svc.HandleWebhook(r.Context(), body, r.Header.Get(SignatureHeader))
		switch {
		case errors.Is(err, ErrInvalidSignature):
			httpx.Error(w, http.StatusBadRequest, "invalid signature")
		case errors.Is(err, ErrLiveMode), errors.Is(err, ErrInvalidEvent):
			httpx.Error(w, http.StatusBadRequest, err.Error())
		case err != nil:
			log.Printf("payment webhook: %v", err)
			httpx.Error(w, http.StatusInternalServerError, "internal error") // provider will retry
		default:
			httpx.JSON(w, http.StatusOK, map[string]string{"status": string(outcome)})
		}
	})
}
