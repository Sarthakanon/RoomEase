package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"roomease/backend/services"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestAnalyticsHandler_GetSummary_Unauthorized(t *testing.T) {
	// Setup
	gin.SetMode(gin.TestMode)
	
	// Create mock services (nil is ok for this test since we're testing auth)
	analyticsService := services.NewAnalyticsService(nil)
	handler := NewAnalyticsHandler(analyticsService, nil)
	
	// Create test router
	router := gin.New()
	router.GET("/api/analytics/summary", handler.GetSummary)
	
	// Create request without user_id in context
	req, _ := http.NewRequest("GET", "/api/analytics/summary", nil)
	w := httptest.NewRecorder()
	
	// Execute request
	router.ServeHTTP(w, req)
	
	// Assert
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	
	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "User not authenticated", response["error"])
}

func TestAnalyticsHandler_GetTrends_InvalidGroupBy(t *testing.T) {
	// Setup
	gin.SetMode(gin.TestMode)
	
	analyticsService := services.NewAnalyticsService(nil)
	handler := NewAnalyticsHandler(analyticsService, nil)
	
	// Create test router with middleware to set user_id
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "test-user-123")
		c.Next()
	})
	router.GET("/api/analytics/trends", handler.GetTrends)
	
	// Create request with invalid group_by parameter
	req, _ := http.NewRequest("GET", "/api/analytics/trends?group_by=invalid", nil)
	w := httptest.NewRecorder()
	
	// Execute request
	router.ServeHTTP(w, req)
	
	// Assert
	assert.Equal(t, http.StatusBadRequest, w.Code)
	
	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Contains(t, response["error"], "Invalid group_by parameter")
}

func TestAnalyticsHandler_GetPredictions_Unauthorized(t *testing.T) {
	// Setup
	gin.SetMode(gin.TestMode)
	
	analyticsService := services.NewAnalyticsService(nil)
	handler := NewAnalyticsHandler(analyticsService, nil)
	
	// Create test router
	router := gin.New()
	router.GET("/api/analytics/predictions", handler.GetPredictions)
	
	// Create request without user_id in context
	req, _ := http.NewRequest("GET", "/api/analytics/predictions", nil)
	w := httptest.NewRecorder()
	
	// Execute request
	router.ServeHTTP(w, req)
	
	// Assert
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestAnalyticsHandler_SubmitFeedback_InvalidFeedbackType(t *testing.T) {
	// Setup
	gin.SetMode(gin.TestMode)
	
	analyticsService := services.NewAnalyticsService(nil)
	handler := NewAnalyticsHandler(analyticsService, nil)
	
	// Create test router with middleware to set user_id
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "test-user-123")
		c.Next()
	})
	router.POST("/api/analytics/feedback", handler.SubmitFeedback)
	
	// Create request with missing body
	req, _ := http.NewRequest("POST", "/api/analytics/feedback", http.NoBody)
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	
	// Execute request - this will fail on binding, which is expected
	router.ServeHTTP(w, req)
	
	// Assert - should get bad request due to missing body
	assert.Equal(t, http.StatusBadRequest, w.Code)
}
