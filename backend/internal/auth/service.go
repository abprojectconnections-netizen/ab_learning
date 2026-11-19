package auth

import (
	"errors"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/ablearning/api/internal/security"
)

const (
	accessTTL  = time.Hour
	refreshTTL = 30 * 24 * time.Hour
)

var (
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrAccountInactive    = errors.New("account is suspended or deactivated")
	ErrValidation         = errors.New("validation failed")
)

type Service struct {
	repo   *Repository
	secret string
}

func NewService(repo *Repository, secret string) *Service {
	return &Service{repo: repo, secret: secret}
}

func (s *Service) tokens(u userRow) (AuthTokenResponse, error) {
	access, err := security.IssueToken(s.secret, u.ID, u.Role, "access", accessTTL)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	refresh, err := security.IssueToken(s.secret, u.ID, u.Role, "refresh", refreshTTL)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	return AuthTokenResponse{AccessToken: access, RefreshToken: refresh, User: toUserResponse(u.User)}, nil
}

func (s *Service) Login(req LoginRequest) (AuthTokenResponse, error) {
	identifier := strings.ToLower(strings.TrimSpace(req.Identifier))
	if identifier == "" || req.Password == "" {
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	u, err := s.repo.ByEmail(identifier)
	if err != nil {
		// Same error for unknown user and wrong password (no user enumeration).
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	if !security.VerifyPassword(req.Password, u.PasswordHash) {
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	if u.Status != "active" {
		return AuthTokenResponse{}, ErrAccountInactive
	}
	s.repo.TouchLogin(u.ID)
	return s.tokens(u)
}

func (s *Service) Register(req RegisterRequest) (AuthTokenResponse, error) {
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.FirstName = strings.TrimSpace(req.FirstName)
	req.LastName = strings.TrimSpace(req.LastName)
	req.Phone = strings.TrimSpace(req.Phone)
	req.Role = strings.ToUpper(strings.TrimSpace(req.Role))
	if _, err := mail.ParseAddress(req.Email); err != nil {
		return AuthTokenResponse{}, errors.Join(ErrValidation, errors.New("a valid email is required"))
	}
	if req.FirstName == "" || req.LastName == "" {
		return AuthTokenResponse{}, errors.Join(ErrValidation, errors.New("first_name and last_name are required"))
	}
	if utf8.RuneCountInString(req.FirstName) > 100 || utf8.RuneCountInString(req.LastName) > 100 {
		return AuthTokenResponse{}, errors.Join(ErrValidation, errors.New("names must be at most 100 characters"))
	}
	if len(req.Password) < 8 {
		return AuthTokenResponse{}, errors.Join(ErrValidation, errors.New("password must be at least 8 characters"))
	}
	// Public self-registration is intentionally limited to learner/instructor.
	if req.Role == "" {
		req.Role = "LEARNER"
	}
	if req.Role != "LEARNER" && req.Role != "INSTRUCTOR" {
		return AuthTokenResponse{}, errors.Join(ErrValidation, errors.New("role must be LEARNER or INSTRUCTOR"))
	}
	hash, err := security.HashPassword(req.Password)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	id, err := s.repo.CreateUser(req, hash, req.Role)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	u, err := s.repo.ByID(id)
	if err != nil {
		return AuthTokenResponse{}, err
	}
	return s.tokens(u)
}

func (s *Service) Me(id int64) (User, error) {
	u, err := s.repo.ByID(id)
	return u.User, err
}

// UpdateMe edits the signed-in user's display name and returns the fresh user.
func (s *Service) UpdateMe(id int64, req UpdateProfileRequest) (User, error) {
	first := strings.TrimSpace(req.FirstName)
	last := strings.TrimSpace(req.LastName)
	if first == "" || last == "" {
		return User{}, errors.Join(ErrValidation, errors.New("first_name and last_name are required"))
	}
	if utf8.RuneCountInString(first) > 100 || utf8.RuneCountInString(last) > 100 {
		return User{}, errors.Join(ErrValidation, errors.New("first_name and last_name must be at most 100 characters"))
	}
	if err := s.repo.UpdateProfileName(id, first, last); err != nil {
		return User{}, err
	}
	return s.Me(id)
}

// Refresh exchanges a valid refresh token for a fresh token pair.
// NOTE: tokens are stateless (no rotation/revocation yet) — Phase 5 item.
func (s *Service) Refresh(refreshToken string) (AuthTokenResponse, error) {
	claims, err := security.ParseToken(s.secret, refreshToken, "refresh")
	if err != nil {
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	u, err := s.repo.ByID(claims.Sub)
	if err != nil || u.Status != "active" {
		return AuthTokenResponse{}, ErrInvalidCredentials
	}
	return s.tokens(u)
}
