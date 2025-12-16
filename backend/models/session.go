package models

import "time"

// Session represents a user session
type Session struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// SessionStore defines the interface for session storage
type SessionStore interface {
	Create(session *Session) error
	Get(sessionID string) (*Session, error)
	Delete(sessionID string) error
	DeleteExpired() error
}

// IsExpired checks if the session has expired
func (s *Session) IsExpired() bool {
	return time.Now().After(s.ExpiresAt)
}
