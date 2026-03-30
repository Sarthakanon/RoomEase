package handlers

import (
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"time"

	"github.com/gin-gonic/gin"
)

// AuthHandler handles authentication requests
type AuthHandler struct {
	sessionStore models.SessionStore
	dbService    *services.PostgresService
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(sessionStore models.SessionStore, dbService *services.PostgresService) *AuthHandler {
	return &AuthHandler{
		sessionStore: sessionStore,
		dbService:    dbService,
	}
}

// LoginRequest represents the login request body
type LoginRequest struct {
	FirebaseToken string `json:"firebase_token" binding:"required"`
}

// LoginResponse represents the login response
type LoginResponse struct {
	UserID    string `json:"user_id"`
	Email     string `json:"email"`
	SessionID string `json:"session_id"`
}

// Login handles user login with Firebase token
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Verify Firebase token
	firebaseUser, err := services.VerifyToken(req.FirebaseToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Check if user exists in PostgreSQL, if not create them
	dbUser, err := h.dbService.GetUserByFirebaseUID(firebaseUser.UID)
	if err != nil {
		// User doesn't exist, create new user
		dbUser = &models.User{
			FirebaseUID: firebaseUser.UID,
			Email:       firebaseUser.Email,
			Name:        firebaseUser.Name,
		}
		if err := h.dbService.CreateUser(dbUser); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create user",
			})
			return
		}
	} else {
		// User exists, update name if it changed (sync from Firebase)
		if dbUser.Name != firebaseUser.Name && firebaseUser.Name != firebaseUser.Email {
			h.dbService.UpdateUser(firebaseUser.UID, &models.UpdateUserRequest{Name: firebaseUser.Name})
			dbUser.Name = firebaseUser.Name
		}
	}

	// Generate session ID
	sessionID, err := services.GenerateSessionID()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to generate session",
		})
		return
	}

	// Create session
	session := &models.Session{
		ID:        sessionID,
		UserID:    firebaseUser.UID,
		Email:     firebaseUser.Email,
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(24 * time.Hour), // 24 hour session
	}

	if err := h.sessionStore.Create(session); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create session",
		})
		return
	}

	// Set session cookie
	c.SetCookie(
		"session_id",
		sessionID,
		86400, // 24 hours in seconds
		"/",
		"",
		false, // Set to true in production with HTTPS
		true,  // HttpOnly
	)

	// Return response
	c.JSON(http.StatusOK, LoginResponse{
		UserID:    firebaseUser.UID,
		Email:     firebaseUser.Email,
		SessionID: sessionID,
	})
}

// Logout handles user logout
func (h *AuthHandler) Logout(c *gin.Context) {
	// Get session ID from context (set by auth middleware)
	sessionID, exists := c.Get("session_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "No active session",
		})
		return
	}

	// Delete session
	if err := h.sessionStore.Delete(sessionID.(string)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete session",
		})
		return
	}

	// Clear session cookie
	c.SetCookie(
		"session_id",
		"",
		-1, // Expire immediately
		"/",
		"",
		false,
		true,
	)

	c.JSON(http.StatusOK, gin.H{
		"message": "Logged out successfully",
	})
}

// VerifyResponse represents the verify response
type VerifyResponse struct {
	Valid  bool   `json:"valid"`
	UserID string `json:"user_id,omitempty"`
	Email  string `json:"email,omitempty"`
}

// Verify checks if the current session is valid
func (h *AuthHandler) Verify(c *gin.Context) {
	// Get user info from context (set by auth middleware)
	userID, userExists := c.Get("user_id")
	email, emailExists := c.Get("email")

	if !userExists || !emailExists {
		c.JSON(http.StatusOK, VerifyResponse{
			Valid: false,
		})
		return
	}

	c.JSON(http.StatusOK, VerifyResponse{
		Valid:  true,
		UserID: userID.(string),
		Email:  email.(string),
	})
}

// RefreshResponse represents the refresh response
type RefreshResponse struct {
	Message   string    `json:"message"`
	ExpiresAt time.Time `json:"expires_at"`
}

// Refresh extends the current session expiration
func (h *AuthHandler) Refresh(c *gin.Context) {
	// Get session ID from context
	sessionID, exists := c.Get("session_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "No active session",
		})
		return
	}

	// Get current session
	session, err := h.sessionStore.Get(sessionID.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Invalid session",
		})
		return
	}

	// Extend expiration by 24 hours
	session.ExpiresAt = time.Now().Add(24 * time.Hour)

	// Update session
	if err := h.sessionStore.Create(session); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to refresh session",
		})
		return
	}

	c.JSON(http.StatusOK, RefreshResponse{
		Message:   "Session refreshed successfully",
		ExpiresAt: session.ExpiresAt,
	})
}
