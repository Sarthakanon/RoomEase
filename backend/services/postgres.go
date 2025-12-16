package services

import (
	"crypto/rand"
	"errors"
	"math/big"
	"roomease/backend/config"
	"roomease/backend/models"
	"time"

	"gorm.io/gorm"
)

// generateInviteCode creates a unique 8-character alphanumeric code
func generateInviteCode() string {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	code := make([]byte, 8)
	for i := range code {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		code[i] = charset[n.Int64()]
	}
	return string(code)
}

// PostgresService handles PostgreSQL operations
type PostgresService struct{}

// NewPostgresService creates a new PostgreSQL service
func NewPostgresService() *PostgresService {
	return &PostgresService{}
}

// User Operations

// GetUserByFirebaseUID retrieves a user by Firebase UID
func (s *PostgresService) GetUserByFirebaseUID(firebaseUID string) (*models.User, error) {
	var user models.User
	result := config.DB.Where("firebase_uid = ?", firebaseUID).First(&user)
	
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, result.Error
	}
	
	return &user, nil
}

// CreateUser creates a new user in PostgreSQL
func (s *PostgresService) CreateUser(user *models.User) error {
	result := config.DB.Create(user)
	return result.Error
}

// UpdateUser updates an existing user
func (s *PostgresService) UpdateUser(firebaseUID string, update *models.UpdateUserRequest) error {
	updates := make(map[string]interface{})
	
	if update.Name != "" {
		updates["name"] = update.Name
	}
	if update.Phone != "" {
		updates["phone"] = update.Phone
	}
	
	result := config.DB.Model(&models.User{}).
		Where("firebase_uid = ?", firebaseUID).
		Updates(updates)
	
	if result.Error != nil {
		return result.Error
	}
	
	if result.RowsAffected == 0 {
		return errors.New("user not found")
	}
	
	return nil
}

// Roomspace Operations

// GetRoomspaceByID retrieves a roomspace by ID
func (s *PostgresService) GetRoomspaceByID(id uint) (*models.Roomspace, error) {
	var roomspace models.Roomspace
	result := config.DB.Preload("Members").Preload("Members.User").First(&roomspace, id)
	
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errors.New("roomspace not found")
		}
		return nil, result.Error
	}
	
	return &roomspace, nil
}

// CreateRoomspace creates a new roomspace
func (s *PostgresService) CreateRoomspace(roomspace *models.Roomspace) error {
	// Start a transaction
	return config.DB.Transaction(func(tx *gorm.DB) error {
		// Generate unique invite code
		for {
			roomspace.InviteCode = generateInviteCode()
			var existing models.Roomspace
			if err := tx.Where("invite_code = ?", roomspace.InviteCode).First(&existing).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					break // Code is unique
				}
				return err
			}
			// Code exists, generate a new one
		}

		// Create the roomspace
		if err := tx.Create(roomspace).Error; err != nil {
			return err
		}
		
		// Add creator as a member
		member := models.RoomspaceMember{
			RoomspaceID: roomspace.ID,
			FirebaseUID: roomspace.CreatedBy,
			JoinedAt:    time.Now(),
		}
		
		if err := tx.Create(&member).Error; err != nil {
			return err
		}
		
		return nil
	})
}

// GetUserRoomspaces retrieves all roomspaces for a user
func (s *PostgresService) GetUserRoomspaces(firebaseUID string) ([]models.Roomspace, error) {
	var roomspaces []models.Roomspace
	
	result := config.DB.
		Joins("JOIN roomspace_members ON roomspace_members.roomspace_id = roomspaces.id").
		Where("roomspace_members.firebase_uid = ?", firebaseUID).
		Preload("Members", func(db *gorm.DB) *gorm.DB {
			return db.Preload("User")
		}).
		Find(&roomspaces)
	
	if result.Error != nil {
		return nil, result.Error
	}
	
	return roomspaces, nil
}

// GetRoomspaceByInviteCode retrieves a roomspace by its invite code
func (s *PostgresService) GetRoomspaceByInviteCode(inviteCode string) (*models.Roomspace, error) {
	var roomspace models.Roomspace
	result := config.DB.Preload("Members").Preload("Members.User").Where("invite_code = ?", inviteCode).First(&roomspace)
	
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errors.New("roomspace not found")
		}
		return nil, result.Error
	}
	
	return &roomspace, nil
}

// RemoveMemberFromRoomspace removes a user from a roomspace (only creator can do this)
func (s *PostgresService) RemoveMemberFromRoomspace(roomspaceID uint, memberFirebaseUID string, requestorFirebaseUID string) error {
	// Check if roomspace exists and get creator
	var roomspace models.Roomspace
	if err := config.DB.First(&roomspace, roomspaceID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("roomspace not found")
		}
		return err
	}

	// Only creator can remove members
	if roomspace.CreatedBy != requestorFirebaseUID {
		return errors.New("only the creator can remove members")
	}

	// Cannot remove the creator
	if memberFirebaseUID == roomspace.CreatedBy {
		return errors.New("creator cannot be removed from the roomspace")
	}

	// Remove the member
	result := config.DB.Where("roomspace_id = ? AND firebase_uid = ?", roomspaceID, memberFirebaseUID).
		Delete(&models.RoomspaceMember{})

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return errors.New("member not found in this roomspace")
	}

	return nil
}

// AddMemberToRoomspace adds a user to a roomspace
func (s *PostgresService) AddMemberToRoomspace(roomspaceID uint, firebaseUID string) error {
	// Check if roomspace exists
	var roomspace models.Roomspace
	if err := config.DB.First(&roomspace, roomspaceID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("roomspace not found")
		}
		return err
	}
	
	// Check if user is already a member
	var existingMember models.RoomspaceMember
	result := config.DB.Where("roomspace_id = ? AND firebase_uid = ?", roomspaceID, firebaseUID).
		First(&existingMember)
	
	if result.Error == nil {
		return errors.New("user is already a member")
	}
	
	// Add new member
	member := models.RoomspaceMember{
		RoomspaceID: roomspaceID,
		FirebaseUID: firebaseUID,
		JoinedAt:    time.Now(),
	}
	
	return config.DB.Create(&member).Error
}

// Join Request Operations

// CreateJoinRequest creates a new join request
func (s *PostgresService) CreateJoinRequest(roomspaceID uint, requesterUID string) (*models.JoinRequest, error) {
	// Check if roomspace exists
	var roomspace models.Roomspace
	if err := config.DB.First(&roomspace, roomspaceID).Error; err != nil {
		return nil, errors.New("roomspace not found")
	}

	// Check if user is already a member
	var existingMember models.RoomspaceMember
	if err := config.DB.Where("roomspace_id = ? AND firebase_uid = ?", roomspaceID, requesterUID).First(&existingMember).Error; err == nil {
		return nil, errors.New("you are already a member of this roomspace")
	}

	// Check if there's already a pending request
	var existingRequest models.JoinRequest
	if err := config.DB.Where("roomspace_id = ? AND requester_uid = ? AND status = ?", roomspaceID, requesterUID, models.JoinRequestStatusPending).First(&existingRequest).Error; err == nil {
		return nil, errors.New("you already have a pending join request")
	}

	request := &models.JoinRequest{
		RoomspaceID:  roomspaceID,
		RequesterUID: requesterUID,
		Status:       models.JoinRequestStatusPending,
	}

	if err := config.DB.Create(request).Error; err != nil {
		return nil, err
	}

	return request, nil
}

// GetPendingJoinRequest gets a user's pending join request
func (s *PostgresService) GetPendingJoinRequest(requesterUID string) (*models.JoinRequest, error) {
	var request models.JoinRequest
	err := config.DB.Preload("Roomspace").Where("requester_uid = ? AND status = ?", requesterUID, models.JoinRequestStatusPending).First(&request).Error
	if err != nil {
		return nil, err
	}
	return &request, nil
}

// GetJoinRequestByID gets a join request by ID
func (s *PostgresService) GetJoinRequestByID(id uint) (*models.JoinRequest, error) {
	var request models.JoinRequest
	err := config.DB.Preload("Roomspace").Preload("Requester").First(&request, id).Error
	if err != nil {
		return nil, err
	}
	return &request, nil
}

// GetJoinRequestsForRoomspace gets all pending join requests for a roomspace
func (s *PostgresService) GetJoinRequestsForRoomspace(roomspaceID uint) ([]models.JoinRequest, error) {
	var requests []models.JoinRequest
	err := config.DB.Preload("Requester").Where("roomspace_id = ? AND status = ?", roomspaceID, models.JoinRequestStatusPending).Find(&requests).Error
	return requests, err
}

// ProcessJoinRequest accepts or rejects a join request
func (s *PostgresService) ProcessJoinRequest(requestID uint, processedByUID string, accept bool) error {
	var request models.JoinRequest
	if err := config.DB.First(&request, requestID).Error; err != nil {
		return errors.New("join request not found")
	}

	if request.Status != models.JoinRequestStatusPending {
		return errors.New("this request has already been processed")
	}

	// Verify processor is a member of the roomspace
	var member models.RoomspaceMember
	if err := config.DB.Where("roomspace_id = ? AND firebase_uid = ?", request.RoomspaceID, processedByUID).First(&member).Error; err != nil {
		return errors.New("you are not a member of this roomspace")
	}

	return config.DB.Transaction(func(tx *gorm.DB) error {
		if accept {
			request.Status = models.JoinRequestStatusAccepted
			// Add user as member
			newMember := models.RoomspaceMember{
				RoomspaceID: request.RoomspaceID,
				FirebaseUID: request.RequesterUID,
				JoinedAt:    time.Now(),
			}
			if err := tx.Create(&newMember).Error; err != nil {
				return err
			}
		} else {
			request.Status = models.JoinRequestStatusRejected
		}
		request.ProcessedBy = processedByUID
		return tx.Save(&request).Error
	})
}

// Notification Operations

// CreateNotification creates a new notification
func (s *PostgresService) CreateNotification(notification *models.Notification) error {
	return config.DB.Create(notification).Error
}

// GetUserNotifications gets all notifications for a user
func (s *PostgresService) GetUserNotifications(userUID string) ([]models.Notification, error) {
	var notifications []models.Notification
	err := config.DB.Where("recipient_uid = ?", userUID).Order("created_at DESC").Find(&notifications).Error
	return notifications, err
}

// MarkNotificationAsRead marks a notification as read
func (s *PostgresService) MarkNotificationAsRead(notificationID uint, userUID string) error {
	result := config.DB.Model(&models.Notification{}).Where("id = ? AND recipient_uid = ?", notificationID, userUID).Update("is_read", true)
	if result.RowsAffected == 0 {
		return errors.New("notification not found")
	}
	return result.Error
}

// GetRoomspaceMembers gets all members of a roomspace
func (s *PostgresService) GetRoomspaceMembers(roomspaceID uint) ([]models.RoomspaceMember, error) {
	var members []models.RoomspaceMember
	err := config.DB.Preload("User").Where("roomspace_id = ?", roomspaceID).Find(&members).Error
	return members, err
}

// AutoMigrate runs database migrations
func (s *PostgresService) AutoMigrate() error {
	// Migrate in correct order: independent tables first, then dependent tables
	// Users and Roomspaces have no dependencies
	// RoomspaceMember depends on both User and Roomspace
	// JoinRequest depends on User and Roomspace
	// Notification depends on User
	
	err := config.DB.AutoMigrate(
		&models.User{},           // No dependencies
		&models.Notification{},   // Depends on User (by UID string, no FK)
		&models.Roomspace{},      // No dependencies (Members loaded via separate query)
		&models.RoomspaceMember{}, // Depends on User and Roomspace
		&models.JoinRequest{},    // Depends on User and Roomspace
	)
	if err != nil {
		return err
	}

	// Generate invite codes for existing roomspaces that don't have one
	var roomspaces []models.Roomspace
	config.DB.Where("invite_code IS NULL OR invite_code = ''").Find(&roomspaces)
	for _, rs := range roomspaces {
		for {
			code := generateInviteCode()
			var existing models.Roomspace
			if err := config.DB.Where("invite_code = ?", code).First(&existing).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					config.DB.Model(&rs).Update("invite_code", code)
					break
				}
			}
		}
	}

	return nil
}
