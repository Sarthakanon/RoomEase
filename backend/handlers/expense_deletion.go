package handlers

import (
	"fmt"
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"

	"github.com/gin-gonic/gin"
)

// ExpenseDeletionHandler handles expense deletion approval workflow
type ExpenseDeletionHandler struct {
	dbService *services.PostgresService
}

// NewExpenseDeletionHandler creates a new expense deletion handler
func NewExpenseDeletionHandler(dbService *services.PostgresService) *ExpenseDeletionHandler {
	return &ExpenseDeletionHandler{
		dbService: dbService,
	}
}

// RequestExpenseDeletion creates a deletion request for an expense
func (h *ExpenseDeletionHandler) RequestExpenseDeletion(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get expense ID from URL
	idStr := c.Param("id")
	expenseID, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid expense ID",
		})
		return
	}

	// Get existing expense
	expense, err := h.dbService.GetExpenseByID(uint(expenseID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Expense not found",
		})
		return
	}

	// Verify user is part of this expense (either paid or in splits)
	isPartOfExpense := false
	affectedUsers := []string{}
	
	// Add payer to affected users
	affectedUsers = append(affectedUsers, expense.PaidBy)
	if expense.PaidBy == userID.(string) {
		isPartOfExpense = true
	}

	// Add all split members to affected users
	for _, split := range expense.Splits {
		affectedUsers = append(affectedUsers, split.UserUID)
		if split.UserUID == userID.(string) {
			isPartOfExpense = true
		}
	}

	if !isPartOfExpense {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "You are not part of this expense",
		})
		return
	}

	// Parse request body
	var req models.CreateDeletionRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Reason is optional, so we can continue without it
		req.Reason = "User requested deletion"
	}

	// Check if there's already a pending deletion request for this expense
	existingRequest, err := h.dbService.GetPendingDeletionRequest(uint(expenseID))
	if err == nil && existingRequest != nil {
		c.JSON(http.StatusConflict, gin.H{
			"error": "A deletion request for this expense is already pending",
			"data":  h.convertToDeletionRequestResponse(existingRequest),
		})
		return
	}

	// Create deletion request
	deletionRequest := &models.ExpenseDeletionRequest{
		ExpenseID:   uint(expenseID),
		RoomspaceID: expense.RoomspaceID,
		RequestedBy: userID.(string),
		Reason:      req.Reason,
		Status:      "pending",
	}

	if err := h.dbService.CreateDeletionRequest(deletionRequest); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create deletion request",
			"details": err.Error(),
		})
		return
	}

	// Send notifications to all affected users (except the requester)
	if err := h.sendDeletionRequestNotifications(deletionRequest, expense, affectedUsers, userID.(string)); err != nil {
		// Log error but don't fail the request
		fmt.Printf("Failed to send deletion request notifications: %v\n", err)
	}

	// Convert to response format
	response := h.convertToDeletionRequestResponse(deletionRequest)

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Deletion request created. All affected roommates will be notified.",
		"data":    response,
	})
}

// RespondToDeletionRequest allows a user to approve or reject a deletion request
func (h *ExpenseDeletionHandler) RespondToDeletionRequest(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get deletion request ID from URL
	idStr := c.Param("id")
	requestID, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid deletion request ID",
		})
		return
	}

	// Get deletion request
	deletionRequest, err := h.dbService.GetDeletionRequestByID(uint(requestID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Deletion request not found",
		})
		return
	}

	// Check if request is still pending
	if deletionRequest.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "This deletion request is no longer pending",
		})
		return
	}

	// Get the expense to verify user is affected
	expense, err := h.dbService.GetExpenseByID(deletionRequest.ExpenseID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Associated expense not found",
		})
		return
	}

	// Verify user is part of this expense
	isAffected := false
	if expense.PaidBy == userID.(string) {
		isAffected = true
	}
	for _, split := range expense.Splits {
		if split.UserUID == userID.(string) {
			isAffected = true
			break
		}
	}

	if !isAffected {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "You are not affected by this expense",
		})
		return
	}

	// Check if user has already responded
	hasResponded, err := h.dbService.HasUserRespondedToDeletion(uint(requestID), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to check response status",
		})
		return
	}
	if hasResponded {
		c.JSON(http.StatusConflict, gin.H{
			"error": "You have already responded to this deletion request",
		})
		return
	}

	// Parse request body
	var req models.RespondToDeletionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Create approval record
	approval := &models.ExpenseDeletionApproval{
		DeletionRequestID: uint(requestID),
		UserUID:           userID.(string),
		Approved:          req.Approved,
		Comment:           req.Comment,
	}

	if err := h.dbService.CreateDeletionApproval(approval); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to record response",
			"details": err.Error(),
		})
		return
	}

	// Check if all affected users have responded
	allResponded, allApproved, err := h.checkDeletionStatus(deletionRequest, expense)
	if err != nil {
		fmt.Printf("Error checking deletion status: %v\n", err)
	}

	// Update deletion request status
	if !req.Approved {
		// If anyone rejects, mark as rejected
		deletionRequest.Status = "rejected"
		h.dbService.UpdateDeletionRequest(deletionRequest)
		
		// Notify requester of rejection
		h.sendDeletionRejectedNotification(deletionRequest, userID.(string))
	} else if allResponded && allApproved {
		// If everyone approved, delete the expense
		deletionRequest.Status = "approved"
		h.dbService.UpdateDeletionRequest(deletionRequest)
		
		// Delete the expense
		if err := h.dbService.DeleteExpense(deletionRequest.ExpenseID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to delete expense",
				"details": err.Error(),
			})
			return
		}
		
		deletionRequest.Status = "completed"
		h.dbService.UpdateDeletionRequest(deletionRequest)
		
		// Notify all users of successful deletion
		h.sendDeletionCompletedNotification(deletionRequest, expense)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Response recorded: %s", map[bool]string{true: "Approved", false: "Rejected"}[req.Approved]),
		"data": gin.H{
			"all_responded": allResponded,
			"all_approved":  allApproved,
			"status":        deletionRequest.Status,
		},
	})
}

// GetPendingDeletionRequests gets all pending deletion requests for the user
func (h *ExpenseDeletionHandler) GetPendingDeletionRequests(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get pending deletion requests
	requests, err := h.dbService.GetPendingDeletionRequestsForUser(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve deletion requests",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.DeletionRequestResponse
	for _, request := range requests {
		responses = append(responses, h.convertToDeletionRequestResponse(&request))
	}

	if responses == nil {
		responses = []models.DeletionRequestResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// Helper functions

// checkDeletionStatus checks if all affected users have responded and if all approved
func (h *ExpenseDeletionHandler) checkDeletionStatus(request *models.ExpenseDeletionRequest, expense *models.Expense) (allResponded bool, allApproved bool, err error) {
	// Get all affected users
	affectedUsers := make(map[string]bool)
	affectedUsers[expense.PaidBy] = false
	for _, split := range expense.Splits {
		affectedUsers[split.UserUID] = false
	}

	// Get all approvals
	approvals, err := h.dbService.GetDeletionApprovals(request.ID)
	if err != nil {
		return false, false, err
	}

	// Mark users who have responded
	allApproved = true
	for _, approval := range approvals {
		affectedUsers[approval.UserUID] = true
		if !approval.Approved {
			allApproved = false
		}
	}

	// Check if all users have responded
	allResponded = true
	for _, responded := range affectedUsers {
		if !responded {
			allResponded = false
			break
		}
	}

	return allResponded, allApproved, nil
}

// sendDeletionRequestNotifications sends notifications to affected users
func (h *ExpenseDeletionHandler) sendDeletionRequestNotifications(request *models.ExpenseDeletionRequest, expense *models.Expense, affectedUsers []string, requesterUID string) error {
	// Get requester info
	requester, err := h.dbService.GetUserByFirebaseUID(requesterUID)
	if err != nil {
		return err
	}

	requesterName := "Someone"
	if requester != nil {
		requesterName = requester.Name
	}

	// Send notification to each affected user (except requester)
	for _, userUID := range affectedUsers {
		if userUID == requesterUID {
			continue
		}

		notification := &models.Notification{
			RecipientUID: userUID,
			Type:         models.NotificationTypeExpenseDeletionRequest,
			Title:        "Expense Deletion Request",
			Message:      fmt.Sprintf("%s requested to delete expense \"%s\" (Rs. %.2f). Please approve or reject.", requesterName, expense.Title, expense.Amount),
		}

		if err := h.dbService.CreateNotification(notification); err != nil {
			fmt.Printf("Failed to create notification for user %s: %v\n", userUID, err)
		}
	}

	return nil
}

// sendDeletionRejectedNotification notifies requester that deletion was rejected
func (h *ExpenseDeletionHandler) sendDeletionRejectedNotification(request *models.ExpenseDeletionRequest, rejectorUID string) error {
	// Get rejector info
	rejector, err := h.dbService.GetUserByFirebaseUID(rejectorUID)
	if err != nil {
		return err
	}

	rejectorName := "Someone"
	if rejector != nil {
		rejectorName = rejector.Name
	}

	// Get expense
	expense, err := h.dbService.GetExpenseByID(request.ExpenseID)
	if err != nil {
		return err
	}

	notification := &models.Notification{
		RecipientUID: request.RequestedBy,
		Type:         models.NotificationTypeExpenseDeletionRejected,
		Title:        "Deletion Request Rejected",
		Message:      fmt.Sprintf("%s rejected your request to delete expense \"%s\"", rejectorName, expense.Title),
	}

	return h.dbService.CreateNotification(notification)
}

// sendDeletionCompletedNotification notifies all users that expense was deleted
func (h *ExpenseDeletionHandler) sendDeletionCompletedNotification(request *models.ExpenseDeletionRequest, expense *models.Expense) error {
	// Get all affected users
	affectedUsers := []string{expense.PaidBy}
	for _, split := range expense.Splits {
		affectedUsers = append(affectedUsers, split.UserUID)
	}

	// Send notification to each affected user
	for _, userUID := range affectedUsers {
		notification := &models.Notification{
			RecipientUID: userUID,
			Type:         models.NotificationTypeExpenseDeletionApproved,
			Title:        "Expense Deleted",
			Message:      fmt.Sprintf("Expense \"%s\" (Rs. %.2f) has been deleted with everyone's approval", expense.Title, expense.Amount),
		}

		if err := h.dbService.CreateNotification(notification); err != nil {
			fmt.Printf("Failed to create notification for user %s: %v\n", userUID, err)
		}
	}

	return nil
}

// convertToDeletionRequestResponse converts deletion request to response format
func (h *ExpenseDeletionHandler) convertToDeletionRequestResponse(request *models.ExpenseDeletionRequest) models.DeletionRequestResponse {
	response := models.DeletionRequestResponse{
		ID:          request.ID,
		ExpenseID:   request.ExpenseID,
		RequestedBy: request.RequestedBy,
		Reason:      request.Reason,
		Status:      request.Status,
		CreatedAt:   request.CreatedAt,
	}

	// Add requester name if available
	if request.Requester != nil {
		response.RequesterName = request.Requester.Name
	}

	// Add expense data if available
	if request.Expense != nil {
		expenseHandler := &ExpenseHandler{dbService: h.dbService}
		expenseResponse := expenseHandler.convertToExpenseResponse(request.Expense)
		response.ExpenseData = &expenseResponse

		// Build affected users list
		affectedUsers := []string{request.Expense.PaidBy}
		for _, split := range request.Expense.Splits {
			affectedUsers = append(affectedUsers, split.UserUID)
		}
		response.AffectedUsers = affectedUsers
	}

	// Add approvals if available
	if request.Approvals != nil {
		for _, approval := range request.Approvals {
			approvalResponse := models.DeletionApprovalResponse{
				UserUID:     approval.UserUID,
				Approved:    approval.Approved,
				Comment:     approval.Comment,
				RespondedAt: approval.RespondedAt,
			}
			if approval.User != nil {
				approvalResponse.UserName = approval.User.Name
			}
			response.Approvals = append(response.Approvals, approvalResponse)
		}
	}

	return response
}
