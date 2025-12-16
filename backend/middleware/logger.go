package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// LoggerMiddleware logs request and response information
func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Start timer
		startTime := time.Now()

		// Get user ID if available
		userID := "anonymous"
		if uid, exists := c.Get("user_id"); exists {
			userID = uid.(string)
		}

		// Log request
		log.Printf("→ %s %s | User: %s", c.Request.Method, c.Request.URL.Path, userID)

		// Process request
		c.Next()

		// Calculate duration
		duration := time.Since(startTime)

		// Log response
		log.Printf("← %s %s | Status: %d | Duration: %v | User: %s",
			c.Request.Method,
			c.Request.URL.Path,
			c.Writer.Status(),
			duration,
			userID,
		)
	}
}
