package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SubscriptionPayment represents a subscription payment record
type SubscriptionPayment struct {
	ID              uuid.UUID              `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	UserID          string                 `json:"user_id" gorm:"not null;index"`
	PlanID          string                 `json:"plan_id" gorm:"not null"`
	Amount          float64                `json:"amount" gorm:"not null"`
	TransactionUUID string                 `json:"transaction_uuid" gorm:"not null;unique"`
	TransactionCode string                 `json:"transaction_code" gorm:"not null"`
	PaymentMethod   string                 `json:"payment_method" gorm:"not null;default:'esewa'"`
	Status          string                 `json:"status" gorm:"not null;default:'pending'"`
	EsewaResponse   map[string]interface{} `json:"esewa_response" gorm:"type:jsonb"`
	CreatedAt       time.Time              `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt       time.Time              `json:"updated_at" gorm:"autoUpdateTime"`
}

// BalanceSettlement represents a balance settlement payment record
type BalanceSettlement struct {
	ID              uuid.UUID              `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	RoomspaceID     string                 `json:"roomspace_id" gorm:"not null;index"`
	PayerUserID     string                 `json:"payer_user_id" gorm:"not null;index"`
	RecipientUserID string                 `json:"recipient_user_id" gorm:"not null;index"`
	Amount          float64                `json:"amount" gorm:"not null"`
	Description     string                 `json:"description"`
	TransactionUUID string                 `json:"transaction_uuid" gorm:"not null;unique"`
	TransactionCode string                 `json:"transaction_code" gorm:"not null"`
	PaymentMethod   string                 `json:"payment_method" gorm:"not null;default:'esewa'"`
	Status          string                 `json:"status" gorm:"not null;default:'pending'"`
	EsewaResponse   map[string]interface{} `json:"esewa_response" gorm:"type:jsonb"`
	CreatedAt       time.Time              `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt       time.Time              `json:"updated_at" gorm:"autoUpdateTime"`

	// Relationships
	Roomspace *Roomspace `json:"roomspace,omitempty" gorm:"foreignKey:RoomspaceID;references:ID"`
	PayerUser *User      `json:"payer_user,omitempty" gorm:"foreignKey:PayerUserID;references:FirebaseUID"`
	Recipient *User      `json:"recipient_user,omitempty" gorm:"foreignKey:RecipientUserID;references:FirebaseUID"`
}

// PaymentHistoryItem represents a unified payment history item
type PaymentHistoryItem struct {
	ID              string                 `json:"id"`
	Type            string                 `json:"type"` // "subscription" or "settlement"
	Amount          float64                `json:"amount"`
	Description     string                 `json:"description"`
	TransactionUUID string                 `json:"transaction_uuid"`
	TransactionCode string                 `json:"transaction_code"`
	PaymentMethod   string                 `json:"payment_method"`
	Status          string                 `json:"status"`
	CreatedAt       time.Time              `json:"created_at"`
	
	// Type-specific fields
	PlanID          *string `json:"plan_id,omitempty"`          // For subscription payments
	RoomspaceID     *string `json:"roomspace_id,omitempty"`     // For settlements
	RecipientUserID *string `json:"recipient_user_id,omitempty"` // For settlements
	RecipientName   *string `json:"recipient_name,omitempty"`   // For settlements
}

// BeforeCreate sets up the model before creation
func (sp *SubscriptionPayment) BeforeCreate(tx *gorm.DB) error {
	if sp.ID == uuid.Nil {
		sp.ID = uuid.New()
	}
	return nil
}

// BeforeCreate sets up the model before creation
func (bs *BalanceSettlement) BeforeCreate(tx *gorm.DB) error {
	if bs.ID == uuid.Nil {
		bs.ID = uuid.New()
	}
	return nil
}

// TableName returns the table name for SubscriptionPayment
func (SubscriptionPayment) TableName() string {
	return "subscription_payments"
}

// TableName returns the table name for BalanceSettlement
func (BalanceSettlement) TableName() string {
	return "balance_settlements"
}