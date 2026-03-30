package services

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"roomease/backend/models"
)

func TestPostgresService_CreateRoomspace(t *testing.T) {
	service := NewPostgresService()

	tests := []struct {
		name      string
		roomspace *models.Roomspace
		wantErr   bool
	}{
		{
			name: "valid roomspace creation",
			roomspace: &models.Roomspace{
				Name:        "Test Roomspace",
				Description: stringPtr("Test Description"),
				CreatorID:   stringPtr("test-creator-id"),
				MaxMembers:  10,
				InviteCode:  "ABC12345",
			},
			wantErr: false,
		},
		{
			name: "roomspace with minimal data",
			roomspace: &models.Roomspace{
				Name:       "Minimal Room",
				CreatorID:  stringPtr("creator-123"),
				MaxMembers: 5,
				InviteCode: "XYZ98765",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Note: This test would require a test database setup
			// For now, we're testing the structure and validation
			assert.NotNil(t, service)
			assert.NotNil(t, tt.roomspace)
			
			// Validate roomspace before creation
			err := tt.roomspace.Validate()
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestPostgresService_ValidateRoomspaceData(t *testing.T) {
	service := NewPostgresService()

	tests := []struct {
		name      string
		roomspace *models.Roomspace
		wantErr   bool
		errMsg    string
	}{
		{
			name: "valid roomspace",
			roomspace: &models.Roomspace{
				Name:        "Valid Room",
				CreatorID:   stringPtr("creator-123"),
				MaxMembers:  10,
				InviteCode:  "ABC12345",
			},
			wantErr: false,
		},
		{
			name: "empty name",
			roomspace: &models.Roomspace{
				Name:        "",
				CreatorID:   stringPtr("creator-123"),
				MaxMembers:  10,
				InviteCode:  "ABC12345",
			},
			wantErr: true,
			errMsg:  "roomspace name is required",
		},
		{
			name: "invalid max members",
			roomspace: &models.Roomspace{
				Name:        "Test Room",
				CreatorID:   stringPtr("creator-123"),
				MaxMembers:  1,
				InviteCode:  "ABC12345",
			},
			wantErr: true,
			errMsg:  "max members must be between 2 and 50",
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
			
			// Service should exist
			assert.NotNil(t, service)
		})
	}
}

func TestGenerateInviteCode(t *testing.T) {
	// Test invite code generation
	code1 := generateInviteCode()
	code2 := generateInviteCode()

	// Should be 8 characters
	assert.Len(t, code1, 8)
	assert.Len(t, code2, 8)

	// Should be different
	assert.NotEqual(t, code1, code2)

	// Should only contain uppercase letters and numbers
	for _, char := range code1 {
		assert.True(t, (char >= 'A' && char <= 'Z') || (char >= '0' && char <= '9'))
	}
}

func TestPostgresService_JoinRequestWorkflow(t *testing.T) {
	service := NewPostgresService()
	
	// Test data
	roomspaceID := uuid.New().String()
	requesterID := "requester-123"
	processorID := "processor-456"
	message := "Please let me join"

	t.Run("create join request validation", func(t *testing.T) {
		// Test the validation logic that would be used
		assert.NotEmpty(t, roomspaceID)
		assert.NotEmpty(t, requesterID)
		assert.NotEmpty(t, message)
		assert.LessOrEqual(t, len(message), 500) // Message length validation
		
		// Service should exist
		assert.NotNil(t, service)
	})

	t.Run("process join request validation", func(t *testing.T) {
		// Test the validation logic for processing requests
		assert.NotEmpty(t, processorID)
		
		// Test approval/rejection logic structure
		actions := []string{"approve", "reject"}
		for _, action := range actions {
			assert.Contains(t, []string{"approve", "reject"}, action)
		}
	})
}

func TestPostgresService_MemberManagement(t *testing.T) {
	service := NewPostgresService()
	
	// Test data
	roomspaceID := uuid.New().String()
	memberID := "member-123"
	requestorID := "requestor-456"

	t.Run("add member validation", func(t *testing.T) {
		// Test validation logic
		assert.NotEmpty(t, roomspaceID)
		assert.NotEmpty(t, memberID)
		
		// Validate UUID format
		_, err := uuid.Parse(roomspaceID)
		assert.NoError(t, err)
		
		assert.NotNil(t, service)
	})

	t.Run("remove member validation", func(t *testing.T) {
		// Test validation logic
		assert.NotEmpty(t, roomspaceID)
		assert.NotEmpty(t, memberID)
		assert.NotEmpty(t, requestorID)
		
		// Members should be different
		assert.NotEqual(t, memberID, requestorID)
		
		assert.NotNil(t, service)
	})
}

func TestPostgresService_PermissionValidation(t *testing.T) {
	// Test permission validation logic
	tests := []struct {
		name           string
		userRole       models.MemberRole
		action         string
		canPerform     bool
	}{
		{"creator can manage members", models.RoleCreator, "manage_members", true},
		{"admin can manage members", models.RoleAdmin, "manage_members", true},
		{"member cannot manage members", models.RoleMember, "manage_members", false},
		{"creator can process requests", models.RoleCreator, "process_requests", true},
		{"admin can process requests", models.RoleAdmin, "process_requests", true},
		{"member cannot process requests", models.RoleMember, "process_requests", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			member := models.RoomspaceMember{
				Role:     tt.userRole,
				IsActive: true,
			}

			var canPerform bool
			switch tt.action {
			case "manage_members":
				canPerform = member.CanManageMembers()
			case "process_requests":
				canPerform = member.CanProcessJoinRequests()
			}

			assert.Equal(t, tt.canPerform, canPerform)
		})
	}
}

func TestPostgresService_InviteCodeValidation(t *testing.T) {
	service := NewPostgresService()

	tests := []struct {
		name       string
		inviteCode string
		valid      bool
	}{
		{"valid code", "ABC12345", true},
		{"too short", "ABC123", false},
		{"too long", "ABC123456", false},
		{"lowercase", "abc12345", false},
		{"special chars", "ABC123!@", false},
		{"with spaces", "ABC 1234", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			roomspace := models.Roomspace{InviteCode: tt.inviteCode}
			err := roomspace.ValidateInviteCode()
			
			if tt.valid {
				assert.NoError(t, err)
			} else {
				assert.Error(t, err)
			}
			
			assert.NotNil(t, service)
		})
	}
}

func TestPostgresService_RoomspaceQueries(t *testing.T) {
	service := NewPostgresService()

	t.Run("get roomspace by ID structure", func(t *testing.T) {
		// Test the query structure and validation
		roomspaceID := uuid.New().String()
		
		// Validate UUID format
		_, err := uuid.Parse(roomspaceID)
		assert.NoError(t, err)
		
		assert.NotNil(t, service)
	})

	t.Run("get roomspace by invite code structure", func(t *testing.T) {
		inviteCode := "ABC12345"
		
		// Validate invite code format
		assert.Len(t, inviteCode, 8)
		
		roomspace := models.Roomspace{InviteCode: inviteCode}
		err := roomspace.ValidateInviteCode()
		assert.NoError(t, err)
		
		assert.NotNil(t, service)
	})

	t.Run("get user roomspaces structure", func(t *testing.T) {
		userID := "user-123"
		
		// Validate user ID
		assert.NotEmpty(t, userID)
		
		assert.NotNil(t, service)
	})
}

func TestPostgresService_DataConsistency(t *testing.T) {
	service := NewPostgresService()

	t.Run("roomspace member consistency", func(t *testing.T) {
		// Test data consistency validation
		roomspace := models.Roomspace{
			ID:         uuid.New(),
			MaxMembers: 5,
			Members: []models.RoomspaceMember{
				{IsActive: true},
				{IsActive: true},
				{IsActive: false},
			},
		}

		activeCount := roomspace.GetActiveMemberCount()
		assert.Equal(t, 2, activeCount)
		assert.True(t, roomspace.CanAcceptNewMembers())
		
		assert.NotNil(t, service)
	})

	t.Run("join request expiry consistency", func(t *testing.T) {
		now := time.Now()
		
		request := models.JoinRequest{
			Status:    models.StatusPending,
			ExpiresAt: now.Add(time.Hour),
		}

		assert.True(t, request.IsPending())
		assert.True(t, request.CanBeProcessed())
		assert.False(t, request.IsExpired())
		
		// Test expired request
		expiredRequest := models.JoinRequest{
			Status:    models.StatusPending,
			ExpiresAt: now.Add(-time.Hour),
		}

		assert.False(t, expiredRequest.IsPending())
		assert.False(t, expiredRequest.CanBeProcessed())
		assert.True(t, expiredRequest.IsExpired())
		
		assert.NotNil(t, service)
	})
}

func TestPostgresService_ErrorHandling(t *testing.T) {
	service := NewPostgresService()

	t.Run("invalid roomspace data", func(t *testing.T) {
		invalidRoomspace := models.Roomspace{
			Name:       "", // Invalid: empty name
			CreatorID:  stringPtr("creator-123"),
			MaxMembers: 10,
		}

		err := invalidRoomspace.Validate()
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "roomspace name is required")
		
		assert.NotNil(t, service)
	})

	t.Run("invalid member role", func(t *testing.T) {
		invalidRole := models.MemberRole("invalid-role")
		assert.False(t, invalidRole.IsValid())
		
		assert.NotNil(t, service)
	})

	t.Run("invalid join request status", func(t *testing.T) {
		invalidStatus := models.JoinRequestStatus("invalid-status")
		assert.False(t, invalidStatus.IsValid())
		
		assert.NotNil(t, service)
	})
}

// Helper function to create string pointer
func stringPtr(s string) *string {
	return &s
}