package middleware

import (
	"net/http"
	"roomease/backend/models"

	"github.com/gin-gonic/gin"
)

// SessionStore is the interface for session storage
var SessionStore models.SessionStore

// AuthMiddleware validates session and attaches user info to context
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get session cookie
		sessionID, err := c.Cookie("session_id")
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "No session cookie found",
			})
			c.Abort()
			return
		}

		// Validate session
		session, err := SessionStore.Get(sessionID)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or expired session",
			})
			c.Abort()
			return
		}

		// Attach user info to context
		c.Set("user_id", session.UserID)
		c.Set("email", session.Email)
		c.Set("session_id", session.ID)

		c.Next()
	}
}
