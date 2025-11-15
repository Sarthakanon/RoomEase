package services

import (
	"errors"
	"roomease/backend/config"
	"roomease/backend/models"
	"time"

	"gorm.io/gorm"
)

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
	result := config.DB.Preload("Members").First(&roomspace, id)
	
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
		Preload("Members").
		Find(&roomspaces)
	
	if result.Error != nil {
		return nil, result.Error
	}
	
	return roomspaces, nil
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

// AutoMigrate runs database migrations
func (s *PostgresService) AutoMigrate() error {
	return config.DB.AutoMigrate(
		&models.User{},
		&models.Roomspace{},
		&models.RoomspaceMember{},
	)
}
