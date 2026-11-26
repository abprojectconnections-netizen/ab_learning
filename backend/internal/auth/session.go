package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/ablearning/api/internal/security"
)

const (
	resetTTL          = time.Hour
	minPasswordLength = 8
)

var (
	// ErrInvalidResetToken covers unknown, used and expired reset tokens alike.
	ErrInvalidResetToken = errors.New("invalid or expired reset token")
	// ErrWrongPassword is returned when the current password does not match.
	ErrWrongPassword = errors.New("current password is incorrect")
)

// clientMeta is request context stored with a refresh token for auditing.
type clientMeta struct {
	UserAgent string
	IP        string
}

// ResetNotifier delivers a password-reset token to the account owner. In
// production this is an email sender; local/test only logs it.
type ResetNotifier func(email, token string)

// WithResetNotifier sets how reset tokens are delivered. Without one, reset
// tokens are created but never exposed.
func (s *Service) WithResetNotifier(n ResetNotifier) *Service {
	s.notify = n
	return s
}

func hashToken(token string) string {
	return fmt.Sprintf("%x", sha256.Sum256([]byte(token)))
}

// newUUID returns a random RFC 4122 version 4 UUID.
func newUUID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16]), nil
}

// Refresh exchanges a refresh token for a new token pair and rotates it: the
// presented token is revoked and replaced atomically. Presenting an
// already-used token is treated as theft and revokes the whole login family.
func (s *Service) Refresh(refreshToken string, meta clientMeta) (AuthTokenResponse, error) {
	if refreshToken == "" {
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	next, err := security.RandomToken(32)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	userID, err := s.repo.RotateRefresh(hashToken(refreshToken), hashToken(next),
		time.Now().UTC().Add(refreshTTL), meta)
	if err != nil {
		if errors.Is(err, ErrRefreshReuse) {
			log.Printf("auth: refresh token reuse detected; login family revoked")
		}
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	u, err := s.repo.ByID(userID)
	if err != nil || u.Status != "active" {
		_ = s.repo.RevokeAllForUser(userID)
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	access, err := security.IssueToken(s.secret, u.ID, u.Role, "access", accessTTL)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	return AuthTokenResponse{AccessToken: access, RefreshToken: next, User: toUserResponse(u.User)}, nil
}

// Logout revokes the login family of the given refresh token. It is
// idempotent and never reveals whether the token existed.
func (s *Service) Logout(refreshToken string) error {
	if refreshToken == "" {
		return nil
	}
	return s.repo.RevokeFamilyByHash(hashToken(refreshToken))
}

// LogoutAll revokes every refresh token of the user (all devices).
func (s *Service) LogoutAll(userID int64) error {
	return s.repo.RevokeAllForUser(userID)
}

// ForgotPassword always succeeds from the caller's point of view so that the
// endpoint cannot be used to discover which emails are registered.
func (s *Service) ForgotPassword(email string) error {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return nil
	}
	u, err := s.repo.ByEmail(email)
	if err != nil || u.Status != "active" {
		return nil
	}
	token, err := security.RandomToken(32)
	if err != nil {
		return err
	}
	if err := s.repo.CreateReset(u.ID, hashToken(token), time.Now().UTC().Add(resetTTL)); err != nil {
		return err
	}
	if s.notify != nil {
		s.notify(u.Email, token)
	}
	return nil
}

// ResetPassword sets a new password from a reset token, then signs the user out
// everywhere.
func (s *Service) ResetPassword(token, newPassword string) error {
	if len(newPassword) < minPasswordLength {
		return errors.Join(ErrValidation, errors.New("password must be at least 8 characters"))
	}
	if token == "" {
		return ErrInvalidResetToken
	}
	hash, err := security.HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.repo.ConsumeReset(hashToken(token), hash)
}

// ChangePassword verifies the current password, sets the new one and revokes
// all refresh tokens so other devices must sign in again.
func (s *Service) ChangePassword(userID int64, current, newPassword string) error {
	if len(newPassword) < minPasswordLength {
		return errors.Join(ErrValidation, errors.New("password must be at least 8 characters"))
	}
	u, err := s.repo.ByID(userID)
	if err != nil {
		return err
	}
	if !security.VerifyPassword(current, u.PasswordHash) {
		return ErrWrongPassword
	}
	hash, err := security.HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.repo.SetPassword(userID, hash)
}
