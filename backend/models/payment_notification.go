package models

import (
	"time"

	"gorm.io/gorm"
)

// PaymentNotificationType represents the type of payment
type PaymentNotificationType string

const (
	PaymentTypeDebit  PaymentNotificationType = "DEBIT"
	PaymentTypeCredit PaymentNotificationType = "CREDIT"
)

// PaymentNotification represents a detected payment notification
type PaymentNotification struct {
	ID          uint                     `gorm:"primaryKey" json:"id"`
	UserUID     string                   `gorm:"not null;index" json:"user_uid"` // Firebase UID of user
	Amount      float64                  `gorm:"not null" json:"amount"`
	Merchant    string                   `gorm:"not null" json:"merchant"`
	AppName     string                   `gorm:"not null" json:"app_name"`
	RawText     string                   `gorm:"type:text" json:"raw_text"`
	Type        PaymentNotificationType  `gorm:"not null" json:"type"`
	Timestamp   time.Time                `gorm:"not null" json:"timestamp"`
	IsProcessed bool                     `gorm:"default:false" json:"is_processed"` // Whether user created expense from this
	ExpenseID   *uint                    `gorm:"index" json:"expense_id,omitempty"` // Link to created expense if any
	CreatedAt   time.Time                `json:"created_at"`
	UpdatedAt   time.Time                `json:"updated_at"`
	DeletedAt   gorm.DeletedAt           `gorm:"index" json:"-"`

	// Relationships
	User    *User    `gorm:"foreignKey:UserUID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"user,omitempty"`
	Expense *Expense `gorm:"foreignKey:ExpenseID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"expense,omitempty"`
}

// PaymentNotificationCreateRequest represents the request to create a payment notification
type PaymentNotificationCreateRequest struct {
	Amount    float64                  `json:"amount" binding:"required,gt=0"`
	Merchant  string                   `json:"merchant" binding:"required"`
	AppName   string                   `json:"app_name" binding:"required"`
	RawText   string                   `json:"raw_text" binding:"required"`
	Type      PaymentNotificationType  `json:"type" binding:"required"`
	Timestamp time.Time                `json:"timestamp" binding:"required"`
}

// PaymentNotificationResponse represents the response for payment notification data
type PaymentNotificationResponse struct {
	ID          uint                     `json:"id"`
	Amount      float64                  `json:"amount"`
	Merchant    string                   `json:"merchant"`
	AppName     string                   `json:"app_name"`
	RawText     string                   `json:"raw_text"`
	Type        PaymentNotificationType  `json:"type"`
	Timestamp   time.Time                `json:"timestamp"`
	IsProcessed bool                     `json:"is_processed"`
	ExpenseID   *uint                    `json:"expense_id,omitempty"`
	CreatedAt   time.Time                `json:"created_at"`
}