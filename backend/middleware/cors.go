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
			// In development, allow all origins (including mobile emulators)
			// Mobile apps typically don't send Origin header, so this allows them
			if origin == "" {
				return true // Allow requests without Origin header (mobile apps)
			}
			// Allow localhost and local network origins
			return strings.HasPrefix(origin, "http://localhost") || 
				   strings.HasPrefix(origin, "https://localhost") ||
				   strings.HasPrefix(origin, "http://127.0.0.1") ||
				   strings.HasPrefix(origin, "http://10.0.2.2") ||
				   strings.HasPrefix(origin, "http://172.") ||
				   strings.HasPrefix(origin, "http://192.168.") ||
				   strings.HasPrefix(origin, "https://192.168.")
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"},
		AllowHeaders:     []string{"Content-Type", "Authorization", "Cookie", "Accept", "Origin", "X-Requested-With"},
		ExposeHeaders:    []string{"Content-Length", "Set-Cookie"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}

	return cors.New(config)
}
