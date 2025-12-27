package models

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestRoomspace_Validate(t *testing.T) {
	tests := []struct {
		name      string
		roomspace Roomspace
		wantErr   bool
		errMsg    string
	}{
		{
			name: "valid roomspace",
			roomspace: Roomspace{
				Name:        "Test Roomspace",
				Description: stringPtr("Test Description"),
				InviteCode:  "ABC12345",
				CreatorID:   "test-creator-id",
				MaxMembers:  10,
			},
			wantErr: false,
		},
		{
			name: "empty name",
			roomspace: Roomspace{
				Name:       "",
				InviteCode: "ABC12345",
				CreatorID:  "test-creator-id",
				MaxMembers: 10,
			},
			wantErr: true,
			errMsg:  "roomspace name is required",
		},
		{
			name: "name too long",
			roomspace: Roomspace{
				Name:       "This is a very long roomspace name that exceeds the maximum allowed length of 100 characters for testing purposes",
				InviteCode: "ABC12345",
				CreatorID:  "test-creator-id",
				MaxMembers: 10,
			},
			wantErr: true,
			errMsg:  "roomspace name cannot exceed 100 characters",
		},
		{
			name: "description too long",
			roomspace: Roomspace{
				Name:        "Test Roomspace",
				Description: stringPtr("This is a very long description that exceeds the maximum allowed length of 500 characters. " + 
					"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. " +
					"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. " +
					"Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. " +
					"Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. " +
					"Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium."),
				InviteCode: "ABC12345",
				CreatorID:  "test-creator-id",
				MaxMembers: 10,
			},
			wantErr: true,
			errMsg:  "roomspace description cannot exceed 500 characters",
		},
		{
			name: "max members too low",
			roomspace: Roomspace{
				Name:       "Test Roomspace",
				InviteCode: "ABC12345",
				CreatorID:  "test-creator-id",
				MaxMembers: 1,
			},
			wantErr: true,
			errMsg:  "max members must be between 2 and 50",
		},
		{
			name: "max members too high",
			roomspace: Roomspace{
				Name:       "Test Roomspace",
				InviteCode: "ABC12345",
				CreatorID:  "test-creator-id",
				MaxMembers: 51,
			},
			wantErr: true,
			errMsg:  "max members must be between 2 and 50",
		},
		{
			name: "empty creator ID",
			roomspace: Roomspace{
				Name:       "Test Roomspace",
				InviteCode: "ABC12345",
				CreatorID:  "",
				MaxMembers: 10,
			},
			wantErr: true,
			errMsg:  "creator ID is required",
		},
		{
			name: "invalid invite code length",
			roomspace: Roomspace{
				Name:       "Test Roomspace",
				InviteCode: "ABC123",
				CreatorID:  "test-creator-id",
				MaxMembers: 10,
			},
			wantErr: true,
			errMsg:  "invite code must be exactly 8 characters",
		},
		{
			name: "invalid invite code format",
			roomspace: Roomspace{
				Name:       "Test Roomspace",
				InviteCode: "abc12345",
				CreatorID:  "test-creator-id",
				MaxMembers: 10,
			},
			wantErr: true,
			errMsg:  "invite code must contain only uppercase letters and numbers",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.roomspace.Validate()
			if tt.wantErr {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestRoomspace_IsCreator(t *testing.T) {
	roomspace := Roomspace{
		CreatorID: "test-creator-id",
	}

	assert.True(t, roomspace.IsCreator("test-creator-id"))
	assert.False(t, roomspace.IsCreator("other-user-id"))
}

func TestRoomspace_IsActive(t *testing.T) {
	tests := []struct {
		name       string
		isArchived bool
		expected   bool
	}{
		{"active roomspace", false, true},
		{"archived roomspace", true, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			roomspace := Roomspace{IsArchived: tt.isArchived}
			assert.Equal(t, tt.expected, roomspace.IsActive())
		})
	}
}

func TestRoomspace_CanAcceptNewMembers(t *testing.T) {
	tests := []struct {
		name         string
		isArchived   bool
		maxMembers   int
		memberCount  int
		expected     bool
	}{
		{"can accept - under limit", false, 10, 5, true},
		{"can accept - at limit minus one", false, 10, 9, true},
		{"cannot accept - at limit", false, 10, 10, false},
		{"cannot accept - over limit", false, 10, 11, false},
		{"cannot accept - archived", true, 10, 5, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			roomspace := Roomspace{
				IsArchived: tt.isArchived,
				MaxMembers: tt.maxMembers,
				Members:    make([]RoomspaceMember, tt.memberCount),
			}

			// Set all members as active
			for i := range roomspace.Members {
				roomspace.Members[i].IsActive = true
			}

			assert.Equal(t, tt.expected, roomspace.CanAcceptNewMembers())
		})
	}
}

func TestRoomspace_GetActiveMemberCount(t *testing.T) {
	roomspace := Roomspace{
		Members: []RoomspaceMember{
			{IsActive: true},
			{IsActive: true},
			{IsActive: false},
			{IsActive: true},
		},
	}

	assert.Equal(t, 3, roomspace.GetActiveMemberCount())
}

func TestRoomspace_GetPendingRequestCount(t *testing.T) {
	now := time.Now()
	roomspace := Roomspace{
		JoinRequests: []JoinRequest{
			{Status: StatusPending, ExpiresAt: now.Add(time.Hour)},
			{Status: StatusPending, ExpiresAt: now.Add(time.Hour)},
			{Status: StatusApproved, ExpiresAt: now.Add(time.Hour)},
			{Status: StatusPending, ExpiresAt: now.Add(-time.Hour)}, // Expired
		},
	}

	assert.Equal(t, 2, roomspace.GetPendingRequestCount())
}

func TestRoomspace_GetMemberByUserID(t *testing.T) {
	roomspace := Roomspace{
		Members: []RoomspaceMember{
			{UserID: "user1", IsActive: true},
			{UserID: "user2", IsActive: false},
			{UserID: "user3", IsActive: true},
		},
	}

	// Should find active member
	member := roomspace.GetMemberByUserID("user1")
	assert.NotNil(t, member)
	assert.Equal(t, "user1", member.UserID)

	// Should not find inactive member
	member = roomspace.GetMemberByUserID("user2")
	assert.Nil(t, member)

	// Should not find non-existent member
	member = roomspace.GetMemberByUserID("user4")
	assert.Nil(t, member)
}

func TestRoomspace_HasMember(t *testing.T) {
	roomspace := Roomspace{
		Members: []RoomspaceMember{
			{UserID: "user1", IsActive: true},
			{UserID: "user2", IsActive: false},
		},
	}

	assert.True(t, roomspace.HasMember("user1"))
	assert.False(t, roomspace.HasMember("user2")) // Inactive
	assert.False(t, roomspace.HasMember("user3")) // Non-existent
}

func TestRoomspace_GetCreators(t *testing.T) {
	roomspace := Roomspace{
		Members: []RoomspaceMember{
			{UserID: "creator1", Role: RoleCreator, IsActive: true},
			{UserID: "creator2", Role: RoleCreator, IsActive: false},
			{UserID: "admin1", Role: RoleAdmin, IsActive: true},
			{UserID: "member1", Role: RoleMember, IsActive: true},
		},
	}

	creators := roomspace.GetCreators()
	assert.Len(t, creators, 1)
	assert.Equal(t, "creator1", creators[0].UserID)
}

func TestRoomspace_ToResponse(t *testing.T) {
	roomspace := Roomspace{
		ID:         uuid.New(),
		Name:       "Test Roomspace",
		CreatorID:  "creator1",
		MaxMembers: 10,
		Members: []RoomspaceMember{
			{UserID: "creator1", Role: RoleCreator, IsActive: true},
			{UserID: "member1", Role: RoleMember, IsActive: true},
			{UserID: "member2", Role: RoleMember, IsActive: false},
		},
		JoinRequests: []JoinRequest{
			{Status: StatusPending, ExpiresAt: time.Now().Add(time.Hour)},
		},
	}

	// Test for creator
	response := roomspace.ToResponse("creator1")
	assert.Equal(t, &roomspace, response.Roomspace)
	assert.Equal(t, 2, response.MemberCount)
	assert.Equal(t, 1, response.PendingRequestCount)
	assert.True(t, response.IsUserMember)
	assert.NotNil(t, response.UserRole)
	assert.Equal(t, RoleCreator, *response.UserRole)

	// Test for non-member
	response = roomspace.ToResponse("non-member")
	assert.Equal(t, 2, response.MemberCount)
	assert.False(t, response.IsUserMember)
	assert.Nil(t, response.UserRole)
}

func TestRoomspace_BeforeCreate(t *testing.T) {
	roomspace := Roomspace{
		Name:       "Test Roomspace",
		InviteCode: "ABC12345",
		CreatorID:  "test-creator-id",
	}

	err := roomspace.BeforeCreate(nil)
	assert.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, roomspace.ID)
	assert.Equal(t, 10, roomspace.MaxMembers) // Default value
}

func TestRoomspace_ValidateInviteCode(t *testing.T) {
	tests := []struct {
		name       string
		inviteCode string
		wantErr    bool
		errMsg     string
	}{
		{"valid code", "ABC12345", false, ""},
		{"too short", "ABC123", true, "invite code must be exactly 8 characters"},
		{"too long", "ABC123456", true, "invite code must be exactly 8 characters"},
		{"lowercase letters", "abc12345", true, "invite code must contain only uppercase letters and numbers"},
		{"special characters", "ABC123!@", true, "invite code must contain only uppercase letters and numbers"},
		{"spaces", "ABC 1234", true, "invite code must contain only uppercase letters and numbers"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			roomspace := Roomspace{InviteCode: tt.inviteCode}
			err := roomspace.ValidateInviteCode()
			if tt.wantErr {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// Helper function to create string pointer
func stringPtr(s string) *string {
	return &s
}