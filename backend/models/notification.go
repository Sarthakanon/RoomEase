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
	NotificationTypePaymentReminder NotificationType = "PAYMENT_REMINDER"
	NotificationTypePaymentClaim   NotificationType = "PAYMENT_CLAIM"
	NotificationTypePaymentConfirmed NotificationType = "PAYMENT_CONFIRMED"
	NotificationTypePaymentRejected NotificationType = "PAYMENT_REJECTED"
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


