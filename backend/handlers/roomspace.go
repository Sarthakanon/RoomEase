package handlers

import (
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"

	"github.com/gin-gonic/gin"
)

// RoomspaceHandler handles roomspace-related requests
type RoomspaceHandler struct {
	dbService *services.PostgresService
}

// NewRoomspaceHandler creates a new roomspace handler
func NewRoomspaceHandler(dbService *services.PostgresService) *RoomspaceHandler {
	return &RoomspaceHandler{
		dbService: dbService,
	}
}

// GetRoomspaces retrieves all roomspaces for the current user
func (h *RoomspaceHandler) GetRoomspaces(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get user's roomspaces
	roomspaces, err := h.dbService.GetUserRoomspaces(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve roomspaces",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    roomspaces,
	})
}

// CreateRoomspace creates a new roomspace
func (h *RoomspaceHandler) CreateRoomspace(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req models.CreateRoomspaceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Create roomspace
	roomspace := &models.Roomspace{
		Name:        req.Name,
		Description: req.Description,
		CreatedBy:   userID.(string),
	}

	if err := h.dbService.CreateRoomspace(roomspace); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create roomspace",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Roomspace created successfully",
		"data":    roomspace,
	})
}

// GetRoomspace retrieves a specific roomspace by ID
func (h *RoomspaceHandler) GetRoomspace(c *gin.Context) {
	// Get roomspace ID from URL
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid roomspace ID",
		})
		return
	}

	// Get roomspace
	roomspace, err := h.dbService.GetRoomspaceByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Roomspace not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    roomspace,
	})
}

// JoinRoomspace adds the current user to a roomspace
func (h *RoomspaceHandler) JoinRoomspace(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid roomspace ID",
		})
		return
	}

	// Add user to roomspace
	if err := h.dbService.AddMemberToRoomspace(uint(id), userID.(string)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Successfully joined roomspace",
	})
}
