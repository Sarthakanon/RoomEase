package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
)

// RecurringInterval represents the interval for recurring expenses
type RecurringInterval string

const (
	IntervalWeekly  RecurringInterval = "weekly"
	IntervalMonthly RecurringInterval = "monthly"
	IntervalYearly  RecurringInterval = "yearly"
)

// RecurringConfig represents the configuration for recurring expenses
type RecurringConfig struct {
	IsRecurring             bool              `json:"is_recurring"`
	Interval                RecurringInterval `json:"interval,omitempty"`
	StartDate               *time.Time        `json:"start_date,omitempty"`
	EndDate                 *time.Time        `json:"end_date,omitempty"`
	MaxOccurrences          *int              `json:"max_occurrences,omitempty"`
	NotifyBeforeCreation    bool              `json:"notify_before_creation"`
	NotificationDaysBefore  int               `json:"notification_days_before"`
}

// Value implements the driver.Valuer interface for database storage
func (rc RecurringConfig) Value() (driver.Value, error) {
	return json.Marshal(rc)
}

// Scan implements the sql.Scanner interface for database retrieval
func (rc *RecurringConfig) Scan(value interface{}) error {
	if value == nil {
		return nil
	}

	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(bytes, rc)
}

// RecurringExpenseTemplate represents a template for recurring expenses
type RecurringExpenseTemplate struct {
	ID                int                    `json:"id" gorm:"primaryKey"`
	RoomspaceID       string                 `json:"roomspace_id" gorm:"not null;index"`
	Title             string                 `json:"title" gorm:"not null"`
	Description       string                 `json:"description"`
	Amount            float64                `json:"amount" gorm:"not null"`
	Category          string                 `json:"category" gorm:"not null"`
	CreatedBy         string                 `json:"created_by" gorm:"not null;index"`
	SelectedRoommates StringArray            `json:"selected_roommates" gorm:"type:text"`
	SplitType         string                 `json:"split_type" gorm:"not null"`
	CustomSplits      map[string]float64     `json:"custom_splits" gorm:"type:jsonb"`
	RecurringConfig   RecurringConfig        `json:"recurring_config" gorm:"type:jsonb"`
	CreatedAt         time.Time              `json:"created_at"`
	UpdatedAt         time.Time              `json:"updated_at"`
	LastGenerated     *time.Time             `json:"last_generated,omitempty"`
	OccurrenceCount   int                    `json:"occurrence_count" gorm:"default:0"`
	IsActive          bool                   `json:"is_active" gorm:"default:true"`
}

// TableName specifies the table name for RecurringExpenseTemplate
func (RecurringExpenseTemplate) TableName() string {
	return "recurring_expense_templates"
}

// GetNextScheduledDate calculates the next scheduled date for this recurring expense
func (ret *RecurringExpenseTemplate) GetNextScheduledDate() *time.Time {
	if !ret.RecurringConfig.IsRecurring {
		return nil
	}

	baseDate := ret.CreatedAt
	if ret.LastGenerated != nil {
		baseDate = *ret.LastGenerated
	}

	var nextDate time.Time
	switch ret.RecurringConfig.Interval {
	case IntervalWeekly:
		nextDate = baseDate.AddDate(0, 0, 7)
	case IntervalMonthly:
		nextDate = baseDate.AddDate(0, 1, 0)
	case IntervalYearly:
		nextDate = baseDate.AddDate(1, 0, 0)
	default:
		return nil
	}

	return &nextDate
}

// ShouldGenerateExpense checks if this template should generate a new expense
func (ret *RecurringExpenseTemplate) ShouldGenerateExpense(currentDate time.Time) bool {
	if !ret.IsActive || !ret.RecurringConfig.IsRecurring {
		return false
	}

	nextDate := ret.GetNextScheduledDate()
	if nextDate == nil {
		return false
	}

	// Check if it's time to generate
	shouldGenerate := currentDate.After(*nextDate) || currentDate.Equal(*nextDate)
	if !shouldGenerate {
		return false
	}

	// Check if recurring should end
	return !ret.ShouldEnd(currentDate)
}

// ShouldEnd checks if the recurring expense should end
func (ret *RecurringExpenseTemplate) ShouldEnd(currentDate time.Time) bool {
	if !ret.RecurringConfig.IsRecurring {
		return true
	}

	// Check end date
	if ret.RecurringConfig.EndDate != nil && currentDate.After(*ret.RecurringConfig.EndDate) {
		return true
	}

	// Check max occurrences
	if ret.RecurringConfig.MaxOccurrences != nil && ret.OccurrenceCount >= *ret.RecurringConfig.MaxOccurrences {
		return true
	}

	return false
}

// ShouldSendNotification checks if a notification should be sent
func (ret *RecurringExpenseTemplate) ShouldSendNotification(currentDate time.Time) bool {
	if !ret.IsActive || !ret.RecurringConfig.IsRecurring || !ret.RecurringConfig.NotifyBeforeCreation {
		return false
	}

	nextDate := ret.GetNextScheduledDate()
	if nextDate == nil {
		return false
	}

	notificationDate := nextDate.AddDate(0, 0, -ret.RecurringConfig.NotificationDaysBefore)
	return currentDate.After(notificationDate) && currentDate.Before(*nextDate)
}

// RecurringExpenseNotification represents a notification for a pending recurring expense
type RecurringExpenseNotification struct {
	ID               int       `json:"id" gorm:"primaryKey"`
	TemplateID       int       `json:"template_id" gorm:"not null;index"`
	RoomspaceID      string    `json:"roomspace_id" gorm:"not null;index"`
	Title            string    `json:"title" gorm:"not null"`
	Amount           float64   `json:"amount" gorm:"not null"`
	ScheduledDate    time.Time `json:"scheduled_date" gorm:"not null"`
	NotificationDate time.Time `json:"notification_date" gorm:"not null"`
	IsRead           bool      `json:"is_read" gorm:"default:false"`
	IsProcessed      bool      `json:"is_processed" gorm:"default:false"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`

	// Relationships
	Template *RecurringExpenseTemplate `json:"template,omitempty" gorm:"foreignKey:TemplateID"`
}

// TableName specifies the table name for RecurringExpenseNotification
func (RecurringExpenseNotification) TableName() string {
	return "recurring_expense_notifications"
}

// CreateRecurringExpenseRequest represents the request to create a recurring expense template
type CreateRecurringExpenseRequest struct {
	RoomspaceID       string                 `json:"roomspace_id" binding:"required"`
	Title             string                 `json:"title" binding:"required"`
	Description       string                 `json:"description"`
	Amount            float64                `json:"amount" binding:"required,gt=0"`
	Category          string                 `json:"category" binding:"required"`
	PaidBy            string                 `json:"paid_by"`
	SplitType         string                 `json:"split_type" binding:"required"`
	SelectedRoommates []string               `json:"selected_roommates" binding:"required"`
	CustomSplits      map[string]float64     `json:"custom_splits"`
	RecurringConfig   RecurringConfig        `json:"recurring_config" binding:"required"`
}

// UpdateRecurringExpenseRequest represents the request to update a recurring expense template
type UpdateRecurringExpenseRequest struct {
	Title             *string                `json:"title"`
	Description       *string                `json:"description"`
	Amount            *float64               `json:"amount"`
	Category          *string                `json:"category"`
	PaidBy            *string                `json:"paid_by"`
	SplitType         *string                `json:"split_type"`
	SelectedRoommates []string               `json:"selected_roommates"`
	CustomSplits      map[string]float64     `json:"custom_splits"`
	RecurringConfig   *RecurringConfig       `json:"recurring_config"`
	IsActive          *bool                  `json:"is_active"`
}

// ProcessRecurringNotificationRequest represents the request to process a recurring notification
type ProcessRecurringNotificationRequest struct {
	Action        string     `json:"action" binding:"required"` // "create_now", "schedule_later", "skip_once", "cancel"
	ScheduledDate *time.Time `json:"scheduled_date,omitempty"`  // For "schedule_later"
}

// StringArray is a custom type for handling string arrays in GORM
type StringArray []string

// Value implements the driver.Valuer interface
func (sa StringArray) Value() (driver.Value, error) {
	return json.Marshal(sa)
}

// Scan implements the sql.Scanner interface
func (sa *StringArray) Scan(value interface{}) error {
	if value == nil {
		return nil
	}

	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(bytes, sa)
}

// BeforeCreate hook for RecurringExpenseTemplate
func (ret *RecurringExpenseTemplate) BeforeCreate(tx *gorm.DB) error {
	now := time.Now()
	ret.CreatedAt = now
	ret.UpdatedAt = now
	return nil
}

// BeforeUpdate hook for RecurringExpenseTemplate
func (ret *RecurringExpenseTemplate) BeforeUpdate(tx *gorm.DB) error {
	ret.UpdatedAt = time.Now()
	return nil
}

// BeforeCreate hook for RecurringExpenseNotification
func (ren *RecurringExpenseNotification) BeforeCreate(tx *gorm.DB) error {
	now := time.Now()
	ren.CreatedAt = now
	ren.UpdatedAt = now
	return nil
}

// BeforeUpdate hook for RecurringExpenseNotification
func (ren *RecurringExpenseNotification) BeforeUpdate(tx *gorm.DB) error {
	ren.UpdatedAt = time.Now()
	return nil
}