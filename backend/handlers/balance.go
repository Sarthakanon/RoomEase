package handlers

import (
	"fmt"
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"

	"github.com/gin-gonic/gin"
)

// BalanceHandler handles balance-related requests
type BalanceHandler struct {
	balanceService *services.BalanceService
	dbService      *services.PostgresService
}

// NewBalanceHandler creates a new balance handler
func NewBalanceHandler(balanceService *services.BalanceService, dbService *services.PostgresService) *BalanceHandler {
	return &BalanceHandler{
		balanceService: balanceService,
		dbService:      dbService,
	}
}

// GetRoomspaceBalances returns balance summary for a roomspace
// GET /api/roomspaces/:id/balances
func (h *BalanceHandler) GetRoomspaceBalances(c *gin.Context) {
	roomspaceID := c.Param("id")
	
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Calculate balances
	summary, err := h.balanceService.CalculateRoomspaceBalances(roomspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to calculate balances",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    summary,
	})
}

// GetUserBalance returns a specific user's balance in a roomspace
// GET /api/roomspaces/:id/balances/:userId
func (h *BalanceHandler) GetUserBalance(c *gin.Context) {
	roomspaceID := c.Param("id")
	targetUserID := c.Param("userId")
	
	// Get authenticated user ID from context
	authUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Verify authenticated user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, authUserID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Get balance (can view any member's balance if you're in the roomspace)
	balance, err := h.balanceService.GetCachedBalance(roomspaceID, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get balance",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    balance,
	})
}

// CreateSettlement records a settlement between two users
// POST /api/roomspaces/:id/settlements
func (h *BalanceHandler) CreateSettlement(c *gin.Context) {
	roomspaceID := c.Param("id")
	
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req struct {
		FromUserID string  `json:"from_user_id" binding:"required"`
		ToUserID   string  `json:"to_user_id" binding:"required"`
		Amount     float64 `json:"amount" binding:"required,gt=0"`
		Notes      string  `json:"notes"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Verify authenticated user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Create settlement model
	settlement := &models.Settlement{
		RoomspaceID: roomspaceID,
		FromUserID:  req.FromUserID,
		ToUserID:    req.ToUserID,
		Amount:      req.Amount,
		Notes:       req.Notes,
	}

	// Create settlement
	if err := h.balanceService.CreateSettlement(settlement); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Failed to create settlement",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Settlement recorded successfully",
		"data":    settlement,
	})
}

// GetSettlementHistory returns settlement history for a roomspace
// GET /api/roomspaces/:id/settlements?limit=10&offset=0
func (h *BalanceHandler) GetSettlementHistory(c *gin.Context) {
	roomspaceID := c.Param("id")
	
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Parse query parameters
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	// Get settlement history
	settlements, err := h.balanceService.GetSettlementHistory(roomspaceID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get settlement history",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    settlements,
	})
}

// GetSettlementSuggestions returns optimal settlement suggestions
// GET /api/roomspaces/:id/settlements/suggestions
func (h *BalanceHandler) GetSettlementSuggestions(c *gin.Context) {
	roomspaceID := c.Param("id")
	
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Generate settlement suggestions
	suggestions, err := h.balanceService.GenerateSettlementSuggestions(roomspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to generate settlement suggestions",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    suggestions,
	})
}

// RefreshBalanceCache manually refreshes the balance cache for a roomspace
// POST /api/roomspaces/:id/balances/refresh
func (h *BalanceHandler) RefreshBalanceCache(c *gin.Context) {
	roomspaceID := c.Param("id")
	
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Refresh cache
	if err := h.balanceService.UpdateBalanceCache(roomspaceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to refresh balance cache",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Balance cache refreshed successfully",
	})
}

// verifyRoomspaceMembership checks if a user is a member of a roomspace
func (h *BalanceHandler) verifyRoomspaceMembership(roomspaceID, userID string) error {
	roomspace, err := h.dbService.GetRoomspaceByID(roomspaceID)
	if err != nil {
		return err
	}

	// Check if user is a member
	if !roomspace.HasMember(userID) {
		return fmt.Errorf("user is not a member of this roomspace")
	}

	return nil
}
