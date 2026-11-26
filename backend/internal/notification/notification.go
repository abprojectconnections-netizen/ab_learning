// Package notification serves the signed-in user's in-app notifications.
package notification

import (
	"database/sql"
	"errors"
	"net/http"
	"time"

	"github.com/ablearning/api/internal/httpx"
	"github.com/ablearning/api/internal/middleware"
)

var ErrNotFound = errors.New("notification not found")

type Notification struct {
	ID        int64     `json:"id"`
	Type      string    `json:"type"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

type ListResponse struct {
	Items       []Notification `json:"items"`
	UnreadCount int            `json:"unread_count"`
}

type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) List(userID int64, unreadOnly bool, limit, offset int) (ListResponse, error) {
	q := `SELECT id, type, title, COALESCE(body, ''), is_read, created_at FROM notifications WHERE user_id = ?`
	if unreadOnly {
		q += ` AND is_read = 0`
	}
	rows, err := r.db.Query(q+` ORDER BY id DESC LIMIT ? OFFSET ?`, userID, limit, offset)
	if err != nil {
		return ListResponse{}, err
	}
	defer rows.Close()
	out := ListResponse{Items: []Notification{}}
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.Type, &n.Title, &n.Body, &n.IsRead, &n.CreatedAt); err != nil {
			return ListResponse{}, err
		}
		out.Items = append(out.Items, n)
	}
	if err := rows.Err(); err != nil {
		return ListResponse{}, err
	}
	err = r.db.QueryRow(`SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0`, userID).Scan(&out.UnreadCount)
	return out, err
}

// MarkRead marks one of the user's own notifications as read. It is idempotent;
// a notification that belongs to someone else is reported as not found.
func (r *Repository) MarkRead(userID, id int64) error {
	res, err := r.db.Exec(`UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?`, id, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n > 0 {
		return nil
	}
	var exists int
	if err := r.db.QueryRow(`SELECT COUNT(*) FROM notifications WHERE id = ? AND user_id = ?`, id, userID).Scan(&exists); err != nil {
		return err
	}
	if exists == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) MarkAllRead(userID int64) error {
	_, err := r.db.Exec(`UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0`, userID)
	return err
}

// Register mounts the routes; every route requires a signed-in user.
func Register(mux *http.ServeMux, guard middleware.Guard, repo *Repository) {
	mux.Handle("GET /api/v1/notifications", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		limit := httpx.QueryInt(r, "limit", 30, 1, 100)
		page := httpx.QueryInt(r, "page", 1, 1, 100000)
		out, err := repo.List(p.UserID, r.URL.Query().Get("unread") == "true", limit, (page-1)*limit)
		if err != nil {
			httpx.Error(w, http.StatusInternalServerError, "internal error")
			return
		}
		httpx.JSON(w, http.StatusOK, out)
	}))
	mux.Handle("POST /api/v1/notifications/read-all", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		if err := repo.MarkAllRead(p.UserID); err != nil {
			httpx.Error(w, http.StatusInternalServerError, "internal error")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	mux.Handle("POST /api/v1/notifications/{id}/read", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		id, ok := httpx.PathID(r, "id")
		if !ok {
			httpx.Error(w, http.StatusBadRequest, "invalid id")
			return
		}
		switch err := repo.MarkRead(p.UserID, id); {
		case errors.Is(err, ErrNotFound):
			httpx.Error(w, http.StatusNotFound, "not found")
		case err != nil:
			httpx.Error(w, http.StatusInternalServerError, "internal error")
		default:
			w.WriteHeader(http.StatusNoContent)
		}
	}))
}
