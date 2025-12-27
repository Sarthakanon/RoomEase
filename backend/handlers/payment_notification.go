package handlers

import (
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"

	"github.com/gin-gonic/gin"
)

type PaymentNotificationHandler struct {
	postgresService *services.PostgresService
}

func NewPaymentNotificationHandler(postgresService *services.PostgresService) *PaymentNotificationHandler {
	return &PaymentNotificationHandler{
		postgresService: postgresService,
	}
}

// CreatePaymentNotification creates a new payment notification
func (h *PaymentNotificationHandler) CreatePaymentNotification(c *gin.Context) {
	userUID := c.GetString("user_uid")
	if userUID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req models.PaymentNotificationCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	notification := &models.PaymentNotification{
		UserUID:   userUID,
		Amount:    req.Amount,
		Merchant:  req.Merchant,
		AppName:   req.AppName,
		RawText:   req.RawText,
		Type:      req.Type,
		Timestamp: req.Timestamp,
	}

	if err := h.postgresService.CreatePaymentNotification(notification); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	response := models.PaymentNotificationResponse{
		ID:          notification.ID,
		Amount:      notification.Amount,
		Merchant:    notification.Merchant,
		AppName:     notification.AppName,
		RawText:     notification.RawText,
		Type:        notification.Type,
		Timestamp:   notification.Timestamp,
		IsProcessed: notification.IsProcessed,
		ExpenseID:   notification.ExpenseID,
		CreatedAt:   notification.CreatedAt,
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    response,
	})
}

// GetPaymentNotifications gets payment notifications for the authenticated user
func (h *PaymentNotificationHandler) GetPaymentNotifications(c *gin.Context) {
	userUID := c.GetString("user_uid")
	if userUID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Parse query parameters
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid offset parameter"})
		return
	}

	notifications, err := h.postgresService.GetPaymentNotifications(userUID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Convert to response format
	var responses []models.PaymentNotificationResponse
	for _, notification := range notifications {
		responses = append(responses, models.PaymentNotificationResponse{
			ID:          notification.ID,
			Amount:      notification.Amount,
			Merchant:    notification.Merchant,
			AppName:     notification.AppName,
			RawText:     notification.RawText,
			Type:        notification.Type,
			Timestamp:   notification.Timestamp,
			IsProcessed: notification.IsProcessed,
			ExpenseID:   notification.ExpenseID,
			CreatedAt:   notification.CreatedAt,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// GetPaymentNotification gets a specific payment notification
func (h *PaymentNotificationHandler) GetPaymentNotification(c *gin.Context) {
	userUID := c.GetString("user_uid")
	if userUID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	notification, err := h.postgresService.GetPaymentNotificationByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	// Check if notification belongs to the user
	if notification.UserUID != userUID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
		return
	}

	response := models.PaymentNotificationResponse{
		ID:          notification.ID,
		Amount:      notification.Amount,
		Merchant:    notification.Merchant,
		AppName:     notification.AppName,
		RawText:     notification.RawText,
		Type:        notification.Type,
		Timestamp:   notification.Timestamp,
		IsProcessed: notification.IsProcessed,
		ExpenseID:   notification.ExpenseID,
		CreatedAt:   notification.CreatedAt,
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    response,
	})
}

// MarkPaymentNotificationAsProcessed marks a payment notification as processed
func (h *PaymentNotificationHandler) MarkPaymentNotificationAsProcessed(c *gin.Context) {
	userUID := c.GetString("user_uid")
	if userUID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	// Check if notification exists and belongs to user
	notification, err := h.postgresService.GetPaymentNotificationByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	if notification.UserUID != userUID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
		return
	}

	// Parse request body for optional expense ID
	var req struct {
		ExpenseID *uint `json:"expense_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		// If no body provided, just mark as processed without expense ID
		req.ExpenseID = nil
	}

	if err := h.postgresService.MarkPaymentNotificationAsProcessed(uint(id), req.ExpenseID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Payment notification marked as processed",
	})
}

// DeletePaymentNotification deletes a payment notification
func (h *PaymentNotificationHandler) DeletePaymentNotification(c *gin.Context) {
	userUID := c.GetString("user_uid")
	if userUID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	// Check if notification exists and belongs to user
	notification, err := h.postgresService.GetPaymentNotificationByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	if notification.UserUID != userUID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied"})
		return
	}

	if err := h.postgresService.DeletePaymentNotification(uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Payment notification deleted successfully",
	})
}