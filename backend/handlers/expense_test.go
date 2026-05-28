package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"roomease/backend/models"
	"roomease/backend/services"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestExpenseHandler_validateExpenseRequest(t *testing.T) {
	handler := &ExpenseHandler{}

	tests := []struct {
		name    string
		req     *models.CreateExpenseRequest
		wantErr bool
		errMsg  string
	}{
		{
			name: "valid equal split",
			req: &models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         models.SplitTypeEqual,
				SelectedRoommates: []string{"user1", "user2"},
			},
			wantErr: false,
		},
		{
			name: "valid percentage split",
			req: &models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         models.SplitTypePercentage,
				SelectedRoommates: []string{"user1", "user2"},
				CustomSplits:      map[string]float64{"user1": 60.0, "user2": 40.0},
			},
			wantErr: false,
		},
		{
			name: "valid exact split",
			req: &models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         models.SplitTypeExact,
				SelectedRoommates: []string{"user1", "user2"},
				CustomSplits:      map[string]float64{"user1": 60.0, "user2": 40.0},
			},
			wantErr: false,
		},
		{
			name: "invalid percentage split - doesn't sum to 100",
			req: &models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         models.SplitTypePercentage,
				SelectedRoommates: []string{"user1", "user2"},
				CustomSplits:      map[string]float64{"user1": 60.0, "user2": 30.0},
			},
			wantErr: true,
			errMsg:  "percentage splits must total exactly 100%",
		},
		{
			name: "invalid exact split - doesn't sum to total",
			req: &models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         models.SplitTypeExact,
				SelectedRoommates: []string{"user1", "user2"},
				CustomSplits:      map[string]float64{"user1": 60.0, "user2": 30.0},
			},
			wantErr: true,
			errMsg:  "split amounts must total the expense amount",
		},
		{
			name: "no selected roommates",
			req: &models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         models.SplitTypeEqual,
				SelectedRoommates: []string{},
			},
			wantErr: true,
			errMsg:  "at least one roommate must be selected",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := handler.validateExpenseRequest(tt.req)
			if tt.wantErr {
				assert.Error(t, err)
				if tt.errMsg != "" {
					assert.Contains(t, err.Error(), tt.errMsg)
				}
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestExpenseHandler_calculateSplits(t *testing.T) {
	handler := &ExpenseHandler{}

	tests := []struct {
		name     string
		req      *models.CreateExpenseRequest
		payerUID string
		want     int // number of splits expected
	}{
		{
			name: "equal split calculation",
			req: &models.CreateExpenseRequest{
				Amount:            100.0,
				SplitType:         models.SplitTypeEqual,
				SelectedRoommates: []string{"user1", "user2"},
			},
			payerUID: "payer",
			want:     3,
		},
		{
			name: "percentage split calculation",
			req: &models.CreateExpenseRequest{
				Amount:       100.0,
				SplitType:    models.SplitTypePercentage,
				CustomSplits: map[string]float64{"user1": 60.0, "user2": 40.0},
			},
			payerUID: "payer",
			want:     2,
		},
		{
			name: "exact split calculation",
			req: &models.CreateExpenseRequest{
				Amount:       100.0,
				SplitType:    models.SplitTypeExact,
				CustomSplits: map[string]float64{"user1": 60.0, "user2": 40.0},
			},
			payerUID: "payer",
			want:     2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			splits, err := handler.calculateSplits(tt.req, tt.payerUID)
			assert.NoError(t, err)
			assert.Len(t, splits, tt.want)

			// Verify total amounts
			total := 0.0
			for _, split := range splits {
				total += split.Amount
				assert.Greater(t, split.Amount, 0.0)
			}
			assert.InDelta(t, tt.req.Amount, total, 0.01) // Allow small rounding differences
		})
	}
}

func TestExpenseHandler_CreateExpense_ValidationErrors(t *testing.T) {
	gin.SetMode(gin.TestMode)

	// Create handler with real service (we'll test validation logic only)
	handler := &ExpenseHandler{dbService: services.NewPostgresService()}

	tests := []struct {
		name           string
		requestBody    interface{}
		expectedStatus int
		expectedError  string
	}{
		{
			name:           "invalid JSON",
			requestBody:    `{"invalid": json}`,
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Invalid request body",
		},
		{
			name: "missing required fields",
			requestBody: models.CreateExpenseRequest{
				Title: "Test",
				// Missing required fields
			},
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Invalid request body",
		},
		{
			name: "invalid split type",
			requestBody: models.CreateExpenseRequest{
				RoomspaceID:       "1",
				Title:             "Test Expense",
				Amount:            100.0,
				Category:          "Food",
				SplitType:         "INVALID",
				SelectedRoommates: []string{"user1", "user2"},
			},
			expectedStatus: http.StatusBadRequest,
			expectedError:  "invalid split type",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create request
			var body bytes.Buffer
			if str, ok := tt.requestBody.(string); ok {
				body.WriteString(str)
			} else {
				json.NewEncoder(&body).Encode(tt.requestBody)
			}

			req, _ := http.NewRequest("POST", "/api/expenses", &body)
			req.Header.Set("Content-Type", "application/json")

			// Create response recorder
			w := httptest.NewRecorder()

			// Create gin context
			c, _ := gin.CreateTestContext(w)
			c.Request = req
			c.Set("user_id", "test-user-uid")

			// Call handler
			handler.CreateExpense(c)

			// Assert response
			assert.Equal(t, tt.expectedStatus, w.Code)

			var response map[string]interface{}
			json.Unmarshal(w.Body.Bytes(), &response)

			if tt.expectedError != "" {
				assert.Contains(t, response["error"].(string), tt.expectedError)
			}
		})
	}
}
