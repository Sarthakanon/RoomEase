package models

import (
	"time"

	"gorm.io/gorm"
)

// ExpenseDeletionRequest represents a request to delete an expense
type ExpenseDeletionRequest struct {
	ID          uint           `gorm:"primaryKey" json:"id"`
	ExpenseID   uint           `gorm:"not null;index" json:"expense_id"`
	RoomspaceID string         `gorm:"type:varchar(36);not null;index" json:"roomspace_id"`
	RequestedBy string         `gorm:"not null;size:128" json:"requested_by"` // Firebase UID
	Reason      string         `gorm:"size:500" json:"reason"`
	Status      string         `gorm:"not null;default:'pending'" json:"status"` // pending, approved, rejected, completed
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	// Relationships
	Expense   *Expense                    `gorm:"foreignKey:ExpenseID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"expense,omitempty"`
	Requester *User                       `gorm:"foreignKey:RequestedBy;references:FirebaseUID" json:"requester,omitempty"`
	Approvals []ExpenseDeletionApproval   `gorm:"foreignKey:DeletionRequestID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"approvals,omitempty"`
}

// ExpenseDeletionApproval represents an approval/rejection from a roommate
type ExpenseDeletionApproval struct {
	ID                uint      `gorm:"primaryKey" json:"id"`
	DeletionRequestID uint      `gorm:"not null;index" json:"deletion_request_id"`
	UserUID           string    `gorm:"not null;size:128" json:"user_uid"` // Firebase UID
	Approved          bool      `gorm:"not null" json:"approved"`
	Comment           string    `gorm:"size:500" json:"comment"`
	RespondedAt       time.Time `json:"responded_at"`

	// Relationships
	DeletionRequest *ExpenseDeletionRequest `gorm:"foreignKey:DeletionRequestID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"deletion_request,omitempty"`
	User            *User                   `gorm:"foreignKey:UserUID;references:FirebaseUID" json:"user,omitempty"`
}

// CreateDeletionRequestRequest represents the request to create a deletion request
type CreateDeletionRequestRequest struct {
	Reason string `json:"reason"`
}

// RespondToDeletionRequest represents the response to a deletion request
type RespondToDeletionRequest struct {
	Approved bool   `json:"approved" binding:"required"`
	Comment  string `json:"comment"`
}

// DeletionRequestResponse represents the response for deletion request data
type DeletionRequestResponse struct {
	ID          uint                          `json:"id"`
	ExpenseID   uint                          `json:"expense_id"`
	ExpenseData *ExpenseResponse              `json:"expense_data,omitempty"`
	RequestedBy string                        `json:"requested_by"`
	RequesterName string                      `json:"requester_name"`
	Reason      string                        `json:"reason"`
	Status      string                        `json:"status"`
	CreatedAt   time.Time                     `json:"created_at"`
	Approvals   []DeletionApprovalResponse    `json:"approvals"`
	AffectedUsers []string                    `json:"affected_users"`
}

// DeletionApprovalResponse represents the response for deletion approval data
type DeletionApprovalResponse struct {
	UserUID     string    `json:"user_uid"`
	UserName    string    `json:"user_name"`
	Approved    bool      `json:"approved"`
	Comment     string    `json:"comment"`
	RespondedAt time.Time `json:"responded_at"`
}
