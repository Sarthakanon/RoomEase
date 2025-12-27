package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RoomspaceMember represents the many-to-many relationship between users and roomspaces
type RoomspaceMember struct {
	ID          uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	RoomspaceID uuid.UUID  `gorm:"type:uuid;not null" json:"roomspace_id" validate:"required"`
	UserID      string     `gorm:"type:varchar(28);not null" json:"user_id" validate:"required"`
	Role        MemberRole `gorm:"type:varchar(20);default:'member';not null" json:"role" validate:"required,oneof=creator admin member pending"`
	JoinedAt    time.Time  `gorm:"default:now()" json:"joined_at"`
	InvitedBy   *string    `gorm:"type:varchar(28)" json:"invited_by,omitempty"`
	IsActive    bool       `gorm:"default:true" json:"is_active"`
	
	// Relationships
	Roomspace *Roomspace `gorm:"foreignKey:RoomspaceID;constraint:OnDelete:CASCADE" json:"roomspace,omitempty"`
	User      *User      `gorm:"foreignKey:UserID;references:FirebaseUID;constraint:OnDelete:CASCADE" json:"user,omitempty"`
	Inviter   *User      `gorm:"foreignKey:InvitedBy;references:FirebaseUID;constraint:OnDelete:SET NULL" json:"inviter,omitempty"`
}

// MemberRole represents the role of a member in a roomspace
type MemberRole string

const (
	RoleCreator MemberRole = "creator"
	RoleAdmin   MemberRole = "admin"
	RoleMember  MemberRole = "member"
	RolePending MemberRole = "pending"
)

// String returns the string representation of MemberRole
func (mr MemberRole) String() string {
	return string(mr)
}

// IsValid checks if the member role is valid
func (mr MemberRole) IsValid() bool {
	switch mr {
	case RoleCreator, RoleAdmin, RoleMember, RolePending:
		return true
	default:
		return false
	}
}

// Helper Methods for RoomspaceMember

// IsCreator checks if the member is a creator
func (rm *RoomspaceMember) IsCreator() bool {
	return rm.Role == RoleCreator
}

// IsAdmin checks if the member is an admin or creator
func (rm *RoomspaceMember) IsAdmin() bool {
	return rm.Role == RoleAdmin || rm.Role == RoleCreator
}

// CanManageMembers checks if the member can manage other members
func (rm *RoomspaceMember) CanManageMembers() bool {
	return rm.IsActive && (rm.Role == RoleCreator || rm.Role == RoleAdmin)
}

// CanProcessJoinRequests checks if the member can process join requests
func (rm *RoomspaceMember) CanProcessJoinRequests() bool {
	return rm.IsActive && (rm.Role == RoleCreator || rm.Role == RoleAdmin)
}

// CanRemoveMember checks if this member can remove another member
func (rm *RoomspaceMember) CanRemoveMember(targetMember *RoomspaceMember) bool {
	if !rm.IsActive || !targetMember.IsActive {
		return false
	}
	
	// Creators can remove anyone except other creators
	if rm.IsCreator() {
		return !targetMember.IsCreator() || rm.UserID == targetMember.UserID
	}
	
	// Admins can remove regular members
	if rm.IsAdmin() {
		return targetMember.Role == RoleMember
	}
	
	// Regular members can only remove themselves
	return rm.UserID == targetMember.UserID
}

// CanPromoteMember checks if this member can promote another member
func (rm *RoomspaceMember) CanPromoteMember(targetMember *RoomspaceMember, newRole MemberRole) bool {
	if !rm.IsActive || !targetMember.IsActive {
		return false
	}
	
	// Only creators can promote to admin or creator
	if newRole == RoleAdmin || newRole == RoleCreator {
		return rm.IsCreator()
	}
	
	// Admins and creators can promote to member
	if newRole == RoleMember {
		return rm.IsAdmin()
	}
	
	return false
}

// GetDisplayRole returns a human-readable role name
func (rm *RoomspaceMember) GetDisplayRole() string {
	switch rm.Role {
	case RoleCreator:
		return "Creator"
	case RoleAdmin:
		return "Admin"
	case RoleMember:
		return "Member"
	case RolePending:
		return "Pending"
	default:
		return "Unknown"
	}
}

// GetPermissions returns a list of permissions for this member
func (rm *RoomspaceMember) GetPermissions() []string {
	permissions := []string{}
	
	if !rm.IsActive {
		return permissions
	}
	
	// Base permissions for all active members
	permissions = append(permissions, "view_roomspace", "view_members", "leave_roomspace")
	
	// Admin and creator permissions
	if rm.IsAdmin() {
		permissions = append(permissions, 
			"process_join_requests", 
			"view_join_requests",
			"invite_members",
		)
	}
	
	// Creator-only permissions
	if rm.IsCreator() {
		permissions = append(permissions, 
			"remove_members", 
			"promote_members", 
			"update_roomspace", 
			"archive_roomspace",
			"manage_settings",
		)
	}
	
	return permissions
}

// GORM Hooks

// BeforeCreate hook for RoomspaceMember
func (rm *RoomspaceMember) BeforeCreate(tx *gorm.DB) error {
	if rm.ID == uuid.Nil {
		rm.ID = uuid.New()
	}
	
	// Validate role
	if !rm.Role.IsValid() {
		rm.Role = RoleMember
	}
	
	return nil
}

// BeforeUpdate hook for RoomspaceMember
func (rm *RoomspaceMember) BeforeUpdate(tx *gorm.DB) error {
	// Validate role
	if !rm.Role.IsValid() {
		return gorm.ErrInvalidValue
	}
	
	return nil
}

// TableName specifies the table name for RoomspaceMember
func (RoomspaceMember) TableName() string {
	return "roomspace_members"
}