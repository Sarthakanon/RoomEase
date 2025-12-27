package models

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestJoinRequestStatus_IsValid(t *testing.T) {
	tests := []struct {
		name     string
		status   JoinRequestStatus
		expected bool
	}{
		{"pending status", StatusPending, true},
		{"approved status", StatusApproved, true},
		{"rejected status", StatusRejected, true},
		{"expired status", StatusExpired, true},
		{"cancelled status", StatusCancelled, true},
		{"invalid status", JoinRequestStatus("invalid"), false},
		{"empty status", JoinRequestStatus(""), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.status.IsValid())
		})
	}
}

func TestJoinRequestStatus_IsFinal(t *testing.T) {
	tests := []struct {
		name     string
		status   JoinRequestStatus
		expected bool
	}{
		{"pending status", StatusPending, false},
		{"approved status", StatusApproved, true},
		{"rejected status", StatusRejected, true},
		{"expired status", StatusExpired, true},
		{"cancelled status", StatusCancelled, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.status.IsFinal())
		})
	}
}

func TestJoinRequestStatus_String(t *testing.T) {
	assert.Equal(t, "pending", StatusPending.String())
	assert.Equal(t, "approved", StatusApproved.String())
	assert.Equal(t, "rejected", StatusRejected.String())
	assert.Equal(t, "expired", StatusExpired.String())
	assert.Equal(t, "cancelled", StatusCancelled.String())
}

func TestJoinRequest_IsExpired(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		expiresAt time.Time
		expected  bool
	}{
		{"not expired", now.Add(time.Hour), false},
		{"expired", now.Add(-time.Hour), true},
		{"just expired", now.Add(-time.Minute), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{ExpiresAt: tt.expiresAt}
			assert.Equal(t, tt.expected, request.IsExpired())
		})
	}
}

func TestJoinRequest_IsPending(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		status    JoinRequestStatus
		expiresAt time.Time
		expected  bool
	}{
		{"pending and not expired", StatusPending, now.Add(time.Hour), true},
		{"pending but expired", StatusPending, now.Add(-time.Hour), false},
		{"approved and not expired", StatusApproved, now.Add(time.Hour), false},
		{"rejected and not expired", StatusRejected, now.Add(time.Hour), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			assert.Equal(t, tt.expected, request.IsPending())
		})
	}
}

func TestJoinRequest_CanBeProcessed(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		status    JoinRequestStatus
		expiresAt time.Time
		expected  bool
	}{
		{"pending and not expired", StatusPending, now.Add(time.Hour), true},
		{"pending but expired", StatusPending, now.Add(-time.Hour), false},
		{"approved", StatusApproved, now.Add(time.Hour), false},
		{"rejected", StatusRejected, now.Add(time.Hour), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			assert.Equal(t, tt.expected, request.CanBeProcessed())
		})
	}
}

func TestJoinRequest_GetTimeUntilExpiry(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		expiresAt time.Time
		expected  time.Duration
	}{
		{"1 hour until expiry", now.Add(time.Hour), time.Hour},
		{"already expired", now.Add(-time.Hour), 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{ExpiresAt: tt.expiresAt}
			duration := request.GetTimeUntilExpiry()
			
			if tt.expected == 0 {
				assert.Equal(t, time.Duration(0), duration)
			} else {
				// Allow some tolerance for test execution time
				assert.InDelta(t, tt.expected.Seconds(), duration.Seconds(), 1.0)
			}
		})
	}
}

func TestJoinRequest_GetDaysUntilExpiry(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		expiresAt time.Time
		expected  int
	}{
		{"7 days until expiry", now.Add(7 * 24 * time.Hour), 6}, // Account for rounding
		{"1 day until expiry", now.Add(25 * time.Hour), 1}, // 25 hours = 1 day
		{"already expired", now.Add(-time.Hour), 0},
		{"less than 1 day", now.Add(12 * time.Hour), 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{ExpiresAt: tt.expiresAt}
			days := request.GetDaysUntilExpiry()
			assert.Equal(t, tt.expected, days)
		})
	}
}

func TestJoinRequest_Approve(t *testing.T) {
	now := time.Now()
	processorID := "processor-123"
	
	tests := []struct {
		name      string
		status    JoinRequestStatus
		expiresAt time.Time
		wantErr   bool
	}{
		{"can approve pending", StatusPending, now.Add(time.Hour), false},
		{"cannot approve expired", StatusPending, now.Add(-time.Hour), true},
		{"cannot approve already approved", StatusApproved, now.Add(time.Hour), true},
		{"cannot approve rejected", StatusRejected, now.Add(time.Hour), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			
			err := request.Approve(processorID)
			
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, StatusApproved, request.Status)
				assert.NotNil(t, request.ProcessedAt)
				assert.NotNil(t, request.ProcessedBy)
				assert.Equal(t, processorID, *request.ProcessedBy)
				assert.Nil(t, request.RejectionReason)
			}
		})
	}
}

func TestJoinRequest_Reject(t *testing.T) {
	now := time.Now()
	processorID := "processor-123"
	reason := "Not suitable"
	
	tests := []struct {
		name      string
		status    JoinRequestStatus
		expiresAt time.Time
		wantErr   bool
	}{
		{"can reject pending", StatusPending, now.Add(time.Hour), false},
		{"cannot reject expired", StatusPending, now.Add(-time.Hour), true},
		{"cannot reject already approved", StatusApproved, now.Add(time.Hour), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			
			err := request.Reject(processorID, reason)
			
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, StatusRejected, request.Status)
				assert.NotNil(t, request.ProcessedAt)
				assert.NotNil(t, request.ProcessedBy)
				assert.Equal(t, processorID, *request.ProcessedBy)
				assert.NotNil(t, request.RejectionReason)
				assert.Equal(t, reason, *request.RejectionReason)
			}
		})
	}
}

func TestJoinRequest_Expire(t *testing.T) {
	tests := []struct {
		name    string
		status  JoinRequestStatus
		wantErr bool
	}{
		{"can expire pending", StatusPending, false},
		{"cannot expire approved", StatusApproved, true},
		{"cannot expire rejected", StatusRejected, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{Status: tt.status}
			
			err := request.Expire()
			
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, StatusExpired, request.Status)
				assert.NotNil(t, request.ProcessedAt)
			}
		})
	}
}

func TestJoinRequest_Cancel(t *testing.T) {
	tests := []struct {
		name    string
		status  JoinRequestStatus
		wantErr bool
	}{
		{"can cancel pending", StatusPending, false},
		{"cannot cancel approved", StatusApproved, true},
		{"cannot cancel rejected", StatusRejected, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{Status: tt.status}
			
			err := request.Cancel()
			
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, StatusCancelled, request.Status)
				assert.NotNil(t, request.ProcessedAt)
			}
		})
	}
}

func TestJoinRequest_GetDisplayStatus(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		status    JoinRequestStatus
		expiresAt time.Time
		expected  string
	}{
		{"pending not expired", StatusPending, now.Add(time.Hour), "Pending"},
		{"pending expired", StatusPending, now.Add(-time.Hour), "Expired"},
		{"approved", StatusApproved, now.Add(time.Hour), "Approved"},
		{"rejected", StatusRejected, now.Add(time.Hour), "Rejected"},
		{"expired", StatusExpired, now.Add(time.Hour), "Expired"},
		{"cancelled", StatusCancelled, now.Add(time.Hour), "Cancelled"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			assert.Equal(t, tt.expected, request.GetDisplayStatus())
		})
	}
}

func TestJoinRequest_GetStatusColor(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name      string
		status    JoinRequestStatus
		expiresAt time.Time
		expected  string
	}{
		{"pending not expired", StatusPending, now.Add(time.Hour), "#FFA726"},
		{"pending expired", StatusPending, now.Add(-time.Hour), "#FF6B6B"},
		{"approved", StatusApproved, now.Add(time.Hour), "#66BB6A"},
		{"rejected", StatusRejected, now.Add(time.Hour), "#EF5350"},
		{"expired", StatusExpired, now.Add(time.Hour), "#BDBDBD"},
		{"cancelled", StatusCancelled, now.Add(time.Hour), "#9E9E9E"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			assert.Equal(t, tt.expected, request.GetStatusColor())
		})
	}
}

func TestJoinRequest_CanBeCancelledBy(t *testing.T) {
	requesterID := "requester-123"
	otherUserID := "other-456"
	
	tests := []struct {
		name        string
		status      JoinRequestStatus
		requesterID string
		userID      string
		expected    bool
	}{
		{"requester can cancel pending", StatusPending, requesterID, requesterID, true},
		{"other user cannot cancel", StatusPending, requesterID, otherUserID, false},
		{"requester cannot cancel approved", StatusApproved, requesterID, requesterID, false},
		{"requester cannot cancel rejected", StatusRejected, requesterID, requesterID, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:      tt.status,
				RequesterID: tt.requesterID,
			}
			assert.Equal(t, tt.expected, request.CanBeCancelledBy(tt.userID))
		})
	}
}

func TestJoinRequest_GetProcessingInfo(t *testing.T) {
	now := time.Now()
	processorID := "processor-123"
	reason := "Not suitable"
	
	// Test unprocessed request
	request := JoinRequest{
		Status:    StatusPending,
		ExpiresAt: now.Add(2 * 24 * time.Hour),
	}
	
	info := request.GetProcessingInfo()
	assert.False(t, info["is_processed"].(bool))
	assert.Equal(t, "Pending", info["status"])
	assert.Equal(t, 1, info["days_until_expiry"]) // Account for rounding
	assert.False(t, info["is_expired"].(bool))
	
	// Test processed request
	processedAt := now.Add(-time.Hour)
	request = JoinRequest{
		Status:          StatusRejected,
		ProcessedAt:     &processedAt,
		ProcessedBy:     &processorID,
		RejectionReason: &reason,
	}
	
	info = request.GetProcessingInfo()
	assert.True(t, info["is_processed"].(bool))
	assert.Equal(t, "Rejected", info["status"])
	assert.Equal(t, &processedAt, info["processed_at"])
	assert.Equal(t, &processorID, info["processed_by"])
	assert.Equal(t, reason, info["rejection_reason"])
}

func TestJoinRequest_BeforeCreate(t *testing.T) {
	request := JoinRequest{
		RoomspaceID: uuid.New(),
		RequesterID: "requester-123",
	}

	err := request.BeforeCreate(nil)
	assert.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, request.ID)
	assert.Equal(t, StatusPending, request.Status)
	assert.False(t, request.ExpiresAt.IsZero())
}

func TestJoinRequest_BeforeUpdate(t *testing.T) {
	now := time.Now()
	
	tests := []struct {
		name        string
		status      JoinRequestStatus
		processedAt *time.Time
		wantErr     bool
	}{
		{"valid status", StatusApproved, nil, false},
		{"invalid status", JoinRequestStatus("invalid"), nil, true},
		{"pending with processed_at", StatusPending, &now, false},
		{"approved without processed_at", StatusApproved, nil, false}, // Should set processed_at
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := JoinRequest{
				Status:      tt.status,
				ProcessedAt: tt.processedAt,
			}
			
			err := request.BeforeUpdate(nil)
			
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				if tt.status != StatusPending && tt.processedAt == nil {
					assert.NotNil(t, request.ProcessedAt)
				}
			}
		})
	}
}

func TestJoinRequest_TableName(t *testing.T) {
	request := JoinRequest{}
	assert.Equal(t, "join_requests", request.TableName())
}