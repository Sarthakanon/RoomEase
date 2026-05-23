package handlers

import (
	"encoding/json"
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"

	"github.com/gin-gonic/gin"
)

type NotificationHandler struct {
	dbService *services.PostgresService
}

func NewNotificationHandler(dbService *services.PostgresService) *NotificationHandler {
	return &NotificationHandler{dbService: dbService}
}

// GetNotifications returns all notifications for the current user
func (h *NotificationHandler) GetNotifications(c *gin.Context) {
	userID, _ := c.Get("user_id")

	notifications, err := h.dbService.GetUserNotifications(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get notifications"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": notifications})
}

// MarkAsRead marks a notification as read
func (h *NotificationHandler) MarkAsRead(c *gin.Context) {
	userID, _ := c.Get("user_id")
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	if err := h.dbService.MarkNotificationAsRead(uint(id), userID.(string)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Notification marked as read"})
}

// GetPendingJoinRequest gets the current user's pending join request
func (h *NotificationHandler) GetPendingJoinRequest(c *gin.Context) {
	userID, _ := c.Get("user_id")

	request, err := h.dbService.GetPendingJoinRequest(userID.(string))
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": nil})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": request})
}

// GetJoinRequests gets all pending join requests for user's roomspaces
func (h *NotificationHandler) GetJoinRequests(c *gin.Context) {
	userID, _ := c.Get("user_id")

	// Get user's roomspaces
	roomspaces, err := h.dbService.GetUserRoomspaces(userID.(string))
	if err != nil || len(roomspaces) == 0 {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []models.JoinRequest{}})
		return
	}

	// Get join requests for ALL user's roomspaces (user can be in multiple)
	var allRequests []models.JoinRequest
	for _, roomspace := range roomspaces {
		requests, err := h.dbService.GetJoinRequestsForRoomspace(roomspace.ID.String())
		if err != nil {
			continue // Skip if error for one roomspace
		}
		allRequests = append(allRequests, requests...)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": allRequests})
}

type ProcessJoinRequestBody struct {
	Accept bool `json:"accept"`
}

// ProcessJoinRequest accepts or rejects a join request
func (h *NotificationHandler) ProcessJoinRequest(c *gin.Context) {
	userID, _ := c.Get("user_id")
	requestID := c.Param("id") // Keep as string since it's a UUID

	var body ProcessJoinRequestBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Get request details before processing
	request, _ := h.dbService.GetJoinRequestByID(requestID)
	if request == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Join request not found"})
		return
	}

	// Get requester and roomspace info
	requester, _ := h.dbService.GetUserByFirebaseUID(request.RequesterID)
	roomspace, _ := h.dbService.GetRoomspaceByID(request.RoomspaceID.String())
	processor, _ := h.dbService.GetUserByFirebaseUID(userID.(string))

	requesterName := "Someone"
	if requester != nil {
		requesterName = requester.Name
	}
	roomspaceName := "the roomspace"
	if roomspace != nil {
		roomspaceName = roomspace.Name
	}
	processorName := "A member"
	if processor != nil {
		processorName = processor.Name
	}

	if err := h.dbService.ProcessJoinRequest(requestID, userID.(string), body.Accept, ""); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if body.Accept {
		// Notify the requester that they've been accepted
		h.dbService.CreateNotification(&models.Notification{
			RecipientUID: request.RequesterID,
			Type:         models.NotificationTypeJoinAccepted,
			Title:        "Welcome to " + roomspaceName + "!",
			Message:      "Your request to join has been accepted by " + processorName,
		})

		// Notify the processor (user who accepted) that they accepted the request
		h.dbService.CreateNotification(&models.Notification{
			RecipientUID: userID.(string),
			Type:         models.NotificationTypeJoinAccepted,
			Title:        "You Accepted a Join Request",
			Message:      "You accepted " + requesterName + "'s request to join " + roomspaceName,
		})

		// Notify all other members that a new member joined
		members, _ := h.dbService.GetRoomspaceMembers(request.RoomspaceID.String())
		for _, member := range members {
			// Skip the requester and the processor
			if member.UserID == request.RequesterID || member.UserID == userID.(string) {
				continue
			}
			h.dbService.CreateNotification(&models.Notification{
				RecipientUID: member.UserID,
				Type:         models.NotificationTypeJoinAccepted,
				Title:        "New Member Joined",
				Message:      processorName + " accepted " + requesterName + "'s request to join " + roomspaceName,
			})
		}
	} else {
		// Notify the requester that they've been rejected
		h.dbService.CreateNotification(&models.Notification{
			RecipientUID: request.RequesterID,
			Type:         models.NotificationTypeJoinRejected,
			Title:        "Request Declined",
			Message:      "Your request to join " + roomspaceName + " was declined",
		})
	}

	status := "rejected"
	if body.Accept {
		status = "accepted"
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Join request " + status})
}

// Helper to create notification for all roomspace members
func (h *NotificationHandler) notifyRoomspaceMembers(roomspaceID uint, excludeUID string, notifType models.NotificationType, title, message string, data map[string]interface{}) {
	members, err := h.dbService.GetRoomspaceMembers(strconv.Itoa(int(roomspaceID)))
	if err != nil {
		return
	}

	dataJSON, _ := json.Marshal(data)

	for _, member := range members {
		if member.UserID == excludeUID {
			continue
		}
		notification := &models.Notification{
			RecipientUID: member.UserID,
			Type:         notifType,
			Title:        title,
			Message:      message,
			Data:         string(dataJSON),
		}
		h.dbService.CreateNotification(notification)
	}
}

// SendPaymentReminder sends a reminder notification to a user to pay their debt
func (h *NotificationHandler) SendPaymentReminder(c *gin.Context) {
	senderUID, _ := c.Get("user_id")

	var req struct {
		RecipientUID string  `json:"recipient_uid" binding:"required"`
		RoomspaceID  string  `json:"roomspace_id" binding:"required"`
		Amount       float64 `json:"amount" binding:"required,gt=0"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body", "details": err.Error()})
		return
	}

	// Get sender and recipient names
	sender, err := h.dbService.GetUserByFirebaseUID(senderUID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get sender info"})
		return
	}

	recipient, err := h.dbService.GetUserByFirebaseUID(req.RecipientUID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get recipient info"})
		return
	}

	// Get roomspace name
	roomspace, err := h.dbService.GetRoomspaceByID(req.RoomspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get roomspace info"})
		return
	}

	// Create notification
	notification := &models.Notification{
		RecipientUID: req.RecipientUID,
		Type:         "PAYMENT_REMINDER",
		Title:        "Payment Reminder",
		Message:      sender.Name + " reminds you to pay Rs." + strconv.FormatFloat(req.Amount, 'f', 2, 64) + " in " + roomspace.Name,
		Data:         `{"roomspace_id":"` + req.RoomspaceID + `","amount":` + strconv.FormatFloat(req.Amount, 'f', 2, 64) + `,"sender_uid":"` + senderUID.(string) + `"}`,
	}

	if err := h.dbService.CreateNotification(notification); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create notification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Reminder sent to " + recipient.Name,
	})
}
