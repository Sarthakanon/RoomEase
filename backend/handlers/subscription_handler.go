package handlers

import (
	"net/http"
	"time"

	"roomease/backend/config"
	"roomease/backend/models"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

// SubscriptionHandler handles subscription-related requests
type SubscriptionHandler struct {
	dbService *services.PostgresService
}

// NewSubscriptionHandler creates a new subscription handler
func NewSubscriptionHandler(dbService *services.PostgresService) *SubscriptionHandler {
	return &SubscriptionHandler{
		dbService: dbService,
	}
}

// GetCurrentSubscription returns the current user's subscription
func (h *SubscriptionHandler) GetCurrentSubscription(c *gin.Context) {
	// Get user ID from context
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
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get user",
		})
		return
	}

	// Build subscription response
	subscription := gin.H{
		"id":         user.FirebaseUID,
		"user_id":    user.FirebaseUID,
		"plan":       user.SubscriptionPlan,
		"status":     "active",
		"start_date": user.CreatedAt,
		"end_date":   user.SubscriptionExpiry,
		"is_yearly":  false, // We don't track this yet
		"amount":     0.0,
		"created_at": user.CreatedAt,
		"updated_at": user.UpdatedAt,
	}

	// Check if subscription is expired
	if user.SubscriptionExpiry != nil && user.SubscriptionExpiry.Before(time.Now()) {
		subscription["status"] = "expired"
		// Downgrade to free if expired
		user.SubscriptionPlan = "free"
		user.SubscriptionExpiry = nil
		config.DB.Save(user)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    subscription,
	})
}

// CancelSubscription cancels the current user's subscription
func (h *SubscriptionHandler) CancelSubscription(c *gin.Context) {
	// Get user ID from context
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
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get user",
		})
		return
	}

	// Check if user has an active subscription
	if user.SubscriptionPlan == "free" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No active subscription to cancel",
		})
		return
	}

	// Set subscription to expire at the end of current period
	// If no expiry date, set it to end of current month
	if user.SubscriptionExpiry == nil {
		// Set expiry to end of current month
		now := time.Now()
		endOfMonth := time.Date(now.Year(), now.Month()+1, 0, 23, 59, 59, 0, now.Location())
		user.SubscriptionExpiry = &endOfMonth
	}

	// Save the user
	if err := config.DB.Save(user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to cancel subscription",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Subscription will be cancelled at the end of the current billing period",
		"data": gin.H{
			"plan":       user.SubscriptionPlan,
			"expires_at": user.SubscriptionExpiry,
		},
	})
}

// GetSubscriptionHistory returns the user's subscription history
func (h *SubscriptionHandler) GetSubscriptionHistory(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get subscription payments from database
	var payments []models.SubscriptionPayment
	if err := config.DB.Where("user_id = ?", userID.(string)).
		Order("created_at DESC").
		Find(&payments).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get subscription history",
		})
		return
	}

	// Convert to subscription history format
	history := make([]gin.H, 0, len(payments))
	for _, payment := range payments {
		history = append(history, gin.H{
			"id":               payment.ID,
			"user_id":          payment.UserID,
			"plan":             payment.PlanID,
			"status":           payment.Status,
			"amount":           payment.Amount,
			"transaction_uuid": payment.TransactionUUID,
			"transaction_code": payment.TransactionCode,
			"payment_method":   payment.PaymentMethod,
			"created_at":       payment.CreatedAt,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    history,
	})
}
