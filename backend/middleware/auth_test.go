package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"roomease/backend/models"
	"roomease/backend/services"
	"roomease/backend/testutils"
)

// Test setup
func setupTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	return router
}

func TestAuthMiddleware_NoSessionCookie(t *testing.T) {
	// Setup session store
	SessionStore = services.NewInMemorySessionStore()

	// Setup middleware
	authMiddleware := AuthMiddleware()

	// Setup router with middleware
	router := setupTestRouter()
	router.Use(authMiddleware)
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	// Create request without session cookie
	req, _ := http.NewRequest("GET", "/protected", nil)

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusUnauthorized, w.Code)

	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Contains(t, response["error"], "No session cookie found")
}

func TestAuthMiddleware_InvalidSession(t *testing.T) {
	// Setup session store
	SessionStore = services.NewInMemorySessionStore()

	// Setup middleware
	authMiddleware := AuthMiddleware()

	// Setup router with middleware
	router := setupTestRouter()
	router.Use(authMiddleware)
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	// Create request with invalid session cookie
	req, _ := http.NewRequest("GET", "/protected", nil)
	req.AddCookie(&http.Cookie{
		Name:  "session_id",
		Value: "invalid-session-123",
	})

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusUnauthorized, w.Code)

	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Contains(t, response["error"], "Invalid or expired session")
}

func TestAuthMiddleware_ValidSession(t *testing.T) {
	// Setup session store
	SessionStore = services.NewInMemorySessionStore()

	// Create a valid session
	session := &models.Session{
		ID:        "valid-session-123",
		UserID:    "user-123",
		Email:     "test@example.com",
		ExpiresAt: time.Now().Add(24 * time.Hour),
		CreatedAt: time.Now(),
	}

	err := SessionStore.Create(session)
	assert.NoError(t, err)

	// Setup middleware
	authMiddleware := AuthMiddleware()

	// Setup router with middleware
	router := setupTestRouter()
	router.Use(authMiddleware)
	router.GET("/protected", func(c *gin.Context) {
		// Check that context values are set
		userID, exists := c.Get("user_id")
		assert.True(t, exists)
		assert.Equal(t, "user-123", userID)

		email, exists := c.Get("email")
		assert.True(t, exists)
		assert.Equal(t, "test@example.com", email)

		sessionID, exists := c.Get("session_id")
		assert.True(t, exists)
		assert.Equal(t, "valid-session-123", sessionID)

		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	// Create request with valid session cookie
	req, _ := http.NewRequest("GET", "/protected", nil)
	req.AddCookie(&http.Cookie{
		Name:  "session_id",
		Value: "valid-session-123",
	})

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusOK, w.Code)
}

func TestAuthMiddleware_ExpiredSession(t *testing.T) {
	// Setup session store
	SessionStore = services.NewInMemorySessionStore()

	// Create an expired session
	expiredSession := &models.Session{
		ID:        "expired-session-456",
		UserID:    "user-456",
		Email:     "expired@example.com",
		ExpiresAt: time.Now().Add(-1 * time.Hour), // Expired 1 hour ago
		CreatedAt: time.Now().Add(-25 * time.Hour),
	}

	err := SessionStore.Create(expiredSession)
	assert.NoError(t, err)

	// Setup middleware
	authMiddleware := AuthMiddleware()

	// Setup router with middleware
	router := setupTestRouter()
	router.Use(authMiddleware)
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	// Create request with expired session cookie
	req, _ := http.NewRequest("GET", "/protected", nil)
	req.AddCookie(&http.Cookie{
		Name:  "session_id",
		Value: "expired-session-456",
	})

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusUnauthorized, w.Code)

	var response map[string]string
	err = json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Contains(t, response["error"], "Invalid or expired session")
}

func TestAuthMiddleware_EmptySessionCookie(t *testing.T) {
	// Setup session store
	SessionStore = services.NewInMemorySessionStore()

	// Setup middleware
	authMiddleware := AuthMiddleware()

	// Setup router with middleware
	router := setupTestRouter()
	router.Use(authMiddleware)
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	// Create request with empty session cookie
	req, _ := http.NewRequest("GET", "/protected", nil)
	req.AddCookie(&http.Cookie{
		Name:  "session_id",
		Value: "",
	})

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusUnauthorized, w.Code)

	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Contains(t, response["error"], "Invalid or expired session")
}

func TestAuthMiddleware_BannedUser(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	reason := "Policy violation"
	assert.NoError(t, db.Model(&models.User{}).
		Where("firebase_uid = ?", fixtures.Member.FirebaseUID).
		Updates(map[string]interface{}{
			"is_banned":  true,
			"ban_reason": reason,
		}).Error)

	SessionStore = services.NewInMemorySessionStore()
	session := &models.Session{
		ID:        "banned-session-123",
		UserID:    fixtures.Member.FirebaseUID,
		Email:     fixtures.Member.Email,
		ExpiresAt: time.Now().Add(24 * time.Hour),
		CreatedAt: time.Now(),
	}
	assert.NoError(t, SessionStore.Create(session))

	router := setupTestRouter()
	router.Use(AuthMiddleware())
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "success"})
	})

	req, _ := http.NewRequest("GET", "/protected", nil)
	req.AddCookie(&http.Cookie{Name: "session_id", Value: session.ID})

	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusForbidden, w.Code)

	var response map[string]interface{}
	assert.NoError(t, json.Unmarshal(w.Body.Bytes(), &response))
	assert.Equal(t, true, response["banned"])
	assert.Contains(t, response["error"], reason)
	_, err := SessionStore.Get(session.ID)
	assert.Error(t, err)
}
