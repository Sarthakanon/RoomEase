package middleware

import (
	"net/http"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

// RoomspaceService is the interface for roomspace operations
var RoomspaceService *services.PostgresService

// ValidateRoomspaceMembership validates that the authenticated user is a member of the requested roomspace
func ValidateRoomspaceMembership() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get user ID from context (set by AuthMiddleware)
		userID, exists := c.Get("user_id")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "User not authenticated",
			})
			c.Abort()
			return
		}

		// Get roomspace ID from URL parameter or query parameter
		roomspaceID := c.Param("id")
		if roomspaceID == "" {
			roomspaceID = c.Query("roomspace_id")
		}

		// If no roomspace ID is provided, skip validation
		// (some endpoints may not require roomspace context)
		if roomspaceID == "" {
			c.Next()
			return
		}

		// Validate membership
		if RoomspaceService != nil {
			if err := RoomspaceService.ValidateRoomspaceMembership(userID.(string), roomspaceID); err != nil {
				c.JSON(http.StatusForbidden, gin.H{
					"error": "You are not a member of this roomspace",
				})
				c.Abort()
				return
			}
		}

		c.Next()
	}
}
