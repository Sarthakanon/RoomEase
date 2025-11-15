package handlers

import (
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

// UserHandler handles user-related requests
type UserHandler struct {
	dbService *services.PostgresService
}

// NewUserHandler creates a new user handler
func NewUserHandler(dbService *services.PostgresService) *UserHandler {
	return &UserHandler{
		dbService: dbService,
	}
}

// GetProfile retrieves the current user's profile
func (h *UserHandler) GetProfile(c *gin.Context) {
	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get user from database
	user, err := h.dbService.GetUserByFirebaseUID(userID.(string))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "User not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    user,
	})
}

// UpdateProfile updates the current user's profile
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req models.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Update user
	if err := h.dbService.UpdateUser(userID.(string), &req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update user",
		})
		return
	}

	// Get updated user
	user, err := h.dbService.GetUserByFirebaseUID(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve updated user",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Profile updated successfully",
		"data":    user,
	})
}
