package models

import (
	"time"

	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// ExpenseHistoryType represents the type of history event
type ExpenseHistoryType string

const (
	HistoryTypeExpenseCreated     ExpenseHistoryType = "expense_created"
	HistoryTypeExpenseEdited      ExpenseHistoryType = "expense_edited"
	HistoryTypeExpenseDeleted     ExpenseHistoryType = "expense_deleted"
	HistoryTypePaymentConfirmed   ExpenseHistoryType = "payment_confirmed"
	HistoryTypeSettlementMade     ExpenseHistoryType = "settlement_made"
	HistoryTypeMemberAdded        ExpenseHistoryType = "member_added"
	HistoryTypeMemberRemoved      ExpenseHistoryType = "member_removed"
)

// ExpenseHistory represents a history record for expense-related activities
type ExpenseHistory struct {
	ID              uint               `gorm:"primaryKey" json:"id"`
	RoomspaceID     string             `gorm:"type:varchar(36);not null;index" json:"roomspace_id"`
	Type            ExpenseHistoryType `gorm:"type:varchar(50);not null" json:"type"`
	Title           string             `gorm:"type:varchar(255);not null" json:"title"`
	Description     string             `gorm:"type:text" json:"description"`
	PerformedBy     string             `gorm:"type:varchar(128);not null" json:"performed_by"` // Firebase UID
	PerformedByName string             `gorm:"type:varchar(255)" json:"performed_by_name"`
	Amount          *float64           `json:"amount,omitempty"`
	Metadata        datatypes.JSONMap  `gorm:"type:jsonb" json:"metadata,omitempty"`
	Timestamp       time.Time          `gorm:"not null;index" json:"timestamp"`
	CreatedAt       time.Time          `json:"created_at"`
	DeletedAt       gorm.DeletedAt     `gorm:"index" json:"-"`

	// Relationships
	Roomspace *Roomspace `gorm:"foreignKey:RoomspaceID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"roomspace,omitempty"`
	User      *User      `gorm:"foreignKey:PerformedBy;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"user,omitempty"`
}

// CreateExpenseHistoryRequest represents the request to create a history entry
type CreateExpenseHistoryRequest struct {
	Type        string                 `json:"type" binding:"required"`
	Title       string                 `json:"title" binding:"required"`
	Description string                 `json:"description"`
	PerformedBy string                 `json:"performed_by" binding:"required"`
	Amount      *float64               `json:"amount,omitempty"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

// ExpenseHistoryResponse represents the response for history data
type ExpenseHistoryResponse struct {
	ID              uint               `json:"id"`
	Type            ExpenseHistoryType `json:"type"`
	Title           string             `json:"title"`
	Description     string             `json:"description"`
	PerformedBy     string             `json:"performed_by"`
	PerformedByName string             `json:"performed_by_name"`
	Amount          *float64           `json:"amount,omitempty"`
	Metadata        map[string]interface{} `json:"metadata,omitempty"`
	Timestamp       time.Time          `json:"timestamp"`
}
