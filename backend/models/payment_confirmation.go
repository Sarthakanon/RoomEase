package models

import (
	"errors"
	"time"
)

// Payment confirmation status types
type PaymentStatus string

const (
	PaymentStatusPending   PaymentStatus = "PENDING"
	PaymentStatusConfirmed PaymentStatus = "CONFIRMED"
	PaymentStatusRejected  PaymentStatus = "REJECTED"
)

// Payment type (full or partial)
type PaymentTypeEnum string

const (
	PaymentTypeFull    PaymentTypeEnum = "FULL"
	PaymentTypePartial PaymentTypeEnum = "PARTIAL"
)

// Validation errors
var (
	ErrSelfPayment          = errors.New("cannot record payment to yourself")
	ErrInvalidPaymentAmount = errors.New("payment amount must be positive")
	ErrAlreadyConfirmed     = errors.New("payment already confirmed")
	ErrAlreadyRejected      = errors.New("payment already rejected")
	ErrUnauthorized         = errors.New("only recipient can confirm/reject payment")
)

// PaymentConfirmation represents a payment claim between two users
type PaymentConfirmation struct {
	ID              uint            `gorm:"primaryKey" json:"id"`
	RoomspaceID     string          `gorm:"type:uuid;not null;index:idx_roomspace_status" json:"roomspace_id"`
	FromUserID      string          `gorm:"type:varchar(255);not null;index:idx_from_user" json:"from_user_id"` // User who paid
	ToUserID        string          `gorm:"type:varchar(255);not null;index:idx_to_user" json:"to_user_id"`     // User who received
	Amount          float64         `gorm:"type:decimal(10,2);not null;check:amount > 0" json:"amount"`
	PaymentType     PaymentTypeEnum `gorm:"type:varchar(20);not null" json:"payment_type"`
	Status          PaymentStatus   `gorm:"type:varchar(20);not null;default:'PENDING';index:idx_roomspace_status" json:"status"`
	Notes           string          `gorm:"type:text" json:"notes,omitempty"`
	PaymentProofURL string          `gorm:"type:text" json:"payment_proof_url,omitempty"`
	PaymentDate     time.Time       `gorm:"not null" json:"payment_date"`
	ConfirmedAt     *time.Time      `json:"confirmed_at,omitempty"`
	ConfirmedBy     *string         `gorm:"type:varchar(255)" json:"confirmed_by,omitempty"`
	RejectionReason string          `gorm:"type:text" json:"rejection_reason,omitempty"`
	CreatedAt       time.Time       `json:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at"`

	// Relationships
	Roomspace *Roomspace `gorm:"foreignKey:RoomspaceID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"roomspace,omitempty"`
	FromUser  *User      `gorm:"foreignKey:FromUserID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"from_user,omitempty"`
	ToUser    *User      `gorm:"foreignKey:ToUserID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"to_user,omitempty"`
}

// TableName specifies the table name for GORM
func (PaymentConfirmation) TableName() string {
	return "payment_confirmations"
}

// IsPending returns true if payment is pending confirmation
func (pc *PaymentConfirmation) IsPending() bool {
	return pc.Status == PaymentStatusPending
}

// IsConfirmed returns true if payment is confirmed
func (pc *PaymentConfirmation) IsConfirmed() bool {
	return pc.Status == PaymentStatusConfirmed
}

// IsRejected returns true if payment is rejected
func (pc *PaymentConfirmation) IsRejected() bool {
	return pc.Status == PaymentStatusRejected
}

// Validate validates the payment confirmation
func (pc *PaymentConfirmation) Validate() error {
	if pc.FromUserID == pc.ToUserID {
		return ErrSelfPayment
	}
	if pc.Amount <= 0 {
		return ErrInvalidPaymentAmount
	}
	return nil
}

// PaymentConfirmationRequest represents a request to create a payment confirmation
type PaymentConfirmationRequest struct {
	ToUserID        string          `json:"to_user_id" binding:"required"`
	Amount          float64         `json:"amount" binding:"required,gt=0"`
	PaymentType     PaymentTypeEnum `json:"payment_type" binding:"required"`
	Notes           string          `json:"notes"`
	PaymentProofURL string          `json:"payment_proof_url"`
	PaymentDate     time.Time       `json:"payment_date" binding:"required"`
}

// PaymentConfirmationResponse represents the response for payment confirmation
type PaymentConfirmationResponse struct {
	ID              uint            `json:"id"`
	RoomspaceID     string          `json:"roomspace_id"`
	FromUserID      string          `json:"from_user_id"`
	FromUserName    string          `json:"from_user_name"`
	ToUserID        string          `json:"to_user_id"`
	ToUserName      string          `json:"to_user_name"`
	Amount          float64         `json:"amount"`
	PaymentType     PaymentTypeEnum `json:"payment_type"`
	Status          PaymentStatus   `json:"status"`
	Notes           string          `json:"notes,omitempty"`
	PaymentProofURL string          `json:"payment_proof_url,omitempty"`
	PaymentDate     time.Time       `json:"payment_date"`
	ConfirmedAt     *time.Time      `json:"confirmed_at,omitempty"`
	RejectionReason string          `json:"rejection_reason,omitempty"`
	CreatedAt       time.Time       `json:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at"`
}

// PaymentConfirmActionRequest represents a request to confirm or reject a payment
type PaymentConfirmActionRequest struct {
	Reason string `json:"reason"` // Optional reason for rejection
}

// PaymentHistoryFilter represents filters for payment history queries
type PaymentHistoryFilter struct {
	RoomspaceID string
	UserID      string // Filter by from_user or to_user
	Status      PaymentStatus
	Limit       int
	Offset      int
	StartDate   *time.Time
	EndDate     *time.Time
}
