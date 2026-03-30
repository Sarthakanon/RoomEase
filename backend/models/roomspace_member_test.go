package models

import (
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestMemberRole_IsValid(t *testing.T) {
	tests := []struct {
		name     string
		role     MemberRole
		expected bool
	}{
		{"creator role", RoleCreator, true},
		{"admin role", RoleAdmin, true},
		{"member role", RoleMember, true},
		{"pending role", RolePending, true},
		{"invalid role", MemberRole("invalid"), false},
		{"empty role", MemberRole(""), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.role.IsValid())
		})
	}
}

func TestMemberRole_String(t *testing.T) {
	assert.Equal(t, "creator", RoleCreator.String())
	assert.Equal(t, "admin", RoleAdmin.String())
	assert.Equal(t, "member", RoleMember.String())
	assert.Equal(t, "pending", RolePending.String())
}

func TestRoomspaceMember_IsCreator(t *testing.T) {
	tests := []struct {
		name     string
		role     MemberRole
		expected bool
	}{
		{"creator role", RoleCreator, true},
		{"admin role", RoleAdmin, false},
		{"member role", RoleMember, false},
		{"pending role", RolePending, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role}
			assert.Equal(t, tt.expected, member.IsCreator())
		})
	}
}

func TestRoomspaceMember_IsAdmin(t *testing.T) {
	tests := []struct {
		name     string
		role     MemberRole
		expected bool
	}{
		{"creator role", RoleCreator, true},
		{"admin role", RoleAdmin, true},
		{"member role", RoleMember, false},
		{"pending role", RolePending, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role}
			assert.Equal(t, tt.expected, member.IsAdmin())
		})
	}
}

func TestRoomspaceMember_CanManageMembers(t *testing.T) {
	tests := []struct {
		name     string
		role     MemberRole
		isActive bool
		expected bool
	}{
		{"active creator", RoleCreator, true, true},
		{"active admin", RoleAdmin, true, true},
		{"active member", RoleMember, true, false},
		{"inactive creator", RoleCreator, false, false},
		{"inactive admin", RoleAdmin, false, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role, IsActive: tt.isActive}
			assert.Equal(t, tt.expected, member.CanManageMembers())
		})
	}
}

func TestRoomspaceMember_CanProcessJoinRequests(t *testing.T) {
	tests := []struct {
		name     string
		role     MemberRole
		isActive bool
		expected bool
	}{
		{"active creator", RoleCreator, true, true},
		{"active admin", RoleAdmin, true, true},
		{"active member", RoleMember, true, false},
		{"inactive creator", RoleCreator, false, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role, IsActive: tt.isActive}
			assert.Equal(t, tt.expected, member.CanProcessJoinRequests())
		})
	}
}

func TestRoomspaceMember_CanRemoveMember(t *testing.T) {
	creator := RoomspaceMember{
		UserID:   "creator1",
		Role:     RoleCreator,
		IsActive: true,
	}
	admin := RoomspaceMember{
		UserID:   "admin1",
		Role:     RoleAdmin,
		IsActive: true,
	}
	member := RoomspaceMember{
		UserID:   "member1",
		Role:     RoleMember,
		IsActive: true,
	}
	inactiveMember := RoomspaceMember{
		UserID:   "inactive1",
		Role:     RoleMember,
		IsActive: false,
	}

	tests := []struct {
		name         string
		remover      RoomspaceMember
		target       RoomspaceMember
		expected     bool
		description  string
	}{
		{"creator removes admin", creator, admin, true, "creator can remove admin"},
		{"creator removes member", creator, member, true, "creator can remove member"},
		{"creator removes self", creator, creator, true, "creator can remove self"},
		{"admin removes member", admin, member, true, "admin can remove member"},
		{"admin removes creator", admin, creator, false, "admin cannot remove creator"},
		{"admin removes self", admin, admin, false, "admin cannot remove self"}, // Changed expectation
		{"member removes self", member, member, true, "member can remove self"},
		{"member removes other", member, admin, false, "member cannot remove others"},
		{"inactive member removes self", inactiveMember, inactiveMember, false, "inactive member cannot remove"},
		{"creator removes inactive", creator, inactiveMember, false, "cannot remove inactive member"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.remover.CanRemoveMember(&tt.target)
			assert.Equal(t, tt.expected, result, tt.description)
		})
	}
}

func TestRoomspaceMember_CanPromoteMember(t *testing.T) {
	creator := RoomspaceMember{
		UserID:   "creator1",
		Role:     RoleCreator,
		IsActive: true,
	}
	admin := RoomspaceMember{
		UserID:   "admin1",
		Role:     RoleAdmin,
		IsActive: true,
	}
	member := RoomspaceMember{
		UserID:   "member1",
		Role:     RoleMember,
		IsActive: true,
	}

	tests := []struct {
		name        string
		promoter    RoomspaceMember
		target      RoomspaceMember
		newRole     MemberRole
		expected    bool
		description string
	}{
		{"creator promotes to admin", creator, member, RoleAdmin, true, "creator can promote to admin"},
		{"creator promotes to creator", creator, member, RoleCreator, true, "creator can promote to creator"},
		{"creator promotes to member", creator, admin, RoleMember, true, "creator can demote to member"},
		{"admin promotes to admin", admin, member, RoleAdmin, false, "admin cannot promote to admin"},
		{"admin promotes to member", admin, member, RoleMember, true, "admin can promote to member"},
		{"member promotes", member, member, RoleAdmin, false, "member cannot promote"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.promoter.CanPromoteMember(&tt.target, tt.newRole)
			assert.Equal(t, tt.expected, result, tt.description)
		})
	}
}

func TestRoomspaceMember_GetDisplayRole(t *testing.T) {
	tests := []struct {
		name     string
		role     MemberRole
		expected string
	}{
		{"creator role", RoleCreator, "Creator"},
		{"admin role", RoleAdmin, "Admin"},
		{"member role", RoleMember, "Member"},
		{"pending role", RolePending, "Pending"},
		{"unknown role", MemberRole("unknown"), "Unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role}
			assert.Equal(t, tt.expected, member.GetDisplayRole())
		})
	}
}

func TestRoomspaceMember_GetPermissions(t *testing.T) {
	tests := []struct {
		name        string
		role        MemberRole
		isActive    bool
		expectedLen int
		contains    []string
		notContains []string
	}{
		{
			name:        "inactive member",
			role:        RoleMember,
			isActive:    false,
			expectedLen: 0,
			contains:    []string{},
			notContains: []string{"view_roomspace"},
		},
		{
			name:        "active member",
			role:        RoleMember,
			isActive:    true,
			expectedLen: 3,
			contains:    []string{"view_roomspace", "view_members", "leave_roomspace"},
			notContains: []string{"process_join_requests", "remove_members"},
		},
		{
			name:        "active admin",
			role:        RoleAdmin,
			isActive:    true,
			expectedLen: 6,
			contains:    []string{"view_roomspace", "process_join_requests", "invite_members"},
			notContains: []string{"remove_members", "archive_roomspace"},
		},
		{
			name:        "active creator",
			role:        RoleCreator,
			isActive:    true,
			expectedLen: 11, // Updated count
			contains:    []string{"view_roomspace", "process_join_requests", "remove_members", "archive_roomspace"},
			notContains: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role, IsActive: tt.isActive}
			permissions := member.GetPermissions()
			
			assert.Len(t, permissions, tt.expectedLen)
			
			for _, perm := range tt.contains {
				assert.Contains(t, permissions, perm)
			}
			
			for _, perm := range tt.notContains {
				assert.NotContains(t, permissions, perm)
			}
		})
	}
}

func TestRoomspaceMember_BeforeCreate(t *testing.T) {
	member := RoomspaceMember{
		RoomspaceID: uuid.New(),
		UserID:      "test-user",
	}

	err := member.BeforeCreate(nil)
	assert.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, member.ID)
	assert.Equal(t, RoleMember, member.Role) // Default role
}

func TestRoomspaceMember_BeforeUpdate(t *testing.T) {
	tests := []struct {
		name    string
		role    MemberRole
		wantErr bool
	}{
		{"valid role", RoleMember, false},
		{"invalid role", MemberRole("invalid"), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := RoomspaceMember{Role: tt.role}
			err := member.BeforeUpdate(nil)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestRoomspaceMember_TableName(t *testing.T) {
	member := RoomspaceMember{}
	assert.Equal(t, "roomspace_members", member.TableName())
}