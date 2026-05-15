package models

import (
	"time"

	"gorm.io/gorm"
)

// User represents a user in the system
type User struct {
	ID                 uint           `gorm:"primaryKey" json:"id"`
	FirebaseUID        string         `gorm:"uniqueIndex;not null" json:"firebase_uid"`
	Email              string         `gorm:"not null" json:"email"`
	Name               string         `json:"name"`
	Phone              string         `json:"phone,omitempty"`
	QRImageURL         string         `gorm:"column:qr_image_url" json:"qr_image_url,omitempty"`
	IsBanned           bool           `gorm:"default:false" json:"is_banned"`
	BanReason          *string        `json:"ban_reason,omitempty"`
	BannedAt           *time.Time     `json:"banned_at,omitempty"`
	SubscriptionPlan   string         `gorm:"default:'free'" json:"subscription_plan"` // free, pro
	SubscriptionExpiry *time.Time     `json:"subscription_expiry,omitempty"`           // null for free plan
	CreatedAt          time.Time      `json:"created_at"`
	UpdatedAt          time.Time      `json:"updated_at"`
	DeletedAt          gorm.DeletedAt `gorm:"index" json:"-"`
}

// CreateUserRequest represents the request to create a user
type CreateUserRequest struct {
	FirebaseUID string `json:"firebase_uid" binding:"required"`
	Email       string `json:"email" binding:"required,email"`
	Name        string `json:"name" binding:"required"`
	Phone       string `json:"phone,omitempty"`
}

// UpdateUserRequest represents the request to update a user
type UpdateUserRequest struct {
	Name       string `json:"name,omitempty"`
	Phone      string `json:"phone,omitempty"`
	QRImageURL string `json:"qr_image_url,omitempty"`
}
