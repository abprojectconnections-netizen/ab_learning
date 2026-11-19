package auth

import (
	"database/sql"
	"errors"
)

var (
	ErrNotFound   = errors.New("not found")
	ErrEmailTaken = errors.New("email or phone already registered")
)

type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

type userRow struct {
	User
	PasswordHash string
	Status       string
}

const userSelect = `
    SELECT u.id, u.email, r.code, COALESCE(p.first_name,''), COALESCE(p.last_name,''),
           COALESCE(p.avatar_url,''), u.password_hash, u.status,
           CASE WHEN i.verified_at IS NOT NULL THEN 1 ELSE 0 END
    FROM users u
    JOIN roles r ON r.id = u.role_id
    LEFT JOIN profiles p ON p.user_id = u.id
    LEFT JOIN instructors i ON i.user_id = u.id`

func (r *Repository) scan(row *sql.Row) (userRow, error) {
	var u userRow
	var verified bool
	err := row.Scan(&u.ID, &u.Email, &u.Role, &u.FirstName, &u.LastName,
		&u.AvatarURL, &u.PasswordHash, &u.Status, &verified)
	if errors.Is(err, sql.ErrNoRows) {
		return userRow{}, ErrNotFound
	}
	u.InstructorVerified = verified
	return u, err
}

func (r *Repository) ByEmail(email string) (userRow, error) {
	return r.scan(r.db.QueryRow(userSelect+` WHERE u.email = ?`, email))
}

func (r *Repository) ByID(id int64) (userRow, error) {
	return r.scan(r.db.QueryRow(userSelect+` WHERE u.id = ?`, id))
}

func (r *Repository) TouchLogin(id int64) {
	_, _ = r.db.Exec(`UPDATE users SET last_login_at = NOW() WHERE id = ?`, id)
}

// CreateUser creates the account, profile and (for instructors) an unverified
// instructor record atomically. Role is constrained by the service whitelist.
func (r *Repository) CreateUser(req RegisterRequest, hash, role string) (int64, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	var taken int
	if err := tx.QueryRow(`SELECT COUNT(*) FROM users WHERE email = ? OR (? <> '' AND phone = ?)`,
		req.Email, req.Phone, req.Phone).Scan(&taken); err != nil {
		return 0, err
	}
	if taken > 0 {
		return 0, ErrEmailTaken
	}

	var phone any
	if req.Phone != "" {
		phone = req.Phone
	}
	res, err := tx.Exec(`INSERT INTO users (role_id, email, phone, password_hash)
        SELECT id, ?, ?, ? FROM roles WHERE code = ?`, req.Email, phone, hash, role)
	if err != nil {
		return 0, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	if _, err := tx.Exec(`INSERT INTO profiles (user_id, first_name, last_name) VALUES (?, ?, ?)`,
		id, req.FirstName, req.LastName); err != nil {
		return 0, err
	}
	if role == "INSTRUCTOR" {
		if _, err := tx.Exec(`INSERT INTO instructors (user_id, verified_at) VALUES (?, NULL)`, id); err != nil {
			return 0, err
		}
	}
	return id, tx.Commit()
}

func (r *Repository) UpdateProfileName(id int64, first, last string) error {
	_, err := r.db.Exec(`INSERT INTO profiles (user_id, first_name, last_name) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE first_name = VALUES(first_name), last_name = VALUES(last_name)`,
		id, first, last)
	return err
}
