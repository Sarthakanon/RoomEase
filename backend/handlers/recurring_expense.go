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
	"gorm.io/gorm"
)

func shiftBackOneInterval(nextDate time.Time, interval models.RecurringInterval) time.Time {
	switch models.NormalizeRecurringInterval(interval) {
	case models.IntervalWeekly:
		return nextDate.AddDate(0, 0, -7)
	case models.IntervalMonthly:
		return nextDate.AddDate(0, -1, 0)
	case models.IntervalYearly:
		return nextDate.AddDate(-1, 0, 0)
	default:
		return nextDate.AddDate(0, -1, 0)
	}
}

func equalizeExactSplits(totalAmount float64, users []string) map[string]float64 {
	out := map[string]float64{}
	if len(users) == 0 {
		return out
	}
	totalCents := int64(totalAmount * 100.0)
	base := totalCents / int64(len(users))
	rem := totalCents % int64(len(users))
	for i, uid := range users {
		cents := base
		if int64(i) < rem {
			cents++
		}
		out[uid] = float64(cents) / 100.0
	}
	return out
}

func proportionalSplitCents(base map[string]float64, totalCents int64) map[string]int64 {
	result := map[string]int64{}
	if totalCents <= 0 || len(base) == 0 {
		return result
	}
	totalBase := 0.0
	for _, v := range base {
		if v > 0 {
			totalBase += v
		}
	}
	if totalBase <= 0 {
		return result
	}
	assigned := int64(0)
	for uid, v := range base {
		if v <= 0 {
			result[uid] = 0
			continue
		}
		cents := int64((v / totalBase) * float64(totalCents))
		result[uid] = cents
		assigned += cents
	}
	remaining := totalCents - assigned
	if remaining != 0 {
		var bestUID string
		best := -1.0
		for uid, v := range base {
			if v > best {
				best = v
				bestUID = uid
			}
		}
		result[bestUID] += remaining
	}
	return result
}

func normalizePayerAmounts(paidBy string, createdBy string, amount float64, payerAmounts map[string]float64) models.JSONFloatMap {
	out := models.JSONFloatMap{}
	total := 0.0
	for uid, a := range payerAmounts {
		if uid == "" || a <= 0 {
			continue
		}
		out[uid] = a
		total += a
	}
	if len(out) == 0 {
		fallback := paidBy
		if fallback == "" {
			fallback = createdBy
		}
		out[fallback] = amount
		return out
	}
	if (total-amount) > 0.01 || (amount-total) > 0.01 {
		// Keep API forgiving: normalize to template amount proportionally.
		scaled := models.JSONFloatMap{}
		for uid, a := range out {
			scaled[uid] = (a / total) * amount
		}
		return scaled
	}
	return out
}

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
	req.RecurringConfig.Interval = models.NormalizeRecurringInterval(req.RecurringConfig.Interval)

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
		PaidBy:            req.PaidBy,
		PayerAmounts:      normalizePayerAmounts(req.PaidBy, userID.(string), req.Amount, req.PayerAmounts),
		SelectedRoommates: models.StringArray(req.SelectedRoommates),
		SplitType:         req.SplitType,
		CustomSplits:      models.JSONFloatMap(req.CustomSplits),
		RecurringConfig:   req.RecurringConfig,
		IsActive:          true,
	}
	if template.PaidBy == "" {
		template.PaidBy = userID.(string)
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

	// Get templates: active/paused + recently deleted (undo window = 1 day)
	var templates []models.RecurringExpenseTemplate
	undoWindowStart := time.Now().Add(-24 * time.Hour)
	if err := config.DB.Where(
		"roomspace_id = ? AND (is_deleted = false OR (is_deleted = true AND deleted_at IS NOT NULL AND deleted_at >= ?))",
		roomspaceID,
		undoWindowStart,
	).
		Order("is_deleted ASC, is_active DESC, created_at DESC").
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
	if req.PaidBy != nil {
		updates["paid_by"] = *req.PaidBy
	}
	if req.PayerAmounts != nil {
		finalPaidBy := template.PaidBy
		if req.PaidBy != nil && *req.PaidBy != "" {
			finalPaidBy = *req.PaidBy
		}
		finalAmount := template.Amount
		if req.Amount != nil && *req.Amount > 0 {
			finalAmount = *req.Amount
		}
		updates["payer_amounts"] = normalizePayerAmounts(finalPaidBy, template.CreatedBy, finalAmount, req.PayerAmounts)
	}
	if req.SplitType != nil {
		updates["split_type"] = *req.SplitType
	}
	if req.SelectedRoommates != nil {
		updates["selected_roommates"] = models.StringArray(req.SelectedRoommates)
	}
	if req.CustomSplits != nil {
		updates["custom_splits"] = models.JSONFloatMap(req.CustomSplits)
	}
	if req.RecurringConfig != nil {
		req.RecurringConfig.Interval = models.NormalizeRecurringInterval(req.RecurringConfig.Interval)
		updates["recurring_config"] = *req.RecurringConfig
	}
	if req.NextScheduledDate != nil {
		interval := models.NormalizeRecurringInterval(template.RecurringConfig.Interval)
		if req.RecurringConfig != nil && req.RecurringConfig.Interval != "" {
			interval = models.NormalizeRecurringInterval(req.RecurringConfig.Interval)
		}
		// Normalize to date-only schedule anchor in UTC to avoid timezone drift.
		nextDate := time.Date(
			req.NextScheduledDate.UTC().Year(),
			req.NextScheduledDate.UTC().Month(),
			req.NextScheduledDate.UTC().Day(),
			12, 0, 0, 0,
			time.UTC,
		)
		lastGenerated := shiftBackOneInterval(nextDate, interval)
		updates["last_generated"] = lastGenerated
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	// Any update on a deleted item restores it by intent.
	updates["is_deleted"] = false
	updates["deleted_at"] = nil
	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No fields provided for update",
		})
		return
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
			"error":   "Failed to reload updated template",
			"details": err.Error(),
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

	now := time.Now().UTC()
	// Soft-delete with 24h undo window
	if err := config.DB.Model(&template).UpdateColumns(map[string]interface{}{
		"is_active":  false,
		"is_deleted": true,
		"deleted_at": now,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete recurring expense template",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Recurring expense template deleted successfully. You can undo within 24 hours.",
	})
}

// RestoreRecurringExpenseTemplate restores a soft-deleted recurring template (within 24h).
func (h *RecurringExpenseHandler) RestoreRecurringExpenseTemplate(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	templateID, err := strconv.Atoi(c.Param("template_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid template ID"})
		return
	}

	var template models.RecurringExpenseTemplate
	if err := config.DB.First(&template, templateID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Recurring expense template not found"})
		return
	}

	if template.CreatedBy != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only restore templates you created"})
		return
	}

	if !template.IsDeleted || template.DeletedAt == nil || template.DeletedAt.Before(time.Now().Add(-24*time.Hour)) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Restore window expired for this recurring payment"})
		return
	}

	if err := config.DB.Model(&template).UpdateColumns(map[string]interface{}{
		"is_deleted": false,
		"deleted_at": gorm.Expr("NULL"),
		"is_active":  true,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to restore recurring expense template",
			"details": err.Error(),
		})
		return
	}

	if err := config.DB.First(&template, templateID).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to reload restored template",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Recurring expense template restored successfully",
		"data":    template,
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
		// roomspace_members.roomspace_id is UUID in some DBs while template roomspace_id is text.
		// Cast UUID -> text to avoid `operator does not exist: text = uuid`.
		Joins("JOIN roomspace_members ON recurring_expense_templates.roomspace_id = roomspace_members.roomspace_id::text").
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
	payerAmounts := map[string]float64(template.PayerAmounts)
	for k, v := range payerAmounts {
		if v <= 0 {
			delete(payerAmounts, k)
		}
	}
	if len(payerAmounts) == 0 {
		fallback := template.PaidBy
		if fallback == "" {
			fallback = userID
		}
		payerAmounts[fallback] = template.Amount
	}

	baseExact := map[string]float64{}
	roommates := []string(template.SelectedRoommates)
	switch template.SplitType {
	case "EQUAL":
		baseExact = equalizeExactSplits(template.Amount, roommates)
	case "PERCENTAGE":
		for _, uid := range roommates {
			p := template.CustomSplits[uid]
			baseExact[uid] = template.Amount * (p / 100.0)
		}
	case "EXACT":
		for _, uid := range roommates {
			baseExact[uid] = template.CustomSplits[uid]
		}
	default:
		baseExact = equalizeExactSplits(template.Amount, roommates)
	}

	totalCents := int64(template.Amount * 100.0)
	assigned := int64(0)
	index := 0
	for uid, amt := range payerAmounts {
		payerCents := int64(amt * 100.0)
		if payerCents <= 0 {
			continue
		}
		if index == len(payerAmounts)-1 {
			payerCents = totalCents - assigned
		}
		assigned += payerCents
		index++
		if payerCents <= 0 {
			continue
		}

		expense := &models.Expense{
			RoomspaceID: template.RoomspaceID,
			Title:       template.Title,
			Description: template.Description,
			Amount:      float64(payerCents) / 100.0,
			Category:    template.Category,
			PaidBy:      uid,
			SplitType:   models.SplitTypeExact,
		}
		if expense.PaidBy == "" {
			expense.PaidBy = userID
		}
		if err := config.DB.Create(expense).Error; err != nil {
			return err
		}

		subSplitCents := proportionalSplitCents(baseExact, payerCents)
		var splits []models.ExpenseSplit
		for roommateID, cents := range subSplitCents {
			if cents <= 0 {
				continue
			}
			splits = append(splits, models.ExpenseSplit{
				ExpenseID: expense.ID,
				UserUID:   roommateID,
				Amount:    float64(cents) / 100.0,
			})
		}
		if len(splits) > 0 {
			if err := config.DB.Create(&splits).Error; err != nil {
				return err
			}
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
