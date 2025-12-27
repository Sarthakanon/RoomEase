package models

import (
	"time"

	"gorm.io/gorm"
)

// ExpenseSplitType represents the type of expense split
type ExpenseSplitType string

const (
	SplitTypeEqual      ExpenseSplitType = "EQUAL"
	SplitTypePercentage ExpenseSplitType = "PERCENTAGE"
	SplitTypeExact      ExpenseSplitType = "EXACT"
)

// Expense represents an expense record
type Expense struct {
	ID          uint             `gorm:"primaryKey" json:"id"`
	RoomspaceID string           `gorm:"type:varchar(36);not null;index;constraint:OnDelete:CASCADE" json:"roomspace_id"`
	Title       string           `gorm:"not null;size:255;check:length(title) > 0" json:"title"`
	Description string           `gorm:"size:1000" json:"description"`
	Amount      float64          `gorm:"not null;check:amount > 0" json:"amount"`
	Category    string           `gorm:"not null;size:100;check:length(category) > 0" json:"category"`
	PaidBy      string           `gorm:"not null;size:128;check:length(paid_by) > 0" json:"paid_by"` // Firebase UID
	SplitType   ExpenseSplitType `gorm:"not null;check:split_type IN ('EQUAL','PERCENTAGE','EXACT')" json:"split_type"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
	DeletedAt   gorm.DeletedAt   `gorm:"index" json:"-"`

	// Relationships with proper constraints
	Roomspace *Roomspace     `gorm:"foreignKey:RoomspaceID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"roomspace,omitempty"`
	Payer     *User          `gorm:"foreignKey:PaidBy;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"payer,omitempty"`
	Splits    []ExpenseSplit `gorm:"foreignKey:ExpenseID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"splits,omitempty"`
}

// ExpenseSplit represents an individual split record for each roommate
type ExpenseSplit struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	ExpenseID  uint      `gorm:"not null;index;constraint:OnDelete:CASCADE" json:"expense_id"`
	UserUID    string    `gorm:"not null;size:128;check:length(user_uid) > 0" json:"user_uid"` // Firebase UID
	Amount     float64   `gorm:"not null;check:amount > 0" json:"amount"`
	Percentage float64   `gorm:"check:percentage >= 0 AND percentage <= 100" json:"percentage,omitempty"` // For percentage splits
	CreatedAt  time.Time `json:"created_at"`

	// Relationships with proper constraints
	Expense *Expense `gorm:"foreignKey:ExpenseID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"expense,omitempty"`
	User    *User    `gorm:"foreignKey:UserUID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"user,omitempty"`
}

// CreateExpenseRequest represents the request to create an expense
type CreateExpenseRequest struct {
	RoomspaceID       string                 `json:"roomspace_id" binding:"required"`
	Title             string                 `json:"title" binding:"required"`
	Description       string                 `json:"description"`
	Amount            float64                `json:"amount" binding:"required,gt=0"`
	Category          string                 `json:"category" binding:"required"`
	SplitType         ExpenseSplitType       `json:"split_type" binding:"required"`
	SelectedRoommates []string               `json:"selected_roommates" binding:"required,min=1"`
	CustomSplits      map[string]float64     `json:"custom_splits,omitempty"`
}

// ExpenseResponse represents the response for expense data
type ExpenseResponse struct {
	ID          uint                   `json:"id"`
	Title       string                 `json:"title"`
	Description string                 `json:"description"`
	Amount      float64                `json:"amount"`
	Category    string                 `json:"category"`
	PaidBy      string                 `json:"paid_by"`
	PayerName   string                 `json:"payer_name"`
	SplitType   ExpenseSplitType       `json:"split_type"`
	CreatedAt   time.Time              `json:"created_at"`
	Splits      []ExpenseSplitResponse `json:"splits"`
}

// ExpenseSplitResponse represents the response for expense split data
type ExpenseSplitResponse struct {
	UserUID    string  `json:"user_uid"`
	UserName   string  `json:"user_name"`
	Amount     float64 `json:"amount"`
	Percentage float64 `json:"percentage,omitempty"`
}