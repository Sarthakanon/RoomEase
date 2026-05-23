package handlers

import (
	"fmt"
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/datatypes"
)

// ExpenseHistoryHandler handles expense history requests
type ExpenseHistoryHandler struct {
	dbService *services.PostgresService
}

// NewExpenseHistoryHandler creates a new expense history handler
func NewExpenseHistoryHandler(dbService *services.PostgresService) *ExpenseHistoryHandler {
	return &ExpenseHistoryHandler{
		dbService: dbService,
	}
}

// GetRoomspaceHistory retrieves expense history for a roomspace
func (h *ExpenseHistoryHandler) GetRoomspaceHistory(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	roomspaceID := c.Param("id")

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Parse query parameters
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 0 {
		limit = 50
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// Get history
	history, err := h.dbService.GetRoomspaceHistory(roomspaceID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to retrieve history",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.ExpenseHistoryResponse
	for _, item := range history {
		responses = append(responses, h.convertToHistoryResponse(&item))
	}

	// Ensure we always return an array, even if empty
	if responses == nil {
		responses = []models.ExpenseHistoryResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
		"meta": gin.H{
			"limit":  limit,
			"offset": offset,
			"count":  len(responses),
		},
	})
}

// CreateHistoryEntry creates a new history entry
func (h *ExpenseHistoryHandler) CreateHistoryEntry(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	roomspaceID := c.Param("id")

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Parse request body
	var req models.CreateExpenseHistoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Create history entry
	history := &models.ExpenseHistory{
		RoomspaceID: roomspaceID,
		Type:        models.ExpenseHistoryType(req.Type),
		Title:       req.Title,
		Description: req.Description,
		PerformedBy: req.PerformedBy,
		Amount:      req.Amount,
		Metadata:    datatypes.JSONMap(req.Metadata),
		Timestamp:   time.Now(),
	}

	if err := h.dbService.CreateExpenseHistory(history); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to create history entry",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	response := h.convertToHistoryResponse(history)

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "History entry created successfully",
		"data":    response,
	})
}

// GetRecentHistory retrieves recent history entries
func (h *ExpenseHistoryHandler) GetRecentHistory(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	roomspaceID := c.Param("id")

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Parse limit parameter (default 10)
	limitStr := c.DefaultQuery("limit", "10")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 0 {
		limit = 10
	}

	// Get recent history
	history, err := h.dbService.GetRecentHistory(roomspaceID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to retrieve recent history",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.ExpenseHistoryResponse
	for _, item := range history {
		responses = append(responses, h.convertToHistoryResponse(&item))
	}

	// Ensure we always return an array, even if empty
	if responses == nil {
		responses = []models.ExpenseHistoryResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// Helper functions

// verifyRoomspaceMembership checks if user is a member of the roomspace
func (h *ExpenseHistoryHandler) verifyRoomspaceMembership(roomspaceID string, userUID string) error {
	members, err := h.dbService.GetRoomspaceMembers(roomspaceID)
	if err != nil {
		return fmt.Errorf("failed to verify roomspace membership")
	}

	for _, member := range members {
		if member.UserID == userUID {
			return nil
		}
	}

	return fmt.Errorf("user is not a member of this roomspace")
}

// convertToHistoryResponse converts history model to response format
func (h *ExpenseHistoryHandler) convertToHistoryResponse(history *models.ExpenseHistory) models.ExpenseHistoryResponse {
	response := models.ExpenseHistoryResponse{
		ID:              history.ID,
		Type:            history.Type,
		Title:           history.Title,
		Description:     history.Description,
		PerformedBy:     history.PerformedBy,
		PerformedByName: history.PerformedByName,
		Amount:          history.Amount,
		Metadata:        map[string]interface{}(history.Metadata),
		Timestamp:       history.Timestamp,
	}

	return response
}
