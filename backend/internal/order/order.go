// Package order exposes the signed-in user's purchase history (read only).
// Checkout and payment are handled separately, in sandbox mode.
package order

import (
	"database/sql"
	"errors"
	"net/http"
	"time"

	"github.com/ablearning/api/internal/httpx"
	"github.com/ablearning/api/internal/middleware"
)

var (
	ErrValidation = errors.New("validation failed")
	ErrNotFound   = errors.New("order not found")
)

var statuses = map[string]bool{"pending": true, "paid": true, "failed": true, "refunded": true, "cancelled": true}

type Summary struct {
	ID         int64     `json:"id"`
	OrderCode  string    `json:"order_code"`
	Status     string    `json:"status"`
	GrandTotal float64   `json:"grand_total"`
	ItemCount  int       `json:"item_count"`
	CreatedAt  time.Time `json:"created_at"`
}

type Item struct {
	CourseID int64   `json:"course_id"`
	Title    string  `json:"title"`
	Price    float64 `json:"price"`
}

type Payment struct {
	Method string     `json:"method"`
	Status string     `json:"status"`
	PaidAt *time.Time `json:"paid_at"`
}

type Detail struct {
	Summary
	Subtotal      float64  `json:"subtotal"`
	DiscountTotal float64  `json:"discount_total"`
	Items         []Item   `json:"items"`
	Payment       *Payment `json:"payment"`
}

type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

// List returns the user's orders, newest first. status may be empty.
func (r *Repository) List(userID int64, status string, limit, offset int) ([]Summary, error) {
	if status != "" && !statuses[status] {
		return nil, errors.Join(ErrValidation, errors.New("status must be pending, paid, failed, refunded or cancelled"))
	}
	q := `SELECT o.id, o.order_code, o.status, o.grand_total,
        (SELECT COUNT(*) FROM order_items i WHERE i.order_id = o.id), o.created_at
        FROM orders o WHERE o.user_id = ?`
	args := []any{userID}
	if status != "" {
		q += ` AND o.status = ?`
		args = append(args, status)
	}
	rows, err := r.db.Query(q+` ORDER BY o.id DESC LIMIT ? OFFSET ?`, append(args, limit, offset)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Summary{}
	for rows.Next() {
		var s Summary
		if err := rows.Scan(&s.ID, &s.OrderCode, &s.Status, &s.GrandTotal, &s.ItemCount, &s.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// Get returns one of the user's own orders; other users' orders look absent.
func (r *Repository) Get(userID, id int64) (Detail, error) {
	var d Detail
	var method, pstatus sql.NullString
	var paidAt sql.NullTime
	err := r.db.QueryRow(`SELECT o.id, o.order_code, o.status, o.grand_total, o.subtotal, o.discount_total, o.created_at,
        p.method, p.status, p.paid_at
        FROM orders o LEFT JOIN payments p ON p.order_id = o.id
        WHERE o.id = ? AND o.user_id = ?`, id, userID).
		Scan(&d.ID, &d.OrderCode, &d.Status, &d.GrandTotal, &d.Subtotal, &d.DiscountTotal, &d.CreatedAt,
			&method, &pstatus, &paidAt)
	if errors.Is(err, sql.ErrNoRows) {
		return Detail{}, ErrNotFound
	}
	if err != nil {
		return Detail{}, err
	}
	if pstatus.Valid {
		p := &Payment{Method: method.String, Status: pstatus.String}
		if paidAt.Valid {
			t := paidAt.Time
			p.PaidAt = &t
		}
		d.Payment = p
	}
	rows, err := r.db.Query(`SELECT i.course_id, c.title, i.price FROM order_items i
        JOIN courses c ON c.id = i.course_id WHERE i.order_id = ? ORDER BY i.id`, id)
	if err != nil {
		return Detail{}, err
	}
	defer rows.Close()
	d.Items = []Item{}
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.CourseID, &it.Title, &it.Price); err != nil {
			return Detail{}, err
		}
		d.Items = append(d.Items, it)
	}
	d.ItemCount = len(d.Items)
	return d, rows.Err()
}

func Register(mux *http.ServeMux, guard middleware.Guard, repo *Repository) {
	mux.Handle("GET /api/v1/orders", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		limit := httpx.QueryInt(r, "limit", 20, 1, 100)
		page := httpx.QueryInt(r, "page", 1, 1, 100000)
		out, err := repo.List(p.UserID, r.URL.Query().Get("status"), limit, (page-1)*limit)
		switch {
		case errors.Is(err, ErrValidation):
			httpx.Error(w, http.StatusUnprocessableEntity, err.Error())
		case err != nil:
			httpx.Error(w, http.StatusInternalServerError, "internal error")
		default:
			httpx.JSON(w, http.StatusOK, out)
		}
	}))
	mux.Handle("GET /api/v1/orders/{id}", guard.Require(func(w http.ResponseWriter, r *http.Request) {
		p, _ := middleware.PrincipalFrom(r.Context())
		id, ok := httpx.PathID(r, "id")
		if !ok {
			httpx.Error(w, http.StatusBadRequest, "invalid id")
			return
		}
		d, err := repo.Get(p.UserID, id)
		switch {
		case errors.Is(err, ErrNotFound):
			httpx.Error(w, http.StatusNotFound, "not found")
		case err != nil:
			httpx.Error(w, http.StatusInternalServerError, "internal error")
		default:
			httpx.JSON(w, http.StatusOK, d)
		}
	}))
}
