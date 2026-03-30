package middleware

import (
	"fmt"
	"net/http"
	"time"
	"roomease/backend/config"
	"roomease/backend/models"

	"github.com/gin-gonic/gin"
)

// SessionStore is the interface for session storage
var SessionStore models.SessionStore

// AuthMiddleware validates session and attaches user info to context
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		fmt.Printf("🔐 AuthMiddleware called for: %s %s\n", c.Request.Method, c.Request.URL.Path)
		
		// Get session cookie
		sessionID, err := c.Cookie("session_id")
		if err != nil {
			fmt.Printf("❌ No session cookie found\n")
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "No session cookie found",
			})
			c.Abort()
			return
		}

		fmt.Printf("🍪 Session ID: %s\n", sessionID)

		// Validate session
		session, err := SessionStore.Get(sessionID)
		if err != nil {
			fmt.Printf("❌ Invalid session: %v\n", err)
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or expired session",
			})
			c.Abort()
			return
		}

		fmt.Printf("✅ Valid session for user: %s\n", session.UserID)

		// Check if user is banned before allowing any operation
		if err := checkUserBanStatus(session.UserID); err != nil {
			fmt.Printf("🚫 User is BANNED, invalidating session and returning error\n")
			// User is banned - invalidate session and return ban error
			SessionStore.Delete(sessionID)
			
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
				"banned": true,
				"action": "logout_required",
			})
			c.Abort()
			return
		}

		fmt.Printf("✅ User is not banned, proceeding with request\n")

		// Attach user info to context
		c.Set("user_id", session.UserID)
		c.Set("email", session.Email)
		c.Set("session_id", session.ID)

		c.Next()
	}
}

// checkUserBanStatus checks if a user is currently banned
func checkUserBanStatus(userUID string) error {
	var user models.User
	result := config.DB.Where("firebase_uid = ?", userUID).First(&user)
	if result.Error != nil {
		// If user not found, don't block (let other middleware handle)
		return nil
	}

	// Debug logging
	fmt.Printf("🔍 Ban check for user %s: IsBanned=%v, BanReason=%v\n", userUID, user.IsBanned, user.BanReason)

	// Check if user is banned
	if user.IsBanned {
		reason := user.BanReason
		if reason == nil || *reason == "" {
			defaultReason := "Account suspended due to policy violation"
			reason = &defaultReason
		}
		fmt.Printf("🚫 User %s is BANNED: %s\n", userUID, *reason)
		return &BanError{
			Reason:   *reason,
			BannedAt: user.BannedAt,
		}
	}

	fmt.Printf("✅ User %s is NOT banned\n", userUID)
	return nil
}

// BanError represents a user ban error
type BanError struct {
	Reason   string
	BannedAt *time.Time
}

func (e *BanError) Error() string {
	return "Your account has been suspended: " + e.Reason
}
