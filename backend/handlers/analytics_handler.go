package handlers

import (
	"fmt"
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"time"

	"github.com/gin-gonic/gin"
)

// AnalyticsHandler handles analytics-related requests
type AnalyticsHandler struct {
	analyticsService *services.AnalyticsService
	dbService        *services.PostgresService
}

// NewAnalyticsHandler creates a new analytics handler
func NewAnalyticsHandler(analyticsService *services.AnalyticsService, dbService *services.PostgresService) *AnalyticsHandler {
	return &AnalyticsHandler{
		analyticsService: analyticsService,
		dbService:        dbService,
	}
}

// GetSummary handles GET /api/analytics/summary
// Returns spending summary with key metrics
func (h *AnalyticsHandler) GetSummary(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	roomspaceID := c.Query("roomspace_id")
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Default to last 30 days if not specified
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)

	// Parse custom date range if provided
	if startDateStr != "" {
		parsed, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid start_date format. Use YYYY-MM-DD",
			})
			return
		}
		startDate = parsed
	}

	if endDateStr != "" {
		parsed, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid end_date format. Use YYYY-MM-DD",
			})
			return
		}
		endDate = parsed
	}

	// Get roomspace ID pointer if provided
	var roomspaceIDPtr *string
	if roomspaceID != "" {
		roomspaceIDPtr = &roomspaceID
	}

	// Get spending summary
	summary, err := h.analyticsService.GetSpendingSummary(userID.(string), roomspaceIDPtr, startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get spending summary",
			"details": err.Error(),
		})
		return
	}

	// Get predictions to populate predicted_next_month
	predictions, err := h.analyticsService.GetSpendingPredictions(userID.(string), roomspaceIDPtr)
	if err == nil && !predictions.InsufficientData {
		totalPredicted := 0.0
		for _, pred := range predictions.Predictions {
			totalPredicted += pred.PredictedAmount
		}
		summary.PredictedNextMonth = totalPredicted
	}

	// Get recommendations to populate savings_potential
	recommendations, err := h.analyticsService.GetBudgetRecommendations(userID.(string), roomspaceIDPtr)
	if err == nil {
		totalSavings := 0.0
		for _, rec := range recommendations {
			totalSavings += rec.PotentialSavings
		}
		summary.SavingsPotential = totalSavings
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    summary,
	})
}

// GetTrends handles GET /api/analytics/trends
// Returns spending trends over time
func (h *AnalyticsHandler) GetTrends(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	roomspaceID := c.Query("roomspace_id")
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")
	groupBy := c.DefaultQuery("group_by", "day") // day, week, month

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Validate group_by parameter
	if groupBy != "day" && groupBy != "week" && groupBy != "month" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid group_by parameter. Must be 'day', 'week', or 'month'",
		})
		return
	}

	// Default to last 30 days if not specified
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)

	// Parse custom date range if provided
	if startDateStr != "" {
		parsed, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid start_date format. Use YYYY-MM-DD",
			})
			return
		}
		startDate = parsed
	}

	if endDateStr != "" {
		parsed, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid end_date format. Use YYYY-MM-DD",
			})
			return
		}
		endDate = parsed
	}

	// Get roomspace ID pointer if provided
	var roomspaceIDPtr *string
	if roomspaceID != "" {
		roomspaceIDPtr = &roomspaceID
	}

	// Get expense history
	trends, err := h.analyticsService.GetExpenseHistory(userID.(string), roomspaceIDPtr, startDate, endDate, groupBy)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get spending trends",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"trends":     trends,
			"group_by":   groupBy,
			"start_date": startDate.Format("2006-01-02"),
			"end_date":   endDate.Format("2006-01-02"),
		},
	})
}

// GetPredictions handles GET /api/analytics/predictions
// Returns spending predictions for next month
func (h *AnalyticsHandler) GetPredictions(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	roomspaceID := c.Query("roomspace_id")

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Get roomspace ID pointer if provided
	var roomspaceIDPtr *string
	if roomspaceID != "" {
		roomspaceIDPtr = &roomspaceID
	}

	// Get spending predictions
	predictions, err := h.analyticsService.GetSpendingPredictions(userID.(string), roomspaceIDPtr)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get spending predictions",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    predictions,
	})
}

// GetPatterns handles GET /api/analytics/patterns
// Returns identified spending patterns
func (h *AnalyticsHandler) GetPatterns(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	roomspaceID := c.Query("roomspace_id")

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Get roomspace ID pointer if provided
	var roomspaceIDPtr *string
	if roomspaceID != "" {
		roomspaceIDPtr = &roomspaceID
	}

	// Get category breakdown which shows spending patterns
	startDate := time.Now().AddDate(0, 0, -60) // Last 60 days
	endDate := time.Now()

	categoryBreakdown, err := h.analyticsService.GetCategoryBreakdown(userID.(string), roomspaceIDPtr, startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get spending patterns",
			"details": err.Error(),
		})
		return
	}

	// Convert category breakdown to pattern format
	// For now, we'll classify based on frequency and amount
	var patterns []map[string]interface{}
	for _, cat := range categoryBreakdown {
		// Estimate pattern type based on count
		patternType := "irregular"
		if cat.Count >= 20 {
			patternType = "daily"
		} else if cat.Count >= 8 {
			patternType = "weekly"
		} else if cat.Count >= 2 {
			patternType = "monthly"
		}

		pattern := map[string]interface{}{
			"category":       cat.Category,
			"pattern_type":   patternType,
			"average_amount": cat.Amount / float64(cat.Count),
			"frequency":      cat.Count,
			"total_amount":   cat.Amount,
		}
		patterns = append(patterns, pattern)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"patterns":   patterns,
			"start_date": startDate.Format("2006-01-02"),
			"end_date":   endDate.Format("2006-01-02"),
		},
	})
}

// GetAnomalies handles GET /api/analytics/anomalies
// Returns detected spending anomalies
func (h *AnalyticsHandler) GetAnomalies(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	roomspaceID := c.Query("roomspace_id")

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Get roomspace ID pointer if provided
	var roomspaceIDPtr *string
	if roomspaceID != "" {
		roomspaceIDPtr = &roomspaceID
	}

	// Detect anomalies
	anomalies, err := h.analyticsService.DetectAnomalies(userID.(string), roomspaceIDPtr)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to detect anomalies",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"anomalies": anomalies,
			"count":     len(anomalies),
		},
	})
}

// GetRecommendations handles GET /api/analytics/recommendations
// Returns AI-generated budget recommendations
func (h *AnalyticsHandler) GetRecommendations(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	roomspaceID := c.Query("roomspace_id")

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Get roomspace ID pointer if provided
	var roomspaceIDPtr *string
	if roomspaceID != "" {
		roomspaceIDPtr = &roomspaceID
	}

	// Get budget recommendations
	recommendations, err := h.analyticsService.GetBudgetRecommendations(userID.(string), roomspaceIDPtr)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get recommendations",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"recommendations": recommendations,
			"count":           len(recommendations),
		},
	})
}

// GetRoomspaceAnalytics handles GET /api/analytics/roomspace/:id
// Returns analytics for a specific roomspace
func (h *AnalyticsHandler) GetRoomspaceAnalytics(c *gin.Context) {
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

	// Parse query parameters for date range
	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	// Default to last 30 days if not specified
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)

	// Parse custom date range if provided
	if startDateStr != "" {
		parsed, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid start_date format. Use YYYY-MM-DD",
			})
			return
		}
		startDate = parsed
	}

	if endDateStr != "" {
		parsed, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid end_date format. Use YYYY-MM-DD",
			})
			return
		}
		endDate = parsed
	}

	// Get roomspace analytics
	analytics, err := h.analyticsService.GetRoomspaceAnalytics(roomspaceID, startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get roomspace analytics",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    analytics,
	})
}

// SubmitFeedback handles POST /api/analytics/feedback
// Submits user feedback on recommendations
func (h *AnalyticsHandler) SubmitFeedback(c *gin.Context) {
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
		RecommendationID string `json:"recommendation_id" binding:"required"`
		FeedbackType     string `json:"feedback_type" binding:"required"` // 'helpful', 'not_helpful', 'applied'
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Validate feedback type
	validTypes := map[string]bool{
		"helpful":     true,
		"not_helpful": true,
		"applied":     true,
	}

	if !validTypes[req.FeedbackType] {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid feedback_type. Must be 'helpful', 'not_helpful', or 'applied'",
		})
		return
	}

	// Create feedback record
	feedback := &models.RecommendationFeedback{
		UserID:           userID.(string),
		RecommendationID: req.RecommendationID,
		FeedbackType:     req.FeedbackType,
	}

	// Save feedback to database
	if err := h.dbService.CreateRecommendationFeedback(feedback); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to save feedback",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Feedback submitted successfully",
		"data":    feedback,
	})
}

// Helper functions

// verifyRoomspaceMembership checks if user is a member of the roomspace
func (h *AnalyticsHandler) verifyRoomspaceMembership(roomspaceID string, userUID string) error {
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
