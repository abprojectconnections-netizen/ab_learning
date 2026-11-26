package admin

import (
	"encoding/json"
	"strings"
	"time"
	"unicode/utf8"
)

// AuditFilter narrows the audit log listing.
type AuditFilter struct {
	Action  string
	ActorID int
	Limit   int
	Offset  int
}

// AuditEntry is one row of the audit log.
type AuditEntry struct {
	ID         int64           `json:"id"`
	ActorID    *int64          `json:"actor_id"`
	ActorEmail string          `json:"actor_email"`
	Action     string          `json:"action"`
	TargetType string          `json:"target_type"`
	TargetID   *int64          `json:"target_id"`
	Metadata   json.RawMessage `json:"metadata"`
	CreatedAt  time.Time       `json:"created_at"`
}

// ListAudit returns audit entries, newest first.
func (s *Service) ListAudit(f AuditFilter) ([]AuditEntry, error) {
	f.Action = strings.TrimSpace(f.Action)
	if utf8.RuneCountInString(f.Action) > 100 {
		return nil, invalid("action must be at most 100 characters")
	}
	return s.repo.ListAudit(f)
}

func (r *Repository) ListAudit(f AuditFilter) ([]AuditEntry, error) {
	where := []string{"1=1"}
	var args []any
	if f.Action != "" {
		where = append(where, "a.action = ?")
		args = append(args, f.Action)
	}
	if f.ActorID > 0 {
		where = append(where, "a.actor_id = ?")
		args = append(args, f.ActorID)
	}
	args = append(args, f.Limit, f.Offset)
	rows, err := r.db.Query(`SELECT a.id, a.actor_id, COALESCE(u.email, ''), a.action,
        COALESCE(a.target_type, ''), a.target_id, a.metadata, a.created_at
        FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_id
        WHERE `+strings.Join(where, " AND ")+` ORDER BY a.id DESC LIMIT ? OFFSET ?`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AuditEntry{}
	for rows.Next() {
		var e AuditEntry
		var actor, target *int64
		var meta []byte
		if err := rows.Scan(&e.ID, &actor, &e.ActorEmail, &e.Action, &e.TargetType, &target, &meta, &e.CreatedAt); err != nil {
			return nil, err
		}
		e.ActorID, e.TargetID = actor, target
		if len(meta) > 0 {
			e.Metadata = json.RawMessage(meta)
		} else {
			e.Metadata = json.RawMessage("null")
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
