package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"roomease/backend/config"
	"roomease/backend/models"
	"roomease/backend/services"
	"roomease/backend/testutils"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestExpenseHandler_DBCreateDeleteAndIsolation(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	service := services.NewPostgresService()
	handler := NewExpenseHandler(service)

	router := gin.New()
	router.Use(withTestUser(fixtures.Creator.FirebaseUID))
	router.POST("/expenses", handler.CreateExpense)
	router.GET("/roomspaces/:id/expenses/recent", handler.GetRecentExpenses)
	router.DELETE("/expenses/:id", handler.DeleteExpense)

	body := map[string]interface{}{
		"roomspace_id":       fixtures.Roomspace.ID.String(),
		"title":              "Handler Dinner",
		"amount":             200.0,
		"category":           "Food",
		"paid_by":            fixtures.Creator.FirebaseUID,
		"split_type":         models.SplitTypeEqual,
		"selected_roommates": []string{fixtures.Creator.FirebaseUID, fixtures.Member.FirebaseUID},
	}
	w := performJSON(router, http.MethodPost, "/expenses", body)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())

	var createdResponse map[string]interface{}
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &createdResponse))
	data := createdResponse["data"].(map[string]interface{})
	createdID := uint(data["id"].(float64))

	var created models.Expense
	require.NoError(t, db.Preload("Splits").First(&created, createdID).Error)
	assert.Equal(t, "Handler Dinner", created.Title)
	assert.Len(t, created.Splits, 2)

	recent := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/roomspaces/"+fixtures.Roomspace.ID.String()+"/expenses/recent?limit=10", nil)
	router.ServeHTTP(recent, req)
	require.Equal(t, http.StatusOK, recent.Code, recent.Body.String())
	assert.NotContains(t, recent.Body.String(), "Deleted Expense")
	assert.NotContains(t, recent.Body.String(), "Other Room Expense")

	deleted := httptest.NewRecorder()
	req, _ = http.NewRequest(http.MethodDelete, fmt.Sprintf("/expenses/%d", createdID), nil)
	router.ServeHTTP(deleted, req)
	require.Equal(t, http.StatusOK, deleted.Code, deleted.Body.String())

	var deletedExpense models.Expense
	require.NoError(t, db.Unscoped().First(&deletedExpense, createdID).Error)
	assert.True(t, deletedExpense.DeletedAt.Valid)
}

func TestExpenseHandler_DBRejectsUnauthorizedRoomspace(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	handler := NewExpenseHandler(services.NewPostgresService())

	router := gin.New()
	router.Use(withTestUser(fixtures.Member.FirebaseUID))
	router.POST("/expenses", handler.CreateExpense)

	body := map[string]interface{}{
		"roomspace_id":       fixtures.OtherRoomspace.ID.String(),
		"title":              "No Access Expense",
		"amount":             100.0,
		"category":           "Food",
		"split_type":         models.SplitTypeEqual,
		"selected_roommates": []string{fixtures.Member.FirebaseUID, fixtures.Outsider.FirebaseUID},
	}
	w := performJSON(router, http.MethodPost, "/expenses", body)

	assert.Equal(t, http.StatusForbidden, w.Code)
	assert.Contains(t, w.Body.String(), "not a member")
}

func TestNotificationHandler_DBListReadAndProcessJoinRequest(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	handler := NewNotificationHandler(services.NewPostgresService())

	memberRouter := gin.New()
	memberRouter.Use(withTestUser(fixtures.Member.FirebaseUID))
	memberRouter.GET("/notifications", handler.GetNotifications)
	memberRouter.PUT("/notifications/:id/read", handler.MarkAsRead)

	list := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/notifications", nil)
	memberRouter.ServeHTTP(list, req)
	require.Equal(t, http.StatusOK, list.Code, list.Body.String())
	assert.Contains(t, list.Body.String(), "Expense added")

	read := httptest.NewRecorder()
	req, _ = http.NewRequest(http.MethodPut, fmt.Sprintf("/notifications/%d/read", fixtures.Notification.ID), nil)
	memberRouter.ServeHTTP(read, req)
	require.Equal(t, http.StatusOK, read.Code, read.Body.String())

	var notification models.Notification
	require.NoError(t, db.First(&notification, fixtures.Notification.ID).Error)
	assert.True(t, notification.IsRead)

	creatorRouter := gin.New()
	creatorRouter.Use(withTestUser(fixtures.Creator.FirebaseUID))
	creatorRouter.POST("/join-requests/:id/process", handler.ProcessJoinRequest)

	process := performJSON(creatorRouter, http.MethodPost, "/join-requests/"+fixtures.JoinRequest.ID.String()+"/process", map[string]bool{"accept": true})
	require.Equal(t, http.StatusOK, process.Code, process.Body.String())

	var joined models.RoomspaceMember
	require.NoError(t, db.Where("roomspace_id = ? AND user_id = ?",
		fixtures.Roomspace.ID, fixtures.Outsider.FirebaseUID).First(&joined).Error)
	assert.True(t, joined.IsActive)
}

func TestPaymentConfirmationHandler_DBCreateConfirmAndReject(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	service := services.NewPaymentConfirmationService(config.DB, services.NewBalanceService(), services.NewPostgresService())
	handler := NewPaymentConfirmationHandler(service, services.NewPostgresService())

	memberRouter := gin.New()
	memberRouter.Use(withTestUser(fixtures.Member.FirebaseUID))
	memberRouter.POST("/roomspaces/:id/payments/confirm", handler.CreatePaymentConfirmation)
	memberRouter.PUT("/roomspaces/:id/payments/:paymentId/confirm", handler.ConfirmPayment)

	createBody := models.PaymentConfirmationRequest{
		ToUserID:    fixtures.Creator.FirebaseUID,
		Amount:      70,
		PaymentType: models.PaymentTypeFull,
		Notes:       "paid via test",
		PaymentDate: time.Now().UTC(),
	}
	created := performJSON(memberRouter, http.MethodPost, "/roomspaces/"+fixtures.Roomspace.ID.String()+"/payments/confirm", createBody)
	require.Equal(t, http.StatusCreated, created.Code, created.Body.String())

	var createdResponse map[string]interface{}
	require.NoError(t, json.Unmarshal(created.Body.Bytes(), &createdResponse))
	paymentID := uint(createdResponse["data"].(map[string]interface{})["id"].(float64))

	unauthorized := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodPut, fmt.Sprintf("/roomspaces/%s/payments/%d/confirm", fixtures.Roomspace.ID.String(), paymentID), nil)
	memberRouter.ServeHTTP(unauthorized, req)
	require.Equal(t, http.StatusForbidden, unauthorized.Code, unauthorized.Body.String())

	creatorRouter := gin.New()
	creatorRouter.Use(withTestUser(fixtures.Creator.FirebaseUID))
	creatorRouter.PUT("/roomspaces/:id/payments/:paymentId/confirm", handler.ConfirmPayment)
	creatorRouter.PUT("/roomspaces/:id/payments/:paymentId/reject", handler.RejectPayment)

	confirmed := httptest.NewRecorder()
	req, _ = http.NewRequest(http.MethodPut, fmt.Sprintf("/roomspaces/%s/payments/%d/confirm", fixtures.Roomspace.ID.String(), paymentID), nil)
	creatorRouter.ServeHTTP(confirmed, req)
	require.Equal(t, http.StatusOK, confirmed.Code, confirmed.Body.String())

	var payment models.PaymentConfirmation
	require.NoError(t, db.First(&payment, paymentID).Error)
	assert.Equal(t, models.PaymentStatusConfirmed, payment.Status)

	rejected := performJSON(creatorRouter, http.MethodPut,
		fmt.Sprintf("/roomspaces/%s/payments/%d/reject", fixtures.Roomspace.ID.String(), fixtures.PaymentConfirmation.ID),
		models.PaymentConfirmActionRequest{Reason: "wrong amount"})
	require.Equal(t, http.StatusOK, rejected.Code, rejected.Body.String())
}

func withTestUser(userID string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("user_id", userID)
		c.Set("email", userID+"@example.com")
		c.Next()
	}
}

func performJSON(router *gin.Engine, method, path string, body interface{}) *httptest.ResponseRecorder {
	var buf bytes.Buffer
	_ = json.NewEncoder(&buf).Encode(body)
	req, _ := http.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}
