package models

import (
	"time"

	"gorm.io/gorm"
)

// Roomspace represents a shared living space
type Roomspace struct {
	ID          uint           `gorm:"primaryKey" json:"id"`
	Name        string         `gorm:"not null" json:"name"`
	Description string         `json:"description,omitempty"`
	InviteCode  string         `gorm:"uniqueIndex;size:8" json:"invite_code"` // Unique 8-char code for joining
	CreatedBy   string         `gorm:"not null" json:"created_by"` // Firebase UID
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
	Members     []RoomspaceMember `gorm:"foreignKey:RoomspaceID;constraint:-" json:"members,omitempty"`
}

// RoomspaceMember represents the many-to-many relationship between users and roomspaces
type RoomspaceMember struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	RoomspaceID uint      `gorm:"not null" json:"roomspace_id"`
	FirebaseUID string    `gorm:"not null" json:"firebase_uid"`
	JoinedAt    time.Time `json:"joined_at"`
	User        *User     `gorm:"foreignKey:FirebaseUID;references:FirebaseUID;constraint:-" json:"user,omitempty"`
}

// CreateRoomspaceRequest represents the request to create a roomspace
type CreateRoomspaceRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description,omitempty"`
}

// JoinRoomspaceRequest represents the request to join a roomspace
type JoinRoomspaceRequest struct {
	RoomspaceID string `json:"roomspace_id" binding:"required"`
}
