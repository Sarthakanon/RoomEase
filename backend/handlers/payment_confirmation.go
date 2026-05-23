package handlers

import (
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// PaymentConfirmationHandler handles payment confirmation requests
type PaymentConfirmationHandler struct {
	paymentService *services.PaymentConfirmationService
	dbService      *services.PostgresService
}

// NewPaymentConfirmationHandler creates a new payment confirmation handler
func NewPaymentConfirmationHandler(paymentService *services.PaymentConfirmationService, dbService *services.PostgresService) *PaymentConfirmationHandler {
	return &PaymentConfirmationHandler{
		paymentService: paymentService,
		dbService:      dbService,
	}
}

// CreatePaymentConfirmation creates a new payment confirmation claim
// POST /api/roomspaces/:id/payments/confirm
func (h *PaymentConfirmationHandler) CreatePaymentConfirmation(c *gin.Context) {
	roomspaceID := c.Param("id")

	// Get authenticated user ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Parse request body
	var req models.PaymentConfirmationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Create payment confirmation
	payment := &models.PaymentConfirmation{
		RoomspaceID:     roomspaceID,
		FromUserID:      userID.(string),
		ToUserID:        req.ToUserID,
		Amount:          req.Amount,
		PaymentType:     req.PaymentType,
		Notes:           req.Notes,
		PaymentProofURL: req.PaymentProofURL,
		PaymentDate:     req.PaymentDate,
	}

	if err := h.paymentService.CreatePaymentConfirmation(payment); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Failed to create payment confirmation",
			"details": err.Error(),
		})
		return
	}

	// Build response
	response := h.buildPaymentResponse(payment)

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Payment confirmation created successfully",
		"data":    response,
	})
}

// ConfirmPayment confirms a payment (recipient confirms they received payment)
// PUT /api/roomspaces/:id/payments/:paymentId/confirm
func (h *PaymentConfirmationHandler) ConfirmPayment(c *gin.Context) {
	roomspaceID := c.Param("id")
	paymentIDStr := c.Param("paymentId")

	// Get authenticated user ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Parse payment ID
	paymentID, err := strconv.ParseUint(paymentIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payment ID"})
		return
	}

	// Confirm payment
	payment, err := h.paymentService.ConfirmPayment(uint(paymentID), userID.(string))
	if err != nil {
		statusCode := http.StatusInternalServerError
		if err == models.ErrUnauthorized {
			statusCode = http.StatusForbidden
		} else if err == models.ErrAlreadyConfirmed || err == models.ErrAlreadyRejected {
			statusCode = http.StatusBadRequest
		}

		c.JSON(statusCode, gin.H{
			"error":   "Failed to confirm payment",
			"details": err.Error(),
		})
		return
	}

	// Verify payment belongs to this roomspace
	if payment.RoomspaceID != roomspaceID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Payment does not belong to this roomspace"})
		return
	}

	// Build response
	response := h.buildPaymentResponse(payment)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Payment confirmed successfully",
		"data":    response,
	})
}

// RejectPayment rejects a payment claim
// PUT /api/roomspaces/:id/payments/:paymentId/reject
func (h *PaymentConfirmationHandler) RejectPayment(c *gin.Context) {
	roomspaceID := c.Param("id")
	paymentIDStr := c.Param("paymentId")

	// Get authenticated user ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Parse payment ID
	paymentID, err := strconv.ParseUint(paymentIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payment ID"})
		return
	}

	// Parse request body (optional reason)
	var req models.PaymentConfirmActionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Reason is optional, so ignore binding errors
		req.Reason = ""
	}

	// Reject payment
	payment, err := h.paymentService.RejectPayment(uint(paymentID), userID.(string), req.Reason)
	if err != nil {
		statusCode := http.StatusInternalServerError
		if err == models.ErrUnauthorized {
			statusCode = http.StatusForbidden
		} else if err == models.ErrAlreadyConfirmed || err == models.ErrAlreadyRejected {
			statusCode = http.StatusBadRequest
		}

		c.JSON(statusCode, gin.H{
			"error":   "Failed to reject payment",
			"details": err.Error(),
		})
		return
	}

	// Verify payment belongs to this roomspace
	if payment.RoomspaceID != roomspaceID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Payment does not belong to this roomspace"})
		return
	}

	// Build response
	response := h.buildPaymentResponse(payment)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Payment rejected",
		"data":    response,
	})
}

// GetPendingConfirmations gets pending payment confirmations
// GET /api/roomspaces/:id/payments/pending
func (h *PaymentConfirmationHandler) GetPendingConfirmations(c *gin.Context) {
	roomspaceID := c.Param("id")

	// Get authenticated user ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Get pending confirmations
	payments, err := h.paymentService.GetPendingConfirmations(roomspaceID, userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get pending confirmations",
			"details": err.Error(),
		})
		return
	}

	// Build responses
	responses := make([]models.PaymentConfirmationResponse, len(payments))
	for i, payment := range payments {
		responses[i] = h.buildPaymentResponse(&payment)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// GetPaymentHistory gets payment history with filters
// GET /api/roomspaces/:id/payments/history
func (h *PaymentConfirmationHandler) GetPaymentHistory(c *gin.Context) {
	roomspaceID := c.Param("id")

	// Get authenticated user ID
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Parse query parameters
	filter := models.PaymentHistoryFilter{
		RoomspaceID: roomspaceID,
		Limit:       20,
		Offset:      0,
	}

	// Optional user filter
	if userFilter := c.Query("user_id"); userFilter != "" {
		filter.UserID = userFilter
	}

	// Optional status filter
	if statusFilter := c.Query("status"); statusFilter != "" {
		filter.Status = models.PaymentStatus(statusFilter)
	}

	// Optional pagination
	if limitStr := c.Query("limit"); limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil {
			filter.Limit = limit
		}
	}
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if offset, err := strconv.Atoi(offsetStr); err == nil {
			filter.Offset = offset
		}
	}

	// Optional date range
	if startDateStr := c.Query("start_date"); startDateStr != "" {
		if startDate, err := time.Parse(time.RFC3339, startDateStr); err == nil {
			filter.StartDate = &startDate
		}
	}
	if endDateStr := c.Query("end_date"); endDateStr != "" {
		if endDate, err := time.Parse(time.RFC3339, endDateStr); err == nil {
			filter.EndDate = &endDate
		}
	}

	// Get payment history
	payments, err := h.paymentService.GetPaymentHistory(filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get payment history",
			"details": err.Error(),
		})
		return
	}

	// Build responses
	responses := make([]models.PaymentConfirmationResponse, len(payments))
	for i, payment := range payments {
		responses[i] = h.buildPaymentResponse(&payment)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// GetPaymentStats gets payment statistics for a roomspace
// GET /api/roomspaces/:id/payments/stats
func (h *PaymentConfirmationHandler) GetPaymentStats(c *gin.Context) {
	roomspaceID := c.Param("id")

	// Get authenticated user ID
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Get payment stats
	stats, err := h.paymentService.GetPaymentStats(roomspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get payment stats",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    stats,
	})
}

// buildPaymentResponse builds a payment confirmation response
func (h *PaymentConfirmationHandler) buildPaymentResponse(payment *models.PaymentConfirmation) models.PaymentConfirmationResponse {
	response := models.PaymentConfirmationResponse{
		ID:              payment.ID,
		RoomspaceID:     payment.RoomspaceID,
		FromUserID:      payment.FromUserID,
		ToUserID:        payment.ToUserID,
		Amount:          payment.Amount,
		PaymentType:     payment.PaymentType,
		Status:          payment.Status,
		Notes:           payment.Notes,
		PaymentProofURL: payment.PaymentProofURL,
		PaymentDate:     payment.PaymentDate,
		ConfirmedAt:     payment.ConfirmedAt,
		RejectionReason: payment.RejectionReason,
		CreatedAt:       payment.CreatedAt,
		UpdatedAt:       payment.UpdatedAt,
	}

	// Add user names if available
	if payment.FromUser != nil {
		response.FromUserName = payment.FromUser.Name
	}
	if payment.ToUser != nil {
		response.ToUserName = payment.ToUser.Name
	}

	return response
}
