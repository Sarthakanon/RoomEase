package models

import (
	"time"

	"gorm.io/gorm"
)

// NotificationType represents the type of notification
type NotificationType string

const (
	NotificationTypeJoinRequest    NotificationType = "JOIN_REQUEST"
	NotificationTypeJoinAccepted   NotificationType = "JOIN_ACCEPTED"
	NotificationTypeJoinRejected   NotificationType = "JOIN_REJECTED"
	NotificationTypeExpenseAdded   NotificationType = "EXPENSE_ADDED"
	NotificationTypeMemberRemoved  NotificationType = "MEMBER_REMOVED"
	NotificationTypeYouRemovedUser NotificationType = "YOU_REMOVED_USER"
)

// Notification represents a notification for a user
type Notification struct {
	ID           uint             `gorm:"primaryKey" json:"id"`
	RecipientUID string           `gorm:"not null;index" json:"recipient_uid"` // Firebase UID of recipient
	Type         NotificationType `gorm:"not null" json:"type"`
	Title        string           `gorm:"not null" json:"title"`
	Message      string           `json:"message"`
	Data         string           `json:"data,omitempty"` // JSON string for extra data
	IsRead       bool             `gorm:"default:false" json:"is_read"`
	CreatedAt    time.Time        `json:"created_at"`
	UpdatedAt    time.Time        `json:"updated_at"`
	DeletedAt    gorm.DeletedAt   `gorm:"index" json:"-"`
}

// JoinRequestStatus represents the status of a join request
type JoinRequestStatus string

const (
	JoinRequestStatusPending  JoinRequestStatus = "PENDING"
	JoinRequestStatusAccepted JoinRequestStatus = "ACCEPTED"
	JoinRequestStatusRejected JoinRequestStatus = "REJECTED"
)

// JoinRequest represents a request to join a roomspace
type JoinRequest struct {
	ID          uint              `gorm:"primaryKey" json:"id"`
	RoomspaceID uint              `gorm:"not null;index" json:"roomspace_id"`
	Roomspace   *Roomspace        `gorm:"foreignKey:RoomspaceID;constraint:-" json:"roomspace,omitempty"`
	RequesterUID string           `gorm:"not null;index" json:"requester_uid"` // Firebase UID
	Requester   *User             `gorm:"foreignKey:RequesterUID;references:FirebaseUID;constraint:-" json:"requester,omitempty"`
	Status      JoinRequestStatus `gorm:"not null;default:PENDING" json:"status"`
	ProcessedBy string            `json:"processed_by,omitempty"` // Firebase UID of who accepted/rejected
	CreatedAt   time.Time         `json:"created_at"`
	UpdatedAt   time.Time         `json:"updated_at"`
	DeletedAt   gorm.DeletedAt    `gorm:"index" json:"-"`
}
