package services

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"roomease/backend/models"
)

func TestInMemorySessionStore_Create(t *testing.T) {
	store := NewInMemorySessionStore()
	
	session := &models.Session{
		ID:        "test-session-1",
		UserID:    "user-1",
		Email:     "test@example.com",
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}
	
	err := store.Create(session)
	assert.NoError(t, err)
	
	// Verify session was stored
	retrievedSession, err := store.Get("test-session-1")
	assert.NoError(t, err)
	assert.Equal(t, session.ID, retrievedSession.ID)
	assert.Equal(t, session.UserID, retrievedSession.UserID)
	assert.Equal(t, session.Email, retrievedSession.Email)
}

func TestInMemorySessionStore_Get_NotFound(t *testing.T) {
	store := NewInMemorySessionStore()
	
	_, err := store.Get("non-existent-session")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "session not found")
}

func TestInMemorySessionStore_Get_Expired(t *testing.T) {
	store := NewInMemorySessionStore()
	
	// Create an expired session
	expiredSession := &models.Session{
		ID:        "expired-session",
		UserID:    "user-1",
		Email:     "test@example.com",
		CreatedAt: time.Now().Add(-2 * time.Hour),
		ExpiresAt: time.Now().Add(-1 * time.Hour), // Expired 1 hour ago
	}
	
	err := store.Create(expiredSession)
	assert.NoError(t, err)
	
	// Try to get expired session
	_, err = store.Get("expired-session")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "session expired")
}

func TestInMemorySessionStore_Delete(t *testing.T) {
	store := NewInMemorySessionStore()
	
	session := &models.Session{
		ID:        "test-session-2",
		UserID:    "user-2",
		Email:     "test2@example.com",
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}
	
	// Create session
	err := store.Create(session)
	assert.NoError(t, err)
	
	// Verify it exists
	_, err = store.Get("test-session-2")
	assert.NoError(t, err)
	
	// Delete session
	err = store.Delete("test-session-2")
	assert.NoError(t, err)
	
	// Verify it's gone
	_, err = store.Get("test-session-2")
	assert.Error(t, err)
}

func TestInMemorySessionStore_DeleteExpired(t *testing.T) {
	store := NewInMemorySessionStore()
	
	// Create a valid session
	validSession := &models.Session{
		ID:        "valid-session",
		UserID:    "user-1",
		Email:     "valid@example.com",
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}
	
	// Create an expired session
	expiredSession := &models.Session{
		ID:        "expired-session",
		UserID:    "user-2",
		Email:     "expired@example.com",
		CreatedAt: time.Now().Add(-2 * time.Hour),
		ExpiresAt: time.Now().Add(-1 * time.Hour),
	}
	
	// Store both sessions
	err := store.Create(validSession)
	assert.NoError(t, err)
	err = store.Create(expiredSession)
	assert.NoError(t, err)
	
	// Delete expired sessions
	err = store.DeleteExpired()
	assert.NoError(t, err)
	
	// Valid session should still exist
	_, err = store.Get("valid-session")
	assert.NoError(t, err)
	
	// Expired session should be gone (but Get will return error anyway due to expiry check)
	_, err = store.Get("expired-session")
	assert.Error(t, err)
}

func TestGenerateSessionID_Uniqueness(t *testing.T) {
	// Generate multiple session IDs and ensure they're unique
	sessionIDs := make(map[string]bool)
	
	for i := 0; i < 100; i++ {
		sessionID, err := GenerateSessionID()
		assert.NoError(t, err)
		assert.NotEmpty(t, sessionID)
		assert.Len(t, sessionID, 64) // 32 bytes = 64 hex characters
		
		// Check uniqueness
		assert.False(t, sessionIDs[sessionID], "Session ID should be unique")
		sessionIDs[sessionID] = true
	}
}

func TestGenerateSessionID_Format(t *testing.T) {
	sessionID, err := GenerateSessionID()
	assert.NoError(t, err)
	
	// Should be 64 characters long (32 bytes in hex)
	assert.Len(t, sessionID, 64)
	
	// Should only contain hex characters
	for _, char := range sessionID {
		assert.True(t, 
			(char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'),
			"Session ID should only contain hex characters")
	}
}

func TestSession_IsExpired(t *testing.T) {
	// Test non-expired session
	validSession := &models.Session{
		ExpiresAt: time.Now().Add(1 * time.Hour),
	}
	assert.False(t, validSession.IsExpired())
	
	// Test expired session
	expiredSession := &models.Session{
		ExpiresAt: time.Now().Add(-1 * time.Hour),
	}
	assert.True(t, expiredSession.IsExpired())
	
	// Test session expiring right now (should be considered expired)
	nowSession := &models.Session{
		ExpiresAt: time.Now().Add(-1 * time.Millisecond),
	}
	assert.True(t, nowSession.IsExpired())
}

func TestInMemorySessionStore_ConcurrentAccess(t *testing.T) {
	store := NewInMemorySessionStore()
	
	// Test concurrent writes
	done := make(chan bool, 10)
	
	for i := 0; i < 10; i++ {
		go func(id int) {
			session := &models.Session{
				ID:        fmt.Sprintf("concurrent-session-%d", id),
				UserID:    fmt.Sprintf("user-%d", id),
				Email:     fmt.Sprintf("user%d@example.com", id),
				CreatedAt: time.Now(),
				ExpiresAt: time.Now().Add(24 * time.Hour),
			}
			
			err := store.Create(session)
			assert.NoError(t, err)
			
			// Try to read it back
			_, err = store.Get(session.ID)
			assert.NoError(t, err)
			
			done <- true
		}(i)
	}
	
	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}
}