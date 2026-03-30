package models

import (
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Roomspace represents a shared living space
type Roomspace struct {
	ID          uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name        string         `gorm:"type:varchar(100);not null" json:"name" validate:"required,min=1,max=100"`
	Description *string        `gorm:"type:text" json:"description,omitempty" validate:"omitempty,max=500"`
	InviteCode  string         `gorm:"type:varchar(8);uniqueIndex;not null" json:"invite_code" validate:"required,len=8,alphanum"`
	CreatorID   *string        `gorm:"type:varchar(28)" json:"creator_id,omitempty" validate:"omitempty"`
	CreatedAt   time.Time      `gorm:"default:now()" json:"created_at"`
	UpdatedAt   time.Time      `gorm:"default:now()" json:"updated_at"`
	IsArchived  bool           `gorm:"default:false" json:"is_archived"`
	MaxMembers  int            `gorm:"default:10;check:max_members >= 2 AND max_members <= 50" json:"max_members" validate:"min=2,max=50"`
	
	// Relationships
	Members      []RoomspaceMember `gorm:"foreignKey:RoomspaceID;constraint:OnDelete:CASCADE" json:"members,omitempty"`
	JoinRequests []JoinRequest     `gorm:"foreignKey:RoomspaceID;constraint:OnDelete:CASCADE" json:"join_requests,omitempty"`
	Creator      *User             `gorm:"foreignKey:CreatorID;references:FirebaseUID;constraint:OnDelete:RESTRICT" json:"creator,omitempty"`
}

// Request/Response DTOs

// CreateRoomspaceRequest represents the request to create a roomspace
type CreateRoomspaceRequest struct {
	Name        string `json:"name" binding:"required" validate:"required,min=1,max=100"`
	Description string `json:"description,omitempty" validate:"omitempty,max=500"`
	MaxMembers  int    `json:"max_members,omitempty" validate:"omitempty,min=2,max=50"`
}

// UpdateRoomspaceRequest represents the request to update a roomspace
type UpdateRoomspaceRequest struct {
	Name        *string `json:"name,omitempty" validate:"omitempty,min=1,max=100"`
	Description *string `json:"description,omitempty" validate:"omitempty,max=500"`
	MaxMembers  *int    `json:"max_members,omitempty" validate:"omitempty,min=2,max=50"`
}

// JoinRoomspaceRequest represents the request to join a roomspace via invite code
type JoinRoomspaceRequest struct {
	InviteCode string `json:"invite_code" binding:"required" validate:"required,len=8,alphanum"`
	Message    string `json:"message,omitempty" validate:"omitempty,max=500"`
}

// ProcessJoinRequestRequest represents the request to approve/reject a join request
type ProcessJoinRequestRequest struct {
	Action string `json:"action" binding:"required" validate:"required,oneof=approve reject"`
	Reason string `json:"reason,omitempty" validate:"omitempty,max=200"`
}

// RoomspaceResponse represents the response for roomspace operations
type RoomspaceResponse struct {
	*Roomspace
	MemberCount         int         `json:"member_count"`
	PendingRequestCount int         `json:"pending_request_count"`
	IsUserMember        bool        `json:"is_user_member"`
	UserRole            *MemberRole `json:"user_role,omitempty"`
}

// Helper Methods for Roomspace

// IsCreator checks if the given user ID is the creator of the roomspace
func (r *Roomspace) IsCreator(userID string) bool {
	return r.CreatorID != nil && *r.CreatorID == userID
}

// IsActive checks if the roomspace is active (not archived)
func (r *Roomspace) IsActive() bool {
	return !r.IsArchived
}

// CanAcceptNewMembers checks if the roomspace can accept new members
func (r *Roomspace) CanAcceptNewMembers() bool {
	if r.IsArchived {
		return false
	}
	
	activeMemberCount := 0
	for _, member := range r.Members {
		if member.IsActive {
			activeMemberCount++
		}
	}
	
	return activeMemberCount < r.MaxMembers
}

// GetActiveMemberCount returns the count of active members
func (r *Roomspace) GetActiveMemberCount() int {
	count := 0
	for _, member := range r.Members {
		if member.IsActive {
			count++
		}
	}
	return count
}

// GetPendingRequestCount returns the count of pending join requests
func (r *Roomspace) GetPendingRequestCount() int {
	count := 0
	for _, request := range r.JoinRequests {
		if request.Status == StatusPending && !request.IsExpired() {
			count++
		}
	}
	return count
}

// GetMemberByUserID finds a member by user ID
func (r *Roomspace) GetMemberByUserID(userID string) *RoomspaceMember {
	for i := range r.Members {
		if r.Members[i].UserID == userID && r.Members[i].IsActive {
			return &r.Members[i]
		}
	}
	return nil
}

// HasMember checks if a user is a member of the roomspace
func (r *Roomspace) HasMember(userID string) bool {
	return r.GetMemberByUserID(userID) != nil
}

// GetCreators returns all creators of the roomspace
func (r *Roomspace) GetCreators() []RoomspaceMember {
	creators := []RoomspaceMember{}
	for _, member := range r.Members {
		if member.Role == RoleCreator && member.IsActive {
			creators = append(creators, member)
		}
	}
	return creators
}

// ValidateInviteCode validates the format of an invite code
func (r *Roomspace) ValidateInviteCode() error {
	if len(r.InviteCode) != 8 {
		return errors.New("invite code must be exactly 8 characters")
	}
	
	matched, _ := regexp.MatchString("^[A-Z0-9]{8}$", r.InviteCode)
	if !matched {
		return errors.New("invite code must contain only uppercase letters and numbers")
	}
	
	return nil
}

// Validate performs comprehensive validation on the roomspace
func (r *Roomspace) Validate() error {
	if strings.TrimSpace(r.Name) == "" {
		return errors.New("roomspace name is required")
	}
	
	if len(r.Name) > 100 {
		return errors.New("roomspace name cannot exceed 100 characters")
	}
	
	if r.Description != nil && len(*r.Description) > 500 {
		return errors.New("roomspace description cannot exceed 500 characters")
	}
	
	if r.MaxMembers < 2 || r.MaxMembers > 50 {
		return errors.New("max members must be between 2 and 50")
	}
	
	if r.CreatorID == nil || *r.CreatorID == "" {
		return errors.New("creator ID is required")
	}
	
	return r.ValidateInviteCode()
}

// ToResponse converts the roomspace to a response DTO with additional metadata
func (r *Roomspace) ToResponse(userID string) *RoomspaceResponse {
	response := &RoomspaceResponse{
		Roomspace:           r,
		MemberCount:         r.GetActiveMemberCount(),
		PendingRequestCount: r.GetPendingRequestCount(),
		IsUserMember:        r.HasMember(userID),
	}
	
	if member := r.GetMemberByUserID(userID); member != nil {
		response.UserRole = &member.Role
	}
	
	return response
}

// GORM Hooks

// BeforeCreate hook for Roomspace
func (r *Roomspace) BeforeCreate(tx *gorm.DB) error {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	
	// Set default max members if not specified
	if r.MaxMembers == 0 {
		r.MaxMembers = 10
	}
	
	return r.Validate()
}

// BeforeUpdate hook for Roomspace
func (r *Roomspace) BeforeUpdate(tx *gorm.DB) error {
	return r.Validate()
}

// TableName specifies the table name for Roomspace
func (Roomspace) TableName() string {
	return "roomspaces"
}
