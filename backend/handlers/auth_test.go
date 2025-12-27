package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"roomease/backend/models"
	"roomease/backend/services"
)

// Test setup
func setupTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	return router
}

func TestAuthHandler_Login_MissingToken(t *testing.T) {
	// Setup
	sessionStore := services.NewInMemorySessionStore()
	handler := NewAuthHandler(sessionStore, nil)

	// Setup request without token
	router := setupTestRouter()
	router.POST("/auth/login", handler.Login)

	loginReq := map[string]string{} // Empty request
	jsonData, _ := json.Marshal(loginReq)

	req, _ := http.NewRequest("POST", "/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusBadRequest, w.Code)
	
	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Invalid request body", response["error"])
}

func TestAuthHandler_Login_EmptyToken(t *testing.T) {
	// Setup
	sessionStore := services.NewInMemorySessionStore()
	handler := NewAuthHandler(sessionStore, nil)

	// Setup request with empty token
	router := setupTestRouter()
	router.POST("/auth/login", handler.Login)

	loginReq := LoginRequest{
		FirebaseToken: "",
	}
	jsonData, _ := json.Marshal(loginReq)

	req, _ := http.NewRequest("POST", "/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions - should return 400 for empty token (binding validation)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	
	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Invalid request body", response["error"])
}

func TestAuthHandler_Logout_NoSession(t *testing.T) {
	// Setup
	sessionStore := services.NewInMemorySessionStore()
	handler := NewAuthHandler(sessionStore, nil)

	// Setup request without session in context
	router := setupTestRouter()
	router.POST("/auth/logout", handler.Logout)

	req, _ := http.NewRequest("POST", "/auth/logout", nil)
	
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	
	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "No active session", response["error"])
}

func TestAuthHandler_Verify_NoSession(t *testing.T) {
	// Setup
	sessionStore := services.NewInMemorySessionStore()
	handler := NewAuthHandler(sessionStore, nil)

	// Setup request without user info in context
	router := setupTestRouter()
	router.GET("/auth/verify", handler.Verify)

	req, _ := http.NewRequest("GET", "/auth/verify", nil)
	
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusOK, w.Code)
	
	var response VerifyResponse
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.False(t, response.Valid)
	assert.Empty(t, response.UserID)
	assert.Empty(t, response.Email)
}

func TestAuthHandler_Refresh_NoSession(t *testing.T) {
	// Setup
	sessionStore := services.NewInMemorySessionStore()
	handler := NewAuthHandler(sessionStore, nil)

	// Setup request without session in context
	router := setupTestRouter()
	router.POST("/auth/refresh", handler.Refresh)

	req, _ := http.NewRequest("POST", "/auth/refresh", nil)
	
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Assertions
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	
	var response map[string]string
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "No active session", response["error"])
}

func TestSessionStore_Integration(t *testing.T) {
	// Test that session store works correctly
	sessionStore := services.NewInMemorySessionStore()
	
	// Create a test session with proper expiry
	session := &models.Session{
		ID:        "test-session-123",
		UserID:    "test-user-456",
		Email:     "test@example.com",
		ExpiresAt: time.Now().Add(24 * time.Hour), // Valid for 24 hours
		CreatedAt: time.Now(),
	}
	
	// Test Create
	err := sessionStore.Create(session)
	assert.NoError(t, err)
	
	// Test Get
	retrievedSession, err := sessionStore.Get("test-session-123")
	assert.NoError(t, err)
	assert.Equal(t, session.ID, retrievedSession.ID)
	assert.Equal(t, session.UserID, retrievedSession.UserID)
	assert.Equal(t, session.Email, retrievedSession.Email)
	
	// Test Delete
	err = sessionStore.Delete("test-session-123")
	assert.NoError(t, err)
	
	// Test Get after delete
	_, err = sessionStore.Get("test-session-123")
	assert.Error(t, err)
}

func TestGenerateSessionID(t *testing.T) {
	// Test session ID generation
	sessionID1, err1 := services.GenerateSessionID()
	assert.NoError(t, err1)
	assert.NotEmpty(t, sessionID1)
	assert.Len(t, sessionID1, 64) // 32 bytes = 64 hex characters
	
	sessionID2, err2 := services.GenerateSessionID()
	assert.NoError(t, err2)
	assert.NotEmpty(t, sessionID2)
	assert.NotEqual(t, sessionID1, sessionID2) // Should be unique
}

func TestLoginRequest_Validation(t *testing.T) {
	// Test various login request scenarios
	tests := []struct {
		name           string
		requestBody    interface{}
		expectedStatus int
		expectedError  string
	}{
		{
			name:           "Missing firebase_token field",
			requestBody:    map[string]string{},
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Invalid request body",
		},
		{
			name:           "Empty firebase_token",
			requestBody:    LoginRequest{FirebaseToken: ""},
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Invalid request body",
		},
		{
			name:           "Invalid JSON",
			requestBody:    "invalid-json",
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Invalid request body",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sessionStore := services.NewInMemorySessionStore()
			handler := NewAuthHandler(sessionStore, nil)

			router := setupTestRouter()
			router.POST("/auth/login", handler.Login)

			var jsonData []byte
			var err error
			
			if str, ok := tt.requestBody.(string); ok {
				jsonData = []byte(str)
			} else {
				jsonData, err = json.Marshal(tt.requestBody)
				assert.NoError(t, err)
			}

			req, _ := http.NewRequest("POST", "/auth/login", bytes.NewBuffer(jsonData))
			req.Header.Set("Content-Type", "application/json")
			
			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			assert.Equal(t, tt.expectedStatus, w.Code)
			
			if tt.expectedError != "" {
				var response map[string]string
				err := json.Unmarshal(w.Body.Bytes(), &response)
				assert.NoError(t, err)
				assert.Equal(t, tt.expectedError, response["error"])
			}
		})
	}
}

func TestResponseStructures(t *testing.T) {
	// Test that response structures marshal correctly
	t.Run("LoginResponse", func(t *testing.T) {
		response := LoginResponse{
			UserID:    "test-user-123",
			Email:     "test@example.com",
			SessionID: "session-456",
		}
		
		jsonData, err := json.Marshal(response)
		assert.NoError(t, err)
		assert.Contains(t, string(jsonData), "test-user-123")
		assert.Contains(t, string(jsonData), "test@example.com")
		assert.Contains(t, string(jsonData), "session-456")
	})
	
	t.Run("VerifyResponse", func(t *testing.T) {
		response := VerifyResponse{
			Valid:  true,
			UserID: "test-user-123",
			Email:  "test@example.com",
		}
		
		jsonData, err := json.Marshal(response)
		assert.NoError(t, err)
		assert.Contains(t, string(jsonData), "true")
		assert.Contains(t, string(jsonData), "test-user-123")
	})
}