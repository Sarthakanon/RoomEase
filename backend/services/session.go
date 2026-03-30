package services

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"log"
	"roomease/backend/models"
	"sync"
	"time"
)

// InMemorySessionStore implements SessionStore interface using in-memory storage
type InMemorySessionStore struct {
	sessions map[string]*models.Session
	mu       sync.RWMutex
}

// NewInMemorySessionStore creates a new in-memory session store
func NewInMemorySessionStore() *InMemorySessionStore {
	store := &InMemorySessionStore{
		sessions: make(map[string]*models.Session),
	}
	
	// Start cleanup goroutine
	go store.cleanupExpiredSessions()
	
	return store
}

// Create stores a new session
func (s *InMemorySessionStore) Create(session *models.Session) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	s.sessions[session.ID] = session
	return nil
}

// Get retrieves a session by ID
func (s *InMemorySessionStore) Get(sessionID string) (*models.Session, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	session, exists := s.sessions[sessionID]
	if !exists {
		return nil, errors.New("session not found")
	}
	
	if session.IsExpired() {
		return nil, errors.New("session expired")
	}
	
	return session, nil
}

// Delete removes a session
func (s *InMemorySessionStore) Delete(sessionID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	delete(s.sessions, sessionID)
	return nil
}

// DeleteExpired removes all expired sessions
func (s *InMemorySessionStore) DeleteExpired() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	count := 0
	for id, session := range s.sessions {
		if session.IsExpired() {
			delete(s.sessions, id)
			count++
		}
	}
	
	if count > 0 {
		log.Printf("Cleaned up %d expired sessions", count)
	}
	
	return nil
}

// cleanupExpiredSessions runs periodically to remove expired sessions
func (s *InMemorySessionStore) cleanupExpiredSessions() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	
	for range ticker.C {
		s.DeleteExpired()
	}
}

// GenerateSessionID generates a random session ID
func GenerateSessionID() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}
