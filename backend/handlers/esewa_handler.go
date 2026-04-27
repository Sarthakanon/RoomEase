package handlers

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"roomease/backend/models"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

// EsewaHandler handles eSewa payment verification and processing
//
// Testing Environment:
// - Users will be redirected to: https://rc-epay.esewa.com.np/auth
// - Test credentials: eSewa ID: 9806800001-5, Password: Nepal@123, MPIN: 1122
type EsewaHandler struct {
	dbService *services.PostgresService
}

// NewEsewaHandler creates a new eSewa handler
func NewEsewaHandler(dbService *services.PostgresService) *EsewaHandler {
	return &EsewaHandler{
		dbService: dbService,
	}
}

// eSewa v2 test configuration
const (
	EsewaSecretKey    = "8gBm/:&EnhH.1/q"                                    // eSewa v2 test secret key
	EsewaMerchantCode = "EPAYTEST"                                           // eSewa test merchant code
	EsewaClientID     = "JB0BBQ4aD0UqIThFJwAKBgAXEUkEGQUBBAwdOgABHD4DChwUAB0R" // SDK client_id
	EsewaClientSecret = "BhwIWQQADhIYSxILExMcAgFXFhcOBwAKBgAXEQ=="             // SDK client_secret
	EsewaToken        = "123456"                                             // Test token
)

// SubscriptionPaymentRequest represents the subscription payment verification request
type SubscriptionPaymentRequest struct {
	PlanID           string                 `json:"plan_id" binding:"required"`
	TransactionUUID  string                 `json:"transaction_uuid" binding:"required"`
	TransactionCode  string                 `json:"transaction_code"`
	Amount           float64                `json:"amount" binding:"required"`
	EsewaResponse    map[string]interface{} `json:"esewa_response" binding:"required"`
}

// BalanceSettlementRequest represents the balance settlement verification request
type BalanceSettlementRequest struct {
	RoomspaceID      string                 `json:"roomspace_id" binding:"required"`
	RecipientUserID  string                 `json:"recipient_user_id" binding:"required"`
	Amount           float64                `json:"amount" binding:"required"`
	Description      string                 `json:"description"`
	TransactionUUID  string                 `json:"transaction_uuid" binding:"required"`
	TransactionCode  string                 `json:"transaction_code"`
	EsewaResponse    map[string]interface{} `json:"esewa_response" binding:"required"`
}

// VerifySubscriptionPayment verifies eSewa payment for subscription upgrade
func (h *EsewaHandler) VerifySubscriptionPayment(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req SubscriptionPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Log the request for debugging
	fmt.Printf("🔍 Subscription payment verification request: %+v\n", req)

	// Handle missing transaction code
	if req.TransactionCode == "" {
		// Try to extract from eSewa response
		if transactionCode, ok := req.EsewaResponse["transaction_code"].(string); ok && transactionCode != "" {
			req.TransactionCode = transactionCode
		} else if oid, ok := req.EsewaResponse["oid"].(string); ok && oid != "" {
			req.TransactionCode = oid
		} else {
			// Use transaction UUID as fallback
			req.TransactionCode = req.TransactionUUID
			fmt.Printf("⚠️ Using transaction UUID as transaction code: %s\n", req.TransactionCode)
		}
	}

	// Verify eSewa signature
	if !h.verifyEsewaSignature(req.EsewaResponse) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid eSewa signature",
		})
		return
	}

	// Verify transaction details
	status, ok := req.EsewaResponse["status"].(string)
	if !ok || status != "COMPLETE" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Transaction not completed",
		})
		return
	}

	totalAmountStr, ok := req.EsewaResponse["total_amount"].(string)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid total amount",
		})
		return
	}

	totalAmount, err := strconv.ParseFloat(totalAmountStr, 64)
	if err != nil || totalAmount != req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Amount mismatch",
		})
		return
	}

	// Create subscription payment record
	payment := &models.SubscriptionPayment{
		UserID:          userID.(string),
		PlanID:          req.PlanID,
		Amount:          req.Amount,
		TransactionUUID: req.TransactionUUID,
		TransactionCode: req.TransactionCode,
		PaymentMethod:   "esewa",
		Status:          "completed",
		EsewaResponse:   req.EsewaResponse,
		CreatedAt:       time.Now(),
	}

	if err := h.dbService.CreateSubscriptionPayment(payment); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to record payment",
		})
		return
	}

	// Update user subscription
	if err := h.dbService.UpdateUserSubscription(userID.(string), req.PlanID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update subscription",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Subscription payment verified and activated",
		"data": gin.H{
			"payment_id":       payment.ID,
			"transaction_uuid": payment.TransactionUUID,
			"plan_id":          payment.PlanID,
		},
	})
}

// VerifyBalanceSettlement verifies eSewa payment for balance settlement
func (h *EsewaHandler) VerifyBalanceSettlement(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req BalanceSettlementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Log the request for debugging
	fmt.Printf("🔍 Balance settlement verification request: %+v\n", req)

	// Handle missing transaction code
	if req.TransactionCode == "" {
		// Try to extract from eSewa response
		if transactionCode, ok := req.EsewaResponse["transaction_code"].(string); ok && transactionCode != "" {
			req.TransactionCode = transactionCode
		} else if oid, ok := req.EsewaResponse["oid"].(string); ok && oid != "" {
			req.TransactionCode = oid
		} else {
			// Use transaction UUID as fallback
			req.TransactionCode = req.TransactionUUID
			fmt.Printf("⚠️ Using transaction UUID as transaction code: %s\n", req.TransactionCode)
		}
	}

	// Verify eSewa signature
	if !h.verifyEsewaSignature(req.EsewaResponse) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid eSewa signature",
		})
		return
	}

	// Verify transaction details
	status, ok := req.EsewaResponse["status"].(string)
	if !ok || status != "COMPLETE" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Transaction not completed",
		})
		return
	}

	totalAmountStr, ok := req.EsewaResponse["total_amount"].(string)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid total amount",
		})
		return
	}

	totalAmount, err := strconv.ParseFloat(totalAmountStr, 64)
	if err != nil || totalAmount != req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Amount mismatch",
		})
		return
	}

	// Verify user is member of roomspace
	isMember, err := h.dbService.IsUserMemberOfRoomspace(userID.(string), req.RoomspaceID)
	if err != nil || !isMember {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "User is not a member of this roomspace",
		})
		return
	}

	// Create balance settlement record
	settlement := &models.BalanceSettlement{
		RoomspaceID:     req.RoomspaceID,
		PayerUserID:     userID.(string),
		RecipientUserID: req.RecipientUserID,
		Amount:          req.Amount,
		Description:     req.Description,
		TransactionUUID: req.TransactionUUID,
		TransactionCode: req.TransactionCode,
		PaymentMethod:   "esewa",
		Status:          "completed",
		EsewaResponse:   req.EsewaResponse,
		CreatedAt:       time.Now(),
	}

	if err := h.dbService.CreateBalanceSettlement(settlement); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to record settlement",
		})
		return
	}

	// Update balances
	if err := h.dbService.UpdateBalancesAfterSettlement(settlement); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update balances",
		})
		return
	}

	// Create notification for recipient
	recipientUser, _ := h.dbService.GetUserByFirebaseUID(req.RecipientUserID)
	payerUser, _ := h.dbService.GetUserByFirebaseUID(userID.(string))
	
	payerName := "Someone"
	if payerUser != nil {
		payerName = payerUser.Name
	}

	if recipientUser != nil {
		notification := &models.Notification{
			RecipientUID: req.RecipientUserID,
			Type:         models.NotificationTypePaymentReceived,
			Title:        "Payment Received",
			Message:      fmt.Sprintf("%s sent you ₹%.2f via eSewa", payerName, req.Amount),
			Data:         fmt.Sprintf(`{"settlement_id":"%s","amount":%.2f}`, settlement.ID.String(), req.Amount),
		}
		h.dbService.CreateNotification(notification)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Balance settlement verified and processed",
		"data": gin.H{
			"settlement_id":    settlement.ID,
			"transaction_uuid": settlement.TransactionUUID,
			"amount":           settlement.Amount,
		},
	})
}

// verifyEsewaSignature verifies the eSewa response signature
func (h *EsewaHandler) verifyEsewaSignature(esewaResponse map[string]interface{}) bool {
	signedFieldNames, ok := esewaResponse["signed_field_names"].(string)
	if !ok {
		return false
	}

	signature, ok := esewaResponse["signature"].(string)
	if !ok {
		return false
	}

	// Build message from signed fields
	fields := strings.Split(signedFieldNames, ",")
	var messageParts []string

	for _, fieldName := range fields {
		fieldName = strings.TrimSpace(fieldName)
		fieldValue, exists := esewaResponse[fieldName]
		if !exists {
			return false
		}
		messageParts = append(messageParts, fmt.Sprintf("%s=%v", fieldName, fieldValue))
	}

	message := strings.Join(messageParts, ",")

	// Generate HMAC-SHA256 signature
	key := []byte(EsewaSecretKey)
	hmacHash := hmac.New(sha256.New, key)
	hmacHash.Write([]byte(message))
	computedSignature := base64.StdEncoding.EncodeToString(hmacHash.Sum(nil))

	return computedSignature == signature
}

// GetPaymentHistory gets payment history for a user
func (h *EsewaHandler) GetPaymentHistory(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get query parameters
	paymentType := c.DefaultQuery("type", "all") // "subscription", "settlement", or "all"
	limit := 20
	offset := 0

	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	// Get payment history
	history, err := h.dbService.GetUserPaymentHistory(userID.(string), paymentType, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve payment history",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    history,
	})
}

// GetSettlementHistory gets settlement history for a roomspace
func (h *EsewaHandler) GetSettlementHistory(c *gin.Context) {
	// Get roomspace ID from URL
	roomspaceID := c.Param("id")

	// Get query parameters
	limit := 20
	offset := 0

	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	// Get settlement history
	settlements, err := h.dbService.GetRoomspaceSettlementHistory(roomspaceID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve settlement history",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    settlements,
	})
}