package auth

import (
	"database/sql"
	"errors"
	"time"
)

var (
	// ErrRefreshInvalid: unknown or expired refresh token.
	ErrRefreshInvalid = errors.New("refresh token invalid")
	// ErrRefreshReuse: a revoked token was presented again.
	ErrRefreshReuse = errors.New("refresh token reuse detected")
)

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}

// CreateRefresh stores the hash of a newly issued refresh token.
func (r *Repository) CreateRefresh(userID int64, hash, family string, expires time.Time, meta clientMeta) error {
	_, err := r.db.Exec(`INSERT INTO refresh_tokens
        (user_id, token_hash, family_id, expires_at, user_agent, ip_address) VALUES (?, ?, ?, ?, ?, ?)`,
		userID, hash, family, expires, nullable(truncate(meta.UserAgent, 255)), nullable(truncate(meta.IP, 45)))
	return err
}

// RotateRefresh atomically revokes the presented token and stores its
// replacement in the same family. A token that is already revoked means it was
// used before: the whole family is revoked (committed) and ErrRefreshReuse is
// returned.
func (r *Repository) RotateRefresh(oldHash, newHash string, newExpires time.Time, meta clientMeta) (int64, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	var (
		id, userID int64
		family     string
		expires    time.Time
		revoked    bool
	)
	err = tx.QueryRow(`SELECT id, user_id, family_id, expires_at, revoked_at IS NOT NULL
        FROM refresh_tokens WHERE token_hash = ? FOR UPDATE`, oldHash).
		Scan(&id, &userID, &family, &expires, &revoked)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, ErrRefreshInvalid
	}
	if err != nil {
		return 0, err
	}
	if revoked {
		if _, err := tx.Exec(`UPDATE refresh_tokens SET revoked_at = NOW()
            WHERE family_id = ? AND revoked_at IS NULL`, family); err != nil {
			return 0, err
		}
		if err := tx.Commit(); err != nil {
			return 0, err
		}
		return 0, ErrRefreshReuse
	}
	if !expires.After(time.Now().UTC()) {
		return 0, ErrRefreshInvalid
	}

	res, err := tx.Exec(`INSERT INTO refresh_tokens
        (user_id, token_hash, family_id, expires_at, user_agent, ip_address) VALUES (?, ?, ?, ?, ?, ?)`,
		userID, newHash, family, newExpires, nullable(truncate(meta.UserAgent, 255)), nullable(truncate(meta.IP, 45)))
	if err != nil {
		return 0, err
	}
	newID, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	if _, err := tx.Exec(`UPDATE refresh_tokens SET revoked_at = NOW(), replaced_by = ? WHERE id = ?`, newID, id); err != nil {
		return 0, err
	}
	return userID, tx.Commit()
}

// RevokeFamilyByHash revokes every token in the family of the given token.
// Unknown tokens are ignored (logout is idempotent).
func (r *Repository) RevokeFamilyByHash(hash string) error {
	var family string
	err := r.db.QueryRow(`SELECT family_id FROM refresh_tokens WHERE token_hash = ?`, hash).Scan(&family)
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE family_id = ? AND revoked_at IS NULL`, family)
	return err
}

// RevokeAllForUser signs the user out of every device.
func (r *Repository) RevokeAllForUser(userID int64) error {
	_, err := r.db.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = ? AND revoked_at IS NULL`, userID)
	return err
}

// SetPassword replaces the password hash and revokes all refresh tokens.
func (r *Repository) SetPassword(userID int64, hash string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`UPDATE users SET password_hash = ? WHERE id = ?`, hash, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = ? AND revoked_at IS NULL`, userID); err != nil {
		return err
	}
	return tx.Commit()
}

// CreateReset stores the hash of a reset token and invalidates earlier unused ones.
func (r *Repository) CreateReset(userID int64, hash string, expires time.Time) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`UPDATE password_resets SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(`INSERT INTO password_resets (user_id, token, expires_at) VALUES (?, ?, ?)`,
		userID, hash, expires); err != nil {
		return err
	}
	return tx.Commit()
}

// ConsumeReset validates and uses a reset token exactly once, sets the new
// password and revokes the user's refresh tokens, all in one transaction.
func (r *Repository) ConsumeReset(hash, newPasswordHash string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var (
		id, userID int64
		expires    time.Time
	)
	err = tx.QueryRow(`SELECT id, user_id, expires_at FROM password_resets
        WHERE token = ? AND used_at IS NULL FOR UPDATE`, hash).Scan(&id, &userID, &expires)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrInvalidResetToken
	}
	if err != nil {
		return err
	}
	if !expires.After(time.Now().UTC()) {
		return ErrInvalidResetToken
	}
	if _, err := tx.Exec(`UPDATE password_resets SET used_at = NOW() WHERE id = ?`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE users SET password_hash = ? WHERE id = ?`, newPasswordHash, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = ? AND revoked_at IS NULL`, userID); err != nil {
		return err
	}
	return tx.Commit()
}
