package handlers

import (
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

// RoomspaceHandler handles roomspace-related requests
type RoomspaceHandler struct {
	dbService *services.PostgresService
}

// NewRoomspaceHandler creates a new roomspace handler
func NewRoomspaceHandler(dbService *services.PostgresService) *RoomspaceHandler {
	return &RoomspaceHandler{
		dbService: dbService,
	}
}

// GetRoomspaces retrieves all roomspaces for the current user
func (h *RoomspaceHandler) GetRoomspaces(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get user's roomspaces
	roomspaces, err := h.dbService.GetUserRoomspaces(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve roomspaces",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    roomspaces,
	})
}

// GetRoomspaceCount retrieves the count of active roomspaces for the current user
func (h *RoomspaceHandler) GetRoomspaceCount(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get count of user's active roomspaces
	count, err := h.dbService.GetUserRoomspaceCount(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve roomspace count",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"count":   count,
		"limit":   5,
		"can_join_more": count < 5,
	})
}

// CreateRoomspace creates a new roomspace
func (h *RoomspaceHandler) CreateRoomspace(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req models.CreateRoomspaceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Create roomspace
	var description *string
	if req.Description != "" {
		description = &req.Description
	}
	
	creatorID := userID.(string)
	roomspace := &models.Roomspace{
		Name:        req.Name,
		Description: description,
		CreatorID:   &creatorID,
	}

	if err := h.dbService.CreateRoomspace(roomspace); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create roomspace",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Roomspace created successfully",
		"data":    roomspace,
	})
}

// GetRoomspace retrieves a specific roomspace by ID
func (h *RoomspaceHandler) GetRoomspace(c *gin.Context) {
	// Get roomspace ID from URL
	idStr := c.Param("id")

	// Get roomspace
	roomspace, err := h.dbService.GetRoomspaceByID(idStr)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Roomspace not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    roomspace,
	})
}

// SearchRoomspaceByCode searches for a roomspace by invite code
func (h *RoomspaceHandler) SearchRoomspaceByCode(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invite code is required",
		})
		return
	}

	// Search for roomspace
	roomspace, err := h.dbService.GetRoomspaceByInviteCode(code)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Roomspace not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    roomspace,
	})
}

// JoinRoomspaceByCode creates a join request for a roomspace using invite code
func (h *RoomspaceHandler) JoinRoomspaceByCode(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	code := c.Param("code")
	if code == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invite code is required"})
		return
	}

	// Find roomspace by code
	roomspace, err := h.dbService.GetRoomspaceByInviteCode(code)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Roomspace not found"})
		return
	}

	// Create join request instead of direct join
	request, err := h.dbService.CreateJoinRequest(roomspace.ID.String(), userID.(string), "")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Notify all members about the join request
	user, _ := h.dbService.GetUserByFirebaseUID(userID.(string))
	userName := "Someone"
	if user != nil {
		userName = user.Name
	}

	members, _ := h.dbService.GetRoomspaceMembers(roomspace.ID.String())
	for _, member := range members {
		notification := &models.Notification{
			RecipientUID: member.UserID,
			Type:         models.NotificationTypeJoinRequest,
			Title:        "New Join Request",
			Message:      userName + " wants to join " + roomspace.Name,
			Data:         `{"request_id":"` + request.ID.String() + `","roomspace_id":"` + roomspace.ID.String() + `"}`,
		}
		h.dbService.CreateNotification(notification)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Join request sent. Waiting for approval.",
		"data":    request,
	})
}

// JoinRoomspace adds the current user to a roomspace by ID
func (h *RoomspaceHandler) JoinRoomspace(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	idStr := c.Param("id")

	// Add user to roomspace
	if err := h.dbService.AddMemberToRoomspace(idStr, userID.(string)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Successfully joined roomspace",
	})
}


// RemoveMemberRequest represents the request to remove a member
type RemoveMemberRequest struct {
	MemberFirebaseUID string `json:"member_firebase_uid" binding:"required"`
}

// RemoveMember removes a member from a roomspace (only creator can do this)
func (h *RoomspaceHandler) RemoveMember(c *gin.Context) {
	// Get user ID from context (the requestor)
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	idStr := c.Param("id")

	// Parse request body
	var req RemoveMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Get roomspace and removed user info before removing
	roomspace, _ := h.dbService.GetRoomspaceByID(idStr)
	removedUser, _ := h.dbService.GetUserByFirebaseUID(req.MemberFirebaseUID)

	// Remove member
	if err := h.dbService.RemoveMemberFromRoomspace(idStr, req.MemberFirebaseUID, userID.(string)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Create notification for the removed user
	roomspaceName := "the roomspace"
	if roomspace != nil {
		roomspaceName = roomspace.Name
	}
	removedUserName := "A member"
	if removedUser != nil {
		removedUserName = removedUser.Name
	}

	// Notify the removed user
	notificationForRemoved := &models.Notification{
		RecipientUID: req.MemberFirebaseUID,
		Type:         models.NotificationTypeMemberRemoved,
		Title:        "Removed from Roomspace",
		Message:      "You have been removed from " + roomspaceName,
	}
	h.dbService.CreateNotification(notificationForRemoved)

	// Notify the creator (who removed the user)
	notificationForCreator := &models.Notification{
		RecipientUID: userID.(string),
		Type:         models.NotificationTypeYouRemovedUser,
		Title:        "Member Removed",
		Message:      "You removed " + removedUserName + " from " + roomspaceName,
	}
	h.dbService.CreateNotification(notificationForCreator)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Member removed successfully",
	})
}

// LeaveRoomspace allows any member (including creator) to leave a roomspace
func (h *RoomspaceHandler) LeaveRoomspace(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get roomspace ID from URL
	idStr := c.Param("id")

	// Leave roomspace with ownership transfer logic
	result, err := h.dbService.LeaveRoomspace(idStr, userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": result.Message,
		"data": gin.H{
			"ownership_transferred": result.OwnershipTransferred,
			"new_creator_id":        result.NewCreatorID,
			"roomspace_deleted":     result.RoomspaceDeleted,
		},
	})
}
