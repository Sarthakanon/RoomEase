package handlers

import (
	"fmt"
	"net/http"
	"roomease/backend/config"
	"roomease/backend/models"
	"roomease/backend/services"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// RecurringExpenseHandler handles recurring expense-related requests
type RecurringExpenseHandler struct {
	dbService *services.PostgresService
}

// NewRecurringExpenseHandler creates a new recurring expense handler
func NewRecurringExpenseHandler(dbService *services.PostgresService) *RecurringExpenseHandler {
	return &RecurringExpenseHandler{
		dbService: dbService,
	}
}

// CreateRecurringExpenseTemplate creates a new recurring expense template
func (h *RecurringExpenseHandler) CreateRecurringExpenseTemplate(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Parse request body
	var req models.CreateRecurringExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Validate recurring configuration
	if !req.RecurringConfig.IsRecurring {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Recurring configuration must be enabled",
		})
		return
	}

	if req.RecurringConfig.StartDate == nil {
		now := time.Now()
		req.RecurringConfig.StartDate = &now
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(req.RoomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Create recurring expense template
	template := &models.RecurringExpenseTemplate{
		RoomspaceID:       req.RoomspaceID,
		Title:             req.Title,
		Description:       req.Description,
		Amount:            req.Amount,
		Category:          req.Category,
		CreatedBy:         userID.(string),
		SelectedRoommates: models.StringArray(req.SelectedRoommates),
		SplitType:         req.SplitType,
		CustomSplits:      req.CustomSplits,
		RecurringConfig:   req.RecurringConfig,
		IsActive:          true,
	}

	// Save to database
	if err := config.DB.Create(template).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create recurring expense template",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Recurring expense template created successfully",
		"data":    template,
	})
}

// GetRecurringExpenseTemplates gets all recurring expense templates for a roomspace
func (h *RecurringExpenseHandler) GetRecurringExpenseTemplates(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	roomspaceID := c.Param("id")
	if roomspaceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Roomspace ID is required",
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Get templates
	var templates []models.RecurringExpenseTemplate
	if err := config.DB.Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).
		Order("created_at DESC").
		Find(&templates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch recurring expense templates",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    templates,
	})
}

// UpdateRecurringExpenseTemplate updates a recurring expense template
func (h *RecurringExpenseHandler) UpdateRecurringExpenseTemplate(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	templateID, err := strconv.Atoi(c.Param("template_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid template ID",
		})
		return
	}

	// Parse request body
	var req models.UpdateRecurringExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Get existing template
	var template models.RecurringExpenseTemplate
	if err := config.DB.First(&template, templateID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Recurring expense template not found",
		})
		return
	}

	// Verify user is the creator or a member of the roomspace
	if template.CreatedBy != userID.(string) {
		if err := h.verifyRoomspaceMembership(template.RoomspaceID, userID.(string)); err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"error": "You don't have permission to update this template",
			})
			return
		}
	}

	// Update fields
	updates := make(map[string]interface{})
	if req.Title != nil {
		updates["title"] = *req.Title
	}
	if req.Description != nil {
		updates["description"] = *req.Description
	}
	if req.Amount != nil {
		updates["amount"] = *req.Amount
	}
	if req.Category != nil {
		updates["category"] = *req.Category
	}
	if req.SplitType != nil {
		updates["split_type"] = *req.SplitType
	}
	if req.SelectedRoommates != nil {
		updates["selected_roommates"] = models.StringArray(req.SelectedRoommates)
	}
	if req.CustomSplits != nil {
		updates["custom_splits"] = req.CustomSplits
	}
	if req.RecurringConfig != nil {
		updates["recurring_config"] = *req.RecurringConfig
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	// Update in database
	if err := config.DB.Model(&template).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update recurring expense template",
			"details": err.Error(),
		})
		return
	}

	// Reload template
	if err := config.DB.First(&template, templateID).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to reload updated template",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Recurring expense template updated successfully",
		"data":    template,
	})
}

// DeleteRecurringExpenseTemplate deletes (deactivates) a recurring expense template
func (h *RecurringExpenseHandler) DeleteRecurringExpenseTemplate(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	templateID, err := strconv.Atoi(c.Param("template_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid template ID",
		})
		return
	}

	// Get existing template
	var template models.RecurringExpenseTemplate
	if err := config.DB.First(&template, templateID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Recurring expense template not found",
		})
		return
	}

	// Verify user is the creator
	if template.CreatedBy != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "You can only delete templates you created",
		})
		return
	}

	// Deactivate template instead of deleting
	if err := config.DB.Model(&template).Update("is_active", false).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete recurring expense template",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Recurring expense template deleted successfully",
	})
}

// GetRecurringExpenseNotifications gets pending recurring expense notifications for a user
func (h *RecurringExpenseHandler) GetRecurringExpenseNotifications(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Get notifications for roomspaces where user is a member
	var notifications []models.RecurringExpenseNotification
	query := config.DB.
		Joins("JOIN recurring_expense_templates ON recurring_expense_notifications.template_id = recurring_expense_templates.id").
		Joins("JOIN roomspace_members ON recurring_expense_templates.roomspace_id = roomspace_members.roomspace_id").
		Where("roomspace_members.user_id = ? AND roomspace_members.is_active = ?", userID.(string), true).
		Where("recurring_expense_notifications.is_processed = ?", false).
		Order("recurring_expense_notifications.scheduled_date ASC").
		Preload("Template")

	if err := query.Find(&notifications).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch recurring expense notifications",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    notifications,
	})
}

// ProcessRecurringExpenseNotification processes a recurring expense notification
func (h *RecurringExpenseHandler) ProcessRecurringExpenseNotification(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	notificationID, err := strconv.Atoi(c.Param("notification_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid notification ID",
		})
		return
	}

	// Parse request body
	var req models.ProcessRecurringNotificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
			"details": err.Error(),
		})
		return
	}

	// Get notification with template
	var notification models.RecurringExpenseNotification
	if err := config.DB.Preload("Template").First(&notification, notificationID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Recurring expense notification not found",
		})
		return
	}

	// Verify user has access to this notification
	if err := h.verifyRoomspaceMembership(notification.RoomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	switch req.Action {
	case "create_now":
		// Create the expense immediately
		if err := h.createExpenseFromTemplate(notification.Template, userID.(string)); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create expense from template",
				"details": err.Error(),
			})
			return
		}
		
		// Mark notification as processed
		if err := config.DB.Model(&notification).Updates(map[string]interface{}{
			"is_processed": true,
			"is_read":      true,
		}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update notification status",
			})
			return
		}

	case "schedule_later":
		if req.ScheduledDate == nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Scheduled date is required for schedule_later action",
			})
			return
		}
		
		// Update the scheduled date
		if err := config.DB.Model(&notification).Update("scheduled_date", *req.ScheduledDate).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to reschedule notification",
			})
			return
		}

	case "skip_once":
		// Mark as processed but don't create expense
		if err := config.DB.Model(&notification).Updates(map[string]interface{}{
			"is_processed": true,
			"is_read":      true,
		}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update notification status",
			})
			return
		}

	case "cancel":
		// Deactivate the template
		if err := config.DB.Model(notification.Template).Update("is_active", false).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to cancel recurring expense",
			})
			return
		}
		
		// Mark notification as processed
		if err := config.DB.Model(&notification).Updates(map[string]interface{}{
			"is_processed": true,
			"is_read":      true,
		}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update notification status",
			})
			return
		}

	default:
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid action. Must be one of: create_now, schedule_later, skip_once, cancel",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Notification processed with action: %s", req.Action),
	})
}

// createExpenseFromTemplate creates an expense from a recurring template
func (h *RecurringExpenseHandler) createExpenseFromTemplate(template *models.RecurringExpenseTemplate, userID string) error {
	// Create expense
	expense := &models.Expense{
		RoomspaceID: template.RoomspaceID,
		Title:       template.Title,
		Description: template.Description,
		Amount:      template.Amount,
		Category:    template.Category,
		PaidBy:      userID, // The user who processed the notification pays
		SplitType:   models.ExpenseSplitType(template.SplitType),
	}

	// Save expense
	if err := config.DB.Create(expense).Error; err != nil {
		return err
	}

	// Create splits
	var splits []models.ExpenseSplit
	totalAmount := template.Amount
	selectedRoommates := []string(template.SelectedRoommates)

	switch template.SplitType {
	case "EQUAL":
		amountPerPerson := totalAmount / float64(len(selectedRoommates))
		for _, roommateID := range selectedRoommates {
			splits = append(splits, models.ExpenseSplit{
				ExpenseID: expense.ID,
				UserUID:   roommateID,
				Amount:    amountPerPerson,
			})
		}

	case "PERCENTAGE":
		for _, roommateID := range selectedRoommates {
			if percentage, exists := template.CustomSplits[roommateID]; exists {
				amount := totalAmount * (percentage / 100.0)
				splits = append(splits, models.ExpenseSplit{
					ExpenseID:  expense.ID,
					UserUID:    roommateID,
					Amount:     amount,
					Percentage: percentage,
				})
			}
		}

	case "EXACT":
		for _, roommateID := range selectedRoommates {
			if amount, exists := template.CustomSplits[roommateID]; exists {
				splits = append(splits, models.ExpenseSplit{
					ExpenseID: expense.ID,
					UserUID:   roommateID,
					Amount:    amount,
				})
			}
		}
	}

	// Save splits
	if len(splits) > 0 {
		if err := config.DB.Create(&splits).Error; err != nil {
			return err
		}
	}

	// Update template occurrence count and last generated
	now := time.Now()
	if err := config.DB.Model(template).Updates(map[string]interface{}{
		"last_generated":   &now,
		"occurrence_count": template.OccurrenceCount + 1,
	}).Error; err != nil {
		return err
	}

	return nil
}

// verifyRoomspaceMembership verifies that a user is a member of a roomspace
func (h *RecurringExpenseHandler) verifyRoomspaceMembership(roomspaceID, userID string) error {
	var count int64
	if err := config.DB.Model(&models.RoomspaceMember{}).
		Where("roomspace_id = ? AND user_id = ? AND is_active = ?", roomspaceID, userID, true).
		Count(&count).Error; err != nil {
		return fmt.Errorf("failed to verify roomspace membership: %v", err)
	}

	if count == 0 {
		return fmt.Errorf("you are not a member of this roomspace")
	}

	return nil
}

// GetUpcomingRecurringExpenses gets upcoming recurring expenses for a roomspace
func (h *RecurringExpenseHandler) GetUpcomingRecurringExpenses(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	roomspaceID := c.Param("id")
	if roomspaceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Roomspace ID is required",
		})
		return
	}

	// Get days parameter (default 30)
	days := 30
	if daysParam := c.Query("days"); daysParam != "" {
		if parsedDays, err := strconv.Atoi(daysParam); err == nil && parsedDays > 0 {
			days = parsedDays
		}
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Use recurring expense service to get upcoming expenses
	recurringService := services.NewRecurringExpenseService(config.DB)
	upcomingTemplates, err := recurringService.GetUpcomingRecurringExpenses(roomspaceID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get upcoming recurring expenses",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    upcomingTemplates,
	})
}

// GetRecurringExpenseStats gets statistics for recurring expenses in a roomspace
func (h *RecurringExpenseHandler) GetRecurringExpenseStats(c *gin.Context) {
	// Get user ID from context
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	roomspaceID := c.Param("id")
	if roomspaceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Roomspace ID is required",
		})
		return
	}

	// Verify user is a member of the roomspace
	if err := h.verifyRoomspaceMembership(roomspaceID, userID.(string)); err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Use recurring expense service to get stats
	recurringService := services.NewRecurringExpenseService(config.DB)
	stats, err := recurringService.GetRecurringExpenseStats(roomspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get recurring expense statistics",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    stats,
	})
}