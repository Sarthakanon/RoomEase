package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JoinRequest represents a request to join a roomspace
type JoinRequest struct {
	ID              uuid.UUID         `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	RoomspaceID     uuid.UUID         `gorm:"type:uuid;not null" json:"roomspace_id" validate:"required"`
	RequesterID     string            `gorm:"type:varchar(28);not null" json:"requester_id" validate:"required"`
	Status          JoinRequestStatus `gorm:"type:varchar(20);default:'pending';not null" json:"status" validate:"required,oneof=pending approved rejected expired cancelled"`
	RequestedAt     time.Time         `gorm:"default:now()" json:"requested_at"`
	ProcessedAt     *time.Time        `json:"processed_at,omitempty"`
	ProcessedBy     *string           `gorm:"type:varchar(28)" json:"processed_by,omitempty"`
	RejectionReason *string           `gorm:"type:varchar(200)" json:"rejection_reason,omitempty" validate:"omitempty,max=200"`
	ExpiresAt       time.Time         `gorm:"default:now() + interval '7 days'" json:"expires_at"`
	Message         *string           `gorm:"type:text" json:"message,omitempty" validate:"omitempty,max=500"`
	
	// Relationships
	Roomspace *Roomspace `gorm:"foreignKey:RoomspaceID;constraint:OnDelete:CASCADE" json:"roomspace,omitempty"`
	Requester *User      `gorm:"foreignKey:RequesterID;references:FirebaseUID;constraint:OnDelete:CASCADE" json:"requester,omitempty"`
	Processor *User      `gorm:"foreignKey:ProcessedBy;references:FirebaseUID;constraint:OnDelete:SET NULL" json:"processor,omitempty"`
}

// JoinRequestStatus represents the status of a join request
type JoinRequestStatus string

const (
	StatusPending   JoinRequestStatus = "pending"
	StatusApproved  JoinRequestStatus = "approved"
	StatusRejected  JoinRequestStatus = "rejected"
	StatusExpired   JoinRequestStatus = "expired"
	StatusCancelled JoinRequestStatus = "cancelled"
)

// String returns the string representation of JoinRequestStatus
func (jrs JoinRequestStatus) String() string {
	return string(jrs)
}

// IsValid checks if the join request status is valid
func (jrs JoinRequestStatus) IsValid() bool {
	switch jrs {
	case StatusPending, StatusApproved, StatusRejected, StatusExpired, StatusCancelled:
		return true
	default:
		return false
	}
}

// IsFinal checks if the status is a final state (cannot be changed)
func (jrs JoinRequestStatus) IsFinal() bool {
	switch jrs {
	case StatusApproved, StatusRejected, StatusExpired, StatusCancelled:
		return true
	default:
		return false
	}
}

// Helper Methods for JoinRequest

// IsExpired checks if the join request has expired
func (jr *JoinRequest) IsExpired() bool {
	return time.Now().After(jr.ExpiresAt)
}

// IsPending checks if the join request is still pending
func (jr *JoinRequest) IsPending() bool {
	return jr.Status == StatusPending && !jr.IsExpired()
}

// CanBeProcessed checks if the join request can be approved or rejected
func (jr *JoinRequest) CanBeProcessed() bool {
	return jr.Status == StatusPending && !jr.IsExpired()
}

// GetTimeUntilExpiry returns the duration until the request expires
func (jr *JoinRequest) GetTimeUntilExpiry() time.Duration {
	if jr.IsExpired() {
		return 0
	}
	return time.Until(jr.ExpiresAt)
}

// GetDaysUntilExpiry returns the number of days until expiry
func (jr *JoinRequest) GetDaysUntilExpiry() int {
	duration := jr.GetTimeUntilExpiry()
	if duration <= 0 {
		return 0
	}
	return int(duration.Hours() / 24)
}

// Approve marks the join request as approved
func (jr *JoinRequest) Approve(processorID string) error {
	if !jr.CanBeProcessed() {
		return gorm.ErrInvalidValue
	}
	
	now := time.Now()
	jr.Status = StatusApproved
	jr.ProcessedAt = &now
	jr.ProcessedBy = &processorID
	jr.RejectionReason = nil // Clear any previous rejection reason
	
	return nil
}

// Reject marks the join request as rejected
func (jr *JoinRequest) Reject(processorID, reason string) error {
	if !jr.CanBeProcessed() {
		return gorm.ErrInvalidValue
	}
	
	now := time.Now()
	jr.Status = StatusRejected
	jr.ProcessedAt = &now
	jr.ProcessedBy = &processorID
	if reason != "" {
		jr.RejectionReason = &reason
	}
	
	return nil
}

// Expire marks the join request as expired
func (jr *JoinRequest) Expire() error {
	if jr.Status != StatusPending {
		return gorm.ErrInvalidValue
	}
	
	now := time.Now()
	jr.Status = StatusExpired
	jr.ProcessedAt = &now
	
	return nil
}

// Cancel marks the join request as cancelled
func (jr *JoinRequest) Cancel() error {
	if jr.Status != StatusPending {
		return gorm.ErrInvalidValue
	}
	
	now := time.Now()
	jr.Status = StatusCancelled
	jr.ProcessedAt = &now
	
	return nil
}

// GetDisplayStatus returns a human-readable status
func (jr *JoinRequest) GetDisplayStatus() string {
	switch jr.Status {
	case StatusPending:
		if jr.IsExpired() {
			return "Expired"
		}
		return "Pending"
	case StatusApproved:
		return "Approved"
	case StatusRejected:
		return "Rejected"
	case StatusExpired:
		return "Expired"
	case StatusCancelled:
		return "Cancelled"
	default:
		return "Unknown"
	}
}

// GetStatusColor returns a color code for UI display
func (jr *JoinRequest) GetStatusColor() string {
	switch jr.Status {
	case StatusPending:
		if jr.IsExpired() {
			return "#FF6B6B" // Red for expired
		}
		return "#FFA726" // Orange for pending
	case StatusApproved:
		return "#66BB6A" // Green for approved
	case StatusRejected:
		return "#EF5350" // Red for rejected
	case StatusExpired:
		return "#BDBDBD" // Gray for expired
	case StatusCancelled:
		return "#9E9E9E" // Gray for cancelled
	default:
		return "#757575" // Default gray
	}
}

// CanBeCancelledBy checks if the request can be cancelled by the given user
func (jr *JoinRequest) CanBeCancelledBy(userID string) bool {
	// Only the requester can cancel their own pending request
	return jr.Status == StatusPending && jr.RequesterID == userID
}

// GetProcessingInfo returns information about who processed the request and when
func (jr *JoinRequest) GetProcessingInfo() map[string]interface{} {
	info := map[string]interface{}{
		"is_processed": jr.ProcessedAt != nil,
		"status":       jr.GetDisplayStatus(),
	}
	
	if jr.ProcessedAt != nil {
		info["processed_at"] = jr.ProcessedAt
		info["processed_by"] = jr.ProcessedBy
		
		if jr.RejectionReason != nil {
			info["rejection_reason"] = *jr.RejectionReason
		}
	}
	
	if jr.Status == StatusPending {
		info["expires_at"] = jr.ExpiresAt
		info["days_until_expiry"] = jr.GetDaysUntilExpiry()
		info["is_expired"] = jr.IsExpired()
	}
	
	return info
}

// GORM Hooks

// BeforeCreate hook for JoinRequest
func (jr *JoinRequest) BeforeCreate(tx *gorm.DB) error {
	if jr.ID == uuid.Nil {
		jr.ID = uuid.New()
	}
	
	// Set default status if not set
	if jr.Status == "" {
		jr.Status = StatusPending
	}
	
	// Validate status
	if !jr.Status.IsValid() {
		return gorm.ErrInvalidValue
	}
	
	// Set expiry if not set
	if jr.ExpiresAt.IsZero() {
		jr.ExpiresAt = time.Now().Add(7 * 24 * time.Hour) // 7 days
	}
	
	return nil
}

// BeforeUpdate hook for JoinRequest
func (jr *JoinRequest) BeforeUpdate(tx *gorm.DB) error {
	// Validate status
	if !jr.Status.IsValid() {
		return gorm.ErrInvalidValue
	}
	
	// Ensure processed_at is set when status changes from pending
	if jr.Status != StatusPending && jr.ProcessedAt == nil {
		now := time.Now()
		jr.ProcessedAt = &now
	}
	
	return nil
}

// TableName specifies the table name for JoinRequest
func (JoinRequest) TableName() string {
	return "join_requests"
}

// JoinRequestWithDetails represents a join request with additional details for API responses
type JoinRequestWithDetails struct {
	*JoinRequest
	RequesterName  string `json:"requester_name"`
	RequesterEmail string `json:"requester_email"`
	RoomspaceName  string `json:"roomspace_name"`
	ProcessorName  *string `json:"processor_name,omitempty"`
	IsExpired      bool   `json:"is_expired"`
	DaysUntilExpiry int   `json:"days_until_expiry"`
}