package handlers

import (
	"fmt"
	"net/http"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// ExpenseHandler handles expense-related requests
type ExpenseHandler struct {
	dbService *services.PostgresService
}

// NewExpenseHandler creates a new expense handler
func NewExpenseHandler(dbService *services.PostgresService) *ExpenseHandler {
	return &ExpenseHandler{
		dbService: dbService,
	}
}

// CreateExpense creates a new expense with splits
func (h *ExpenseHandler) CreateExpense(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req models.CreateExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Debug: Log the received paid_by value
	fmt.Printf("DEBUG: Received expense request - PaidBy: '%s', AuthUser: '%s', Title: '%s'\n", req.PaidBy, userID.(string), req.Title)

	// Validate split type and custom splits
	if err := h.validateExpenseRequest(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(req.RoomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Determine who paid for the expense
	paidBy := userID.(string) // Default to authenticated user
	if req.PaidBy != "" {
		// If PaidBy is specified, verify they are a member of the roomspace
		if err := h.verifyRoomspaceMembership(req.RoomspaceID, req.PaidBy); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "The specified payer is not a member of this roomspace",
			})
			return
		}
		paidBy = req.PaidBy
	}

	// Calculate splits based on split type
	splits, err := h.calculateSplits(&req, paidBy)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Create expense model
	expense := &models.Expense{
		RoomspaceID: req.RoomspaceID,
		Title:       req.Title,
		Description: req.Description,
		Amount:      req.Amount,
		Category:    req.Category,
		PaidBy:      paidBy,
		SplitType:   req.SplitType,
		Splits:      splits,
	}

	// Debug: Log the final paidBy value
	fmt.Printf("DEBUG: Creating expense with PaidBy: '%s'\n", paidBy)

	// Save expense to database
	if err := h.dbService.CreateExpense(expense); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create expense",
			"details": err.Error(),
		})
		return
	}

	// Send notifications to selected roommates (excluding the creator)
	if err := h.sendExpenseNotifications(expense, userID.(string)); err != nil {
		// Log error but don't fail the expense creation
		fmt.Printf("Failed to send expense notifications: %v\n", err)
	}

	// Convert to response format
	response := h.convertToExpenseResponse(expense)

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Expense created successfully",
		"data":    response,
	})
}

// GetExpenses retrieves expenses for the user's roomspaces
func (h *ExpenseHandler) GetExpenses(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")
	roomspaceID := c.Query("roomspace_id")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 0 {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// If roomspace_id is provided, validate user membership
	if roomspaceID != "" {
		if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": err.Error(),
			})
			return
		}
	}

	// Get user's expenses (filtered by roomspace if provided)
	expenses, err := h.dbService.GetUserExpenses(userID.(string), roomspaceID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve expenses",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.ExpenseResponse
	for _, expense := range expenses {
		responses = append(responses, h.convertToExpenseResponse(&expense))
	}

	// Ensure we always return an array, even if empty
	if responses == nil {
		responses = []models.ExpenseResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
		"meta": gin.H{
			"limit":  limit,
			"offset": offset,
			"count":  len(responses),
		},
	})
}

// GetExpenseByID retrieves a specific expense by ID
func (h *ExpenseHandler) GetExpenseByID(c *gin.Context) {
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
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid expense ID",
		})
		return
	}

	// Get expense
	expense, err := h.dbService.GetExpenseByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Expense not found",
		})
		return
	}

	// Verify user has access to this expense (member of roomspace)
	if err := h.verifyRoomspaceMembership(expense.RoomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Access denied",
		})
		return
	}

	// Convert to response format
	response := h.convertToExpenseResponse(expense)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    response,
	})
}

// GetRoomspaceExpenses retrieves expenses for a specific roomspace
func (h *ExpenseHandler) GetRoomspaceExpenses(c *gin.Context) {
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

	// Parse query parameters
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 0 {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// Parse month/year filters (default to current month if not provided)
	year, month := h.parseDateFilters(c)

	// Get roomspace expenses
	expenses, err := h.dbService.GetRoomspaceExpenses(roomspaceID, limit, offset, year, month)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve expenses",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.ExpenseResponse
	for _, expense := range expenses {
		responses = append(responses, h.convertToExpenseResponse(&expense))
	}

	// Ensure we always return an array, even if empty
	if responses == nil {
		responses = []models.ExpenseResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
		"meta": gin.H{
			"limit":  limit,
			"offset": offset,
			"count":  len(responses),
			"year":   year,
			"month":  month,
		},
	})
}

// GetRecentExpenses retrieves recent expenses for a roomspace (for dashboard)
func (h *ExpenseHandler) GetRecentExpenses(c *gin.Context) {
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

	// Parse limit parameter (default 3 for dashboard)
	limitStr := c.DefaultQuery("limit", "3")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 0 {
		limit = 3
	}

	// Parse month/year filters (default to current month if not provided)
	year, month := h.parseDateFilters(c)

	// Get recent expenses
	expenses, err := h.dbService.GetRecentExpenses(roomspaceID, limit, year, month)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve recent expenses",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.ExpenseResponse
	for _, expense := range expenses {
		responses = append(responses, h.convertToExpenseResponse(&expense))
	}

	// Ensure we always return an array, even if empty
	if responses == nil {
		responses = []models.ExpenseResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// UpdateExpense updates an existing expense
func (h *ExpenseHandler) UpdateExpense(c *gin.Context) {
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
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid expense ID",
		})
		return
	}

	// Get existing expense
	existingExpense, err := h.dbService.GetExpenseByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Expense not found",
		})
		return
	}

	// Verify user is the one who paid for this expense (only they can edit)
	if existingExpense.PaidBy != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Only the person who paid can edit this expense",
		})
		return
	}

	// Parse request body
	var req models.CreateExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Validate the request
	if err := h.validateExpenseRequest(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Verify user is still a member of the roomspace
	if err := h.verifyRoomspaceMembership(req.RoomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Calculate new splits
	splits, err := h.calculateSplits(&req, userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Update expense
	existingExpense.Title = req.Title
	existingExpense.Description = req.Description
	existingExpense.Amount = req.Amount
	existingExpense.Category = req.Category
	existingExpense.SplitType = req.SplitType
	existingExpense.Splits = splits

	// Save updated expense
	if err := h.dbService.UpdateExpense(existingExpense); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update expense",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	response := h.convertToExpenseResponse(existingExpense)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Expense updated successfully",
		"data":    response,
	})
}

// DeleteExpense deletes an expense
func (h *ExpenseHandler) DeleteExpense(c *gin.Context) {
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
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid expense ID",
		})
		return
	}

	// Get existing expense
	existingExpense, err := h.dbService.GetExpenseByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Expense not found",
		})
		return
	}

	// Verify user is the one who paid for this expense (only they can delete)
	if existingExpense.PaidBy != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Only the person who paid can delete this expense",
		})
		return
	}

	// Delete expense (soft delete)
	if err := h.dbService.DeleteExpense(uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete expense",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Expense deleted successfully",
	})
}

// sendExpenseNotifications sends notifications to selected roommates about the new expense
func (h *ExpenseHandler) sendExpenseNotifications(expense *models.Expense, creatorUID string) error {
	// Get the creator's information
	creator, err := h.dbService.GetUserByFirebaseUID(creatorUID)
	if err != nil {
		return fmt.Errorf("failed to get creator information: %v", err)
	}

	creatorName := "Someone"
	if creator != nil {
		creatorName = creator.Name
	}

	// Get roomspace information
	roomspace, err := h.dbService.GetRoomspaceByID(expense.RoomspaceID)
	if err != nil {
		return fmt.Errorf("failed to get roomspace information: %v", err)
	}

	roomspaceName := "the roomspace"
	if roomspace != nil {
		roomspaceName = roomspace.Name
	}

	// Create notification title and message
	title := fmt.Sprintf("New Expense: %s", expense.Title)
	message := fmt.Sprintf("%s added a $%.2f expense for %s in %s", 
		creatorName, expense.Amount, expense.Category, roomspaceName)

	// Send notifications to all selected roommates except the creator
	for _, split := range expense.Splits {
		// Skip sending notification to the creator themselves
		if split.UserUID == creatorUID {
			continue
		}

		notification := &models.Notification{
			RecipientUID: split.UserUID,
			Type:         models.NotificationTypeExpenseAdded,
			Title:        title,
			Message:      message,
		}

		if err := h.dbService.CreateNotification(notification); err != nil {
			// Log error but continue with other notifications
			fmt.Printf("Failed to create notification for user %s: %v\n", split.UserUID, err)
		}
	}

	return nil
}

// Helper functions

// validateExpenseRequest validates the expense creation request
func (h *ExpenseHandler) validateExpenseRequest(req *models.CreateExpenseRequest) error {
	// Validate selected roommates
	if len(req.SelectedRoommates) == 0 {
		return fmt.Errorf("at least one roommate must be selected")
	}
	
	// Prevent solo expenses (only 1 person selected)
	if len(req.SelectedRoommates) == 1 {
		return fmt.Errorf("shared expenses must have at least 2 people. For personal expenses, use the personal expense feature")
	}
	
	// Validate split type
	switch req.SplitType {
	case models.SplitTypeEqual:
		// No additional validation needed for equal splits
	case models.SplitTypePercentage:
		if req.CustomSplits == nil || len(req.CustomSplits) == 0 {
			return fmt.Errorf("custom splits required for percentage split type")
		}
		// Validate percentages sum to 100
		total := 0.0
		for _, percentage := range req.CustomSplits {
			if percentage <= 0 || percentage > 100 {
				return fmt.Errorf("percentage values must be between 0 and 100")
			}
			total += percentage
		}
		if total != 100.0 {
			return fmt.Errorf("percentage splits must total exactly 100%%")
		}
	case models.SplitTypeExact:
		if req.CustomSplits == nil || len(req.CustomSplits) == 0 {
			return fmt.Errorf("custom splits required for exact amount split type")
		}
		// Validate amounts sum to total
		total := 0.0
		for _, amount := range req.CustomSplits {
			if amount <= 0 {
				return fmt.Errorf("split amounts must be greater than 0")
			}
			total += amount
		}
		if fmt.Sprintf("%.2f", total) != fmt.Sprintf("%.2f", req.Amount) {
			return fmt.Errorf("split amounts must total the expense amount")
		}
	default:
		return fmt.Errorf("invalid split type")
	}

	return nil
}

// verifyRoomspaceMembership checks if user is a member of the roomspace
func (h *ExpenseHandler) verifyRoomspaceMembership(roomspaceID string, userUID string) error {
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

// calculateSplits calculates expense splits based on split type
func (h *ExpenseHandler) calculateSplits(req *models.CreateExpenseRequest, payerUID string) ([]models.ExpenseSplit, error) {
	var splits []models.ExpenseSplit

	switch req.SplitType {
	case models.SplitTypeEqual:
		// Equal split among selected roommates
		splitAmount := req.Amount / float64(len(req.SelectedRoommates))
		// Handle rounding by giving the remainder to the first person
		remainder := req.Amount - (splitAmount * float64(len(req.SelectedRoommates)))
		
		for i, roommateUID := range req.SelectedRoommates {
			amount := splitAmount
			if i == 0 {
				amount += remainder
			}
			splits = append(splits, models.ExpenseSplit{
				UserUID: roommateUID,
				Amount:  amount,
			})
		}

	case models.SplitTypePercentage:
		// Percentage-based splits
		for roommateUID, percentage := range req.CustomSplits {
			amount := (req.Amount * percentage) / 100.0
			splits = append(splits, models.ExpenseSplit{
				UserUID:    roommateUID,
				Amount:     amount,
				Percentage: percentage,
			})
		}

	case models.SplitTypeExact:
		// Exact amount splits
		for roommateUID, amount := range req.CustomSplits {
			splits = append(splits, models.ExpenseSplit{
				UserUID: roommateUID,
				Amount:  amount,
			})
		}
	}

	return splits, nil
}

// convertToExpenseResponse converts expense model to response format
func (h *ExpenseHandler) convertToExpenseResponse(expense *models.Expense) models.ExpenseResponse {
	response := models.ExpenseResponse{
		ID:          expense.ID,
		Title:       expense.Title,
		Description: expense.Description,
		Amount:      expense.Amount,
		Category:    expense.Category,
		PaidBy:      expense.PaidBy,
		SplitType:   expense.SplitType,
		CreatedAt:   expense.CreatedAt,
	}

	// Add payer name if available
	if expense.Payer != nil {
		response.PayerName = expense.Payer.Name
	}

	// Convert splits
	for _, split := range expense.Splits {
		splitResponse := models.ExpenseSplitResponse{
			UserUID:    split.UserUID,
			Amount:     split.Amount,
			Percentage: split.Percentage,
		}
		
		// Add user name if available
		if split.User != nil {
			splitResponse.UserName = split.User.Name
		}
		
		response.Splits = append(response.Splits, splitResponse)
	}

	return response
}

// CreatePersonalExpense creates a new personal expense (no roomspace or splits)
func (h *ExpenseHandler) CreatePersonalExpense(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req models.CreatePersonalExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Create personal expense model
	expense := &models.PersonalExpense{
		UserUID:     userID.(string),
		Title:       req.Title,
		Description: req.Description,
		Amount:      req.Amount,
		Category:    req.Category,
	}

	// Save personal expense to database
	if err := h.dbService.CreatePersonalExpense(expense); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create personal expense",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	response := models.PersonalExpenseResponse{
		ID:          expense.ID,
		Title:       expense.Title,
		Description: expense.Description,
		Amount:      expense.Amount,
		Category:    expense.Category,
		CreatedAt:   expense.CreatedAt,
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    response,
		"message": "Personal expense created successfully",
	})
}

// GetPersonalExpenses retrieves personal expenses for the authenticated user
func (h *ExpenseHandler) GetPersonalExpenses(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse query parameters for pagination
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	// Parse month/year filters (default to current month if not provided)
	year, month := h.parseDateFilters(c)

	// Get personal expenses from database
	expenses, err := h.dbService.GetPersonalExpenses(userID.(string), limit, offset, year, month)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve personal expenses",
			"details": err.Error(),
		})
		return
	}

	// Convert to response format
	var responses []models.PersonalExpenseResponse
	for _, expense := range expenses {
		responses = append(responses, models.PersonalExpenseResponse{
			ID:          expense.ID,
			Title:       expense.Title,
			Description: expense.Description,
			Amount:      expense.Amount,
			Category:    expense.Category,
			CreatedAt:   expense.CreatedAt,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    responses,
	})
}

// DeletePersonalExpense deletes a personal expense
func (h *ExpenseHandler) DeletePersonalExpense(c *gin.Context) {
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
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid expense ID",
		})
		return
	}

	// Get existing personal expense
	existingExpense, err := h.dbService.GetPersonalExpenseByID(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Personal expense not found",
		})
		return
	}

	// Verify user owns this personal expense
	if existingExpense.UserUID != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "You can only delete your own personal expenses",
		})
		return
	}

	// Delete personal expense (soft delete)
	if err := h.dbService.DeletePersonalExpense(uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete personal expense",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Personal expense deleted successfully",
	})
}


// parseDateFilters parses month and year query parameters
// Returns year and month (defaults to current month if not provided)
func (h *ExpenseHandler) parseDateFilters(c *gin.Context) (int, int) {
	now := time.Now()
	
	// Parse year parameter
	yearStr := c.Query("year")
	year := now.Year()
	if yearStr != "" {
		if y, err := strconv.Atoi(yearStr); err == nil && y > 0 {
			year = y
		}
	}
	
	// Parse month parameter
	monthStr := c.Query("month")
	month := int(now.Month())
	if monthStr != "" {
		if m, err := strconv.Atoi(monthStr); err == nil && m >= 1 && m <= 12 {
			month = m
		}
	}
	
	return year, month
}
