package services

import (
	"fmt"
	"log"
	"roomease/backend/models"
	"time"

	"gorm.io/gorm"
)

// RecurringExpenseService handles recurring expense processing
type RecurringExpenseService struct {
	db *gorm.DB
}

// NewRecurringExpenseService creates a new recurring expense service
func NewRecurringExpenseService(db *gorm.DB) *RecurringExpenseService {
	return &RecurringExpenseService{
		db: db,
	}
}

// ProcessRecurringExpenses processes all due recurring expenses
func (s *RecurringExpenseService) ProcessRecurringExpenses() error {
	log.Println("Starting recurring expense processing...")
	
	currentTime := time.Now()
	
	// Get all active recurring expense templates
	var templates []models.RecurringExpenseTemplate
	if err := s.db.Where("is_active = ?", true).Find(&templates).Error; err != nil {
		return fmt.Errorf("failed to fetch recurring expense templates: %v", err)
	}
	
	log.Printf("Found %d active recurring expense templates", len(templates))
	
	for _, template := range templates {
		if err := s.processTemplate(&template, currentTime); err != nil {
			log.Printf("Error processing template %d: %v", template.ID, err)
			continue
		}
	}
	
	log.Println("Completed recurring expense processing")
	return nil
}

// processTemplate processes a single recurring expense template
func (s *RecurringExpenseService) processTemplate(template *models.RecurringExpenseTemplate, currentTime time.Time) error {
	// Check if template should send notification
	if template.ShouldSendNotification(currentTime) {
		if err := s.createNotificationIfNotExists(template, currentTime); err != nil {
			return fmt.Errorf("failed to create notification for template %d: %v", template.ID, err)
		}
	}
	
	// Check if template should generate expense automatically (if notification is disabled)
	if !template.RecurringConfig.NotifyBeforeCreation && template.ShouldGenerateExpense(currentTime) {
		if err := s.generateExpenseFromTemplate(template); err != nil {
			return fmt.Errorf("failed to generate expense from template %d: %v", template.ID, err)
		}
	}
	
	// Check if template should be deactivated
	if template.ShouldEnd(currentTime) {
		if err := s.db.Model(template).Update("is_active", false).Error; err != nil {
			return fmt.Errorf("failed to deactivate template %d: %v", template.ID, err)
		}
		log.Printf("Deactivated recurring expense template %d (reached end condition)", template.ID)
	}
	
	return nil
}

// createNotificationIfNotExists creates a notification if it doesn't already exist
func (s *RecurringExpenseService) createNotificationIfNotExists(template *models.RecurringExpenseTemplate, currentTime time.Time) error {
	nextDate := template.GetNextScheduledDate()
	if nextDate == nil {
		return nil
	}
	
	// Check if notification already exists for this scheduled date
	var existingCount int64
	if err := s.db.Model(&models.RecurringExpenseNotification{}).
		Where("template_id = ? AND scheduled_date = ?", template.ID, *nextDate).
		Count(&existingCount).Error; err != nil {
		return err
	}
	
	if existingCount > 0 {
		return nil // Notification already exists
	}
	
	// Create notification
	notification := &models.RecurringExpenseNotification{
		TemplateID:       template.ID,
		RoomspaceID:      template.RoomspaceID,
		Title:            template.Title,
		Amount:           template.Amount,
		ScheduledDate:    *nextDate,
		NotificationDate: currentTime,
		IsRead:           false,
		IsProcessed:      false,
	}
	
	if err := s.db.Create(notification).Error; err != nil {
		return err
	}
	
	log.Printf("Created notification for recurring expense template %d, scheduled for %s", 
		template.ID, nextDate.Format("2006-01-02"))
	
	return nil
}

// generateExpenseFromTemplate automatically generates an expense from a template
func (s *RecurringExpenseService) generateExpenseFromTemplate(template *models.RecurringExpenseTemplate) error {
	// Create expense
	expense := &models.Expense{
		RoomspaceID: template.RoomspaceID,
		Title:       template.Title,
		Description: template.Description,
		Amount:      template.Amount,
		Category:    template.Category,
		PaidBy:      template.CreatedBy, // Default to template creator
		SplitType:   models.ExpenseSplitType(template.SplitType),
	}
	
	// Save expense
	if err := s.db.Create(expense).Error; err != nil {
		return err
	}
	
	// Create splits
	if err := s.createSplitsFromTemplate(expense, template); err != nil {
		return err
	}
	
	// Update template
	now := time.Now()
	if err := s.db.Model(template).Updates(map[string]interface{}{
		"last_generated":   &now,
		"occurrence_count": template.OccurrenceCount + 1,
	}).Error; err != nil {
		return err
	}
	
	log.Printf("Auto-generated expense %d from recurring template %d", expense.ID, template.ID)
	
	return nil
}

// createSplitsFromTemplate creates expense splits based on template configuration
func (s *RecurringExpenseService) createSplitsFromTemplate(expense *models.Expense, template *models.RecurringExpenseTemplate) error {
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
		if err := s.db.Create(&splits).Error; err != nil {
			return err
		}
	}
	
	return nil
}

// CleanupOldNotifications removes old processed notifications
func (s *RecurringExpenseService) CleanupOldNotifications() error {
	// Remove notifications older than 30 days that are processed
	cutoffDate := time.Now().AddDate(0, 0, -30)
	
	result := s.db.Where("is_processed = ? AND created_at < ?", true, cutoffDate).
		Delete(&models.RecurringExpenseNotification{})
	
	if result.Error != nil {
		return fmt.Errorf("failed to cleanup old notifications: %v", result.Error)
	}
	
	log.Printf("Cleaned up %d old recurring expense notifications", result.RowsAffected)
	return nil
}

// GetUpcomingRecurringExpenses gets upcoming recurring expenses for a roomspace
func (s *RecurringExpenseService) GetUpcomingRecurringExpenses(roomspaceID string, days int) ([]models.RecurringExpenseTemplate, error) {
	var templates []models.RecurringExpenseTemplate
	
	// Get active templates for the roomspace
	if err := s.db.Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).
		Find(&templates).Error; err != nil {
		return nil, err
	}
	
	// Filter templates that have upcoming expenses within the specified days
	var upcomingTemplates []models.RecurringExpenseTemplate
	currentTime := time.Now()
	futureTime := currentTime.AddDate(0, 0, days)
	
	for _, template := range templates {
		nextDate := template.GetNextScheduledDate()
		if nextDate != nil && nextDate.After(currentTime) && nextDate.Before(futureTime) {
			upcomingTemplates = append(upcomingTemplates, template)
		}
	}
	
	return upcomingTemplates, nil
}

// GetRecurringExpenseStats gets statistics for recurring expenses
func (s *RecurringExpenseService) GetRecurringExpenseStats(roomspaceID string) (map[string]interface{}, error) {
	stats := make(map[string]interface{})
	
	// Count active templates
	var activeCount int64
	if err := s.db.Model(&models.RecurringExpenseTemplate{}).
		Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).
		Count(&activeCount).Error; err != nil {
		return nil, err
	}
	stats["active_templates"] = activeCount
	
	// Count pending notifications
	var pendingCount int64
	if err := s.db.Model(&models.RecurringExpenseNotification{}).
		Where("roomspace_id = ? AND is_processed = ?", roomspaceID, false).
		Count(&pendingCount).Error; err != nil {
		return nil, err
	}
	stats["pending_notifications"] = pendingCount
	
	// Calculate total monthly recurring amount
	var templates []models.RecurringExpenseTemplate
	if err := s.db.Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).
		Find(&templates).Error; err != nil {
		return nil, err
	}
	
	var monthlyTotal float64
	for _, template := range templates {
		switch template.RecurringConfig.Interval {
		case models.IntervalWeekly:
			monthlyTotal += template.Amount * 4.33 // Average weeks per month
		case models.IntervalMonthly:
			monthlyTotal += template.Amount
		case models.IntervalYearly:
			monthlyTotal += template.Amount / 12
		}
	}
	stats["estimated_monthly_total"] = monthlyTotal
	
	return stats, nil
}