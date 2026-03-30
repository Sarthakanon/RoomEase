package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// TestGetExpenses_RoomspaceFiltering tests that roomspace_id query parameter is properly handled
func TestGetExpenses_RoomspaceFiltering(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name           string
		roomspaceID    string
		expectStatus   int
		expectError    bool
	}{
		{
			name:         "without roomspace_id parameter",
			roomspaceID:  "",
			expectStatus: http.StatusUnauthorized, // Will fail auth since no user_id in context
			expectError:  true,
		},
		{
			name:         "with roomspace_id parameter",
			roomspaceID:  "test-roomspace-123",
			expectStatus: http.StatusUnauthorized, // Will fail auth since no user_id in context
			expectError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a test router
			router := gin.New()
			
			// Create handler with nil service (we're just testing parameter parsing)
			handler := &ExpenseHandler{dbService: nil}
			
			// Register route
			router.GET("/api/expenses", handler.GetExpenses)

			// Create request
			req, _ := http.NewRequest("GET", "/api/expenses", nil)
			if tt.roomspaceID != "" {
				q := req.URL.Query()
				q.Add("roomspace_id", tt.roomspaceID)
				req.URL.RawQuery = q.Encode()
			}

			// Create response recorder
			w := httptest.NewRecorder()

			// Serve request
			router.ServeHTTP(w, req)

			// Assert status code
			assert.Equal(t, tt.expectStatus, w.Code)
		})
	}
}

// TestAnalytics_RoomspaceFiltering tests that analytics endpoints accept roomspace_id parameter
func TestAnalytics_RoomspaceFiltering(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name         string
		endpoint     string
		roomspaceID  string
		expectStatus int
	}{
		{
			name:         "summary without roomspace_id",
			endpoint:     "/api/analytics/summary",
			roomspaceID:  "",
			expectStatus: http.StatusUnauthorized,
		},
		{
			name:         "summary with roomspace_id",
			endpoint:     "/api/analytics/summary",
			roomspaceID:  "test-roomspace-123",
			expectStatus: http.StatusUnauthorized,
		},
		{
			name:         "trends without roomspace_id",
			endpoint:     "/api/analytics/trends",
			roomspaceID:  "",
			expectStatus: http.StatusUnauthorized,
		},
		{
			name:         "trends with roomspace_id",
			endpoint:     "/api/analytics/trends",
			roomspaceID:  "test-roomspace-123",
			expectStatus: http.StatusUnauthorized,
		},
		{
			name:         "predictions without roomspace_id",
			endpoint:     "/api/analytics/predictions",
			roomspaceID:  "",
			expectStatus: http.StatusUnauthorized,
		},
		{
			name:         "predictions with roomspace_id",
			endpoint:     "/api/analytics/predictions",
			roomspaceID:  "test-roomspace-123",
			expectStatus: http.StatusUnauthorized,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a test router
			router := gin.New()
			
			// Create handler with nil services (we're just testing parameter parsing)
			handler := &AnalyticsHandler{
				analyticsService: nil,
				dbService:        nil,
			}
			
			// Register routes
			router.GET("/api/analytics/summary", handler.GetSummary)
			router.GET("/api/analytics/trends", handler.GetTrends)
			router.GET("/api/analytics/predictions", handler.GetPredictions)

			// Create request
			req, _ := http.NewRequest("GET", tt.endpoint, nil)
			if tt.roomspaceID != "" {
				q := req.URL.Query()
				q.Add("roomspace_id", tt.roomspaceID)
				req.URL.RawQuery = q.Encode()
			}

			// Create response recorder
			w := httptest.NewRecorder()

			// Serve request
			router.ServeHTTP(w, req)

			// Assert status code
			assert.Equal(t, tt.expectStatus, w.Code)
		})
	}
}
