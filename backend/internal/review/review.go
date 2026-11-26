// Package review lets enrolled learners rate courses and lets admins moderate.
package review

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/ablearning/api/internal/httpx"
	"github.com/ablearning/api/internal/middleware"
)

var (
	ErrValidation  = errors.New("validation failed")
	ErrNotFound    = errors.New("not found")
	ErrNotEnrolled = errors.New("you must be enrolled in this course to review it")
)

type Review struct {
	ID           int64     `json:"id"`
	Rating       int       `json:"rating"`
	Comment      string    `json:"comment"`
	ReviewerName string    `json:"reviewer_name"`
	CreatedAt    time.Time `json:"created_at"`
}

type Listing struct {
	RatingAvg   float64  `json:"rating_avg"`
	RatingCount int      `json:"rating_count"`
	Items       []Review `json:"items"`
}

type Input struct {
	Rating  int    `json:"rating"`
	Comment string `json:"comment"`
}

// Validate normalises and checks a review.
func (in *Input) Validate() error {
	in.Comment = strings.TrimSpace(in.Comment)
	if in.Rating < 1 || in.Rating > 5 {
		return errors.Join(ErrValidation, errors.New("rating must be between 1 and 5"))
	}
	if utf8.RuneCountInString(in.Comment) > 2000 {
		return errors.Join(ErrValidation, errors.New("comment must be at most 2000 characters"))
	}
	return nil
}

type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) List(courseID int64, limit, offset int) (Listing, error) {
	var published int
	if err := r.db.QueryRow(`SELECT COUNT(*) FROM courses WHERE id = ? AND status = 'published'`, courseID).Scan(&published); err != nil {
		return Listing{}, err
	}
	if published == 0 {
		return Listing{}, ErrNotFound
	}
	out := Listing{Items: []Review{}}
	if err := r.db.QueryRow(`SELECT COALESCE(AVG(rating), 0), COUNT(*) FROM reviews WHERE course_id = ?`, courseID).
		Scan(&out.RatingAvg, &out.RatingCount); err != nil {
		return Listing{}, err
	}
	rows, err := r.db.Query(`SELECT r.id, r.rating, COALESCE(r.comment, ''),
        TRIM(CONCAT(COALESCE(p.first_name, ''), ' ', COALESCE(p.last_name, ''))), r.created_at
        FROM reviews r LEFT JOIN profiles p ON p.user_id = r.user_id
        WHERE r.course_id = ? ORDER BY r.id DESC LIMIT ? OFFSET ?`, courseID, limit, offset)
	if err != nil {
		return Listing{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var v Review
		if err := rows.Scan(&v.ID, &v.Rating, &v.Comment, &v.ReviewerName, &v.CreatedAt); err != nil {
			return Listing{}, err
		}
		out.Items = append(out.Items, v)
	}
	return out, rows.Err()
}

func refreshStats(tx *sql.Tx, courseID int64) error {
	_, err := tx.Exec(`UPDATE courses SET
        rating_avg = (SELECT COALESCE(AVG(rating), 0) FROM reviews WHERE course_id = ?),
        rating_count = (SELECT COUNT(*) FROM reviews WHERE course_id = ?)
        WHERE id = ?`, courseID, courseID, courseID)
	return err
}

// Upsert creates or updates the user's review. Only enrolled learners may review.
func (r *Repository) Upsert(courseID, userID int64, in Input) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var enrolled int
	if err := tx.QueryRow(`SELECT COUNT(*) FROM enrollments WHERE user_id = ? AND course_id = ?`, userID, courseID).Scan(&enrolled); err != nil {
		return err
	}
	if enrolled == 0 {
		return ErrNotEnrolled
	}
	if _, err := tx.Exec(`INSERT INTO reviews (course_id, user_id, rating, comment) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE rating = VALUES(rating), comment = VALUES(comment)`,
		courseID, userID, in.Rating, in.Comment); err != nil {
		return err
	}
	if err := refreshStats(tx, courseID); err != nil {
		return err
	}
	return tx.Commit()
}

// DeleteOwn removes the user's own review of a course.
func (r *Repository) DeleteOwn(courseID, userID int64) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	res, err := tx.Exec(`DELETE FROM reviews WHERE course_id = ? AND user_id = ?`, courseID, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	if err := refreshStats(tx, courseID); err != nil {
		return err
	}
	return tx.Commit()
}

// Moderate deletes any review and records the action in the audit log.
func (r *Repository) Moderate(reviewID, adminID int64) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var courseID int64
	err = tx.QueryRow(`SELECT course_id FROM reviews WHERE id = ? FOR UPDATE`, reviewID).Scan(&courseID)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM reviews WHERE id = ?`, reviewID); err != nil {
		return err
	}
	if err := refreshStats(tx, courseID); err != nil {
		return err
	}
	if _, err := tx.Exec(`INSERT INTO audit_logs (actor_id, action, target_type, target_id, metadata)
        VALUES (?, 'review.delete', 'review', ?, JSON_OBJECT('course_id', ?))`, adminID, reviewID, courseID); err != nil {
		return err
	}
	return tx.Commit()
}

func fail(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrValidation):
		httpx.Error(w, http.StatusUnprocessableEntity, err.Error())
	case errors.Is(err, ErrNotEnrolled):
		httpx.Error(w, http.StatusForbidden, err.Error())
	case errors.Is(err, ErrNotFound):
		httpx.Error(w, http.StatusNotFound, "not found")
	default:
		httpx.Error(w, http.StatusInternalServerError, "internal error")
	}
}

func Register(mux *http.ServeMux, guard middleware.Guard, repo *Repository) {
	mux.HandleFunc("GET /api/v1/courses/{id}/reviews", func(w http.ResponseWriter, r *http.Request) {
		id, ok := httpx.PathID(r, "id")
		if !ok {
			httpx.Error(w, http.StatusBadRequest, "invalid id")
			return
		}
		limit := httpx.QueryInt(r, "limit", 20, 1, 100)
		page := httpx.QueryInt(r, "page", 1, 1, 100000)
		out, err := repo.List(id, limit, (page-1)*limit)
		if err != nil {
			fail(w, err)
			return
		}
		httpx.JSON(w, http.StatusOK, out)
	})
	mux.Handle("PUT /api/v1/courses/{id}/reviews/me", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		id, ok := httpx.PathID(r, "id")
		if !ok {
			httpx.Error(w, http.StatusBadRequest, "invalid id")
			return
		}
		var in Input
		if err := httpx.Decode(w, r, &in); err != nil {
			httpx.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := in.Validate(); err != nil {
			fail(w, err)
			return
		}
		if err := repo.Upsert(id, p.UserID, in); err != nil {
			fail(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	mux.Handle("DELETE /api/v1/courses/{id}/reviews/me", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		id, ok := httpx.PathID(r, "id")
		if !ok {
			httpx.Error(w, http.StatusBadRequest, "invalid id")
			return
		}
		if err := repo.DeleteOwn(id, p.UserID); err != nil {
			fail(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	mux.Handle("DELETE /api/v1/admin/reviews/{id}", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		id, ok := httpx.PathID(r, "id")
		if !ok {
			httpx.Error(w, http.StatusBadRequest, "invalid id")
			return
		}
		if err := repo.Moderate(id, p.UserID); err != nil {
			fail(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}, middleware.RoleAdmin, middleware.RoleSuperAdmin))
}
