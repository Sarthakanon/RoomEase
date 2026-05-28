package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"roomease/backend/services"
	"roomease/backend/testutils"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidateRoomspaceMembership(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	RoomspaceService = services.NewPostgresService()
	t.Cleanup(func() { RoomspaceService = nil })

	tests := []struct {
		name       string
		userID     string
		roomspace  string
		wantStatus int
	}{
		{
			name:       "authenticated member can continue",
			userID:     fixtures.Member.FirebaseUID,
			roomspace:  fixtures.Roomspace.ID.String(),
			wantStatus: http.StatusOK,
		},
		{
			name:       "non-member is rejected",
			userID:     fixtures.Outsider.FirebaseUID,
			roomspace:  fixtures.Roomspace.ID.String(),
			wantStatus: http.StatusForbidden,
		},
		{
			name:       "missing roomspace id skips membership check",
			userID:     fixtures.Outsider.FirebaseUID,
			roomspace:  "",
			wantStatus: http.StatusOK,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := setupTestRouter()
			router.Use(func(c *gin.Context) {
				c.Set("user_id", tt.userID)
				c.Next()
			})
			router.GET("/roomspaces/:id/expenses", ValidateRoomspaceMembership(), func(c *gin.Context) {
				c.JSON(http.StatusOK, gin.H{"ok": true})
			})
			router.GET("/expenses", ValidateRoomspaceMembership(), func(c *gin.Context) {
				c.JSON(http.StatusOK, gin.H{"ok": true})
			})

			path := "/expenses"
			if tt.roomspace != "" {
				path = "/roomspaces/" + tt.roomspace + "/expenses"
			}
			req, _ := http.NewRequest(http.MethodGet, path, nil)
			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			assert.Equal(t, tt.wantStatus, w.Code)
		})
	}
}

func TestValidateRoomspaceMembership_Unauthenticated(t *testing.T) {
	router := setupTestRouter()
	router.GET("/roomspaces/:id/expenses", ValidateRoomspaceMembership(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	req, _ := http.NewRequest(http.MethodGet, "/roomspaces/room-1/expenses", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
	var response map[string]string
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &response))
	assert.Contains(t, response["error"], "User not authenticated")
}
