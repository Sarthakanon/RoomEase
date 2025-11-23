package middleware

import (
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// CORSMiddleware returns a CORS middleware configured for the application
func CORSMiddleware(allowedOrigins string) gin.HandlerFunc {
	config := cors.Config{
		AllowOriginFunc: func(origin string) bool {
			// Allow all localhost origins during development
			return strings.HasPrefix(origin, "http://localhost:") || 
				   strings.HasPrefix(origin, "http://127.0.0.1:")
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Content-Type", "Authorization", "Cookie"},
		ExposeHeaders:    []string{"Content-Length", "Set-Cookie"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}

	return cors.New(config)
}
