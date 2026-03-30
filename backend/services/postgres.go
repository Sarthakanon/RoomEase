package services

import (
	"crypto/rand"
	"errors"
	"fmt"
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
	// Check if database is connected
	if config.DB == nil {
		return nil, errors.New("database connection not available")
	}
	
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
func (s *PostgresService) GetRoomspaceByID(id string) (*models.Roomspace, error) {
	var roomspace models.Roomspace
	result := config.DB.Preload("Members").Preload("Members.User").Where("id = ?", id).First(&roomspace)
	
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
	// Check roomspace limit before creating
	if roomspace.CreatorID != nil {
		if err := s.CheckRoomspaceLimit(*roomspace.CreatorID); err != nil {
			return err
		}
	}
	
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
			UserID:      *roomspace.CreatorID,
			Role:        models.RoleCreator,
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
		Where("roomspace_members.user_id = ?", firebaseUID).
		Preload("Members", func(db *gorm.DB) *gorm.DB {
			return db.Preload("User")
		}).
		Find(&roomspaces)
	
	if result.Error != nil {
		return nil, result.Error
	}
	
	return roomspaces, nil
}

// GetUserRoomspaceCount retrieves the count of active roomspaces for a user
func (s *PostgresService) GetUserRoomspaceCount(firebaseUID string) (int64, error) {
	var count int64
	err := config.DB.Model(&models.RoomspaceMember{}).
		Where("user_id = ? AND is_active = ?", firebaseUID, true).
		Count(&count).Error
	
	if err != nil {
		return 0, err
	}
	
	return count, nil
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
func (s *PostgresService) RemoveMemberFromRoomspace(roomspaceID string, memberFirebaseUID string, requestorFirebaseUID string) error {
	// Check if roomspace exists and get creator
	var roomspace models.Roomspace
	if err := config.DB.Where("id = ?", roomspaceID).First(&roomspace).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("roomspace not found")
		}
		return err
	}

	// Only creator can remove members
	if roomspace.CreatorID == nil || *roomspace.CreatorID != requestorFirebaseUID {
		return errors.New("only the creator can remove members")
	}

	// Cannot remove the creator
	if memberFirebaseUID == *roomspace.CreatorID {
		return errors.New("creator cannot be removed from the roomspace")
	}

	// Remove the member
	result := config.DB.Where("roomspace_id = ? AND user_id = ?", roomspaceID, memberFirebaseUID).
		Delete(&models.RoomspaceMember{})

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return errors.New("member not found in this roomspace")
	}

	return nil
}

// CheckRoomspaceLimit verifies user hasn't exceeded 5 roomspace limit
func (s *PostgresService) CheckRoomspaceLimit(userUID string) error {
	var count int64
	err := config.DB.Model(&models.RoomspaceMember{}).
		Where("user_id = ? AND is_active = ?", userUID, true).
		Count(&count).Error
	
	if err != nil {
		return err
	}
	
	if count >= 5 {
		return errors.New("maximum roomspace limit (5) reached")
	}
	return nil
}

// ValidateRoomspaceMembership checks if user is member of requested roomspace
func (s *PostgresService) ValidateRoomspaceMembership(userUID, roomspaceID string) error {
	var member models.RoomspaceMember
	err := config.DB.Where("user_id = ? AND roomspace_id = ? AND is_active = ?", 
		userUID, roomspaceID, true).First(&member).Error
	
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("user is not a member of this roomspace")
		}
		return err
	}
	return nil
}

// AddMemberToRoomspace adds a user to a roomspace
func (s *PostgresService) AddMemberToRoomspace(roomspaceID string, firebaseUID string) error {
	// Check roomspace limit before adding
	if err := s.CheckRoomspaceLimit(firebaseUID); err != nil {
		return err
	}
	
	// Check if roomspace exists
	var roomspace models.Roomspace
	if err := config.DB.Where("id = ?", roomspaceID).First(&roomspace).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("roomspace not found")
		}
		return err
	}
	
	// Check if user is already a member
	var existingMember models.RoomspaceMember
	result := config.DB.Where("roomspace_id = ? AND user_id = ?", roomspaceID, firebaseUID).
		First(&existingMember)
	
	if result.Error == nil {
		return errors.New("user is already a member")
	}
	
	// Add new member
	member := models.RoomspaceMember{
		RoomspaceID: roomspace.ID,
		UserID:      firebaseUID,
		Role:        models.RoleMember,
		JoinedAt:    time.Now(),
		IsActive:    true,
	}
	
	return config.DB.Create(&member).Error
}

// Join Request Operations

// CreateJoinRequest creates a new join request
func (s *PostgresService) CreateJoinRequest(roomspaceID string, requesterUID string, message string) (*models.JoinRequest, error) {
	// Check roomspace limit before creating join request
	if err := s.CheckRoomspaceLimit(requesterUID); err != nil {
		return nil, err
	}
	
	// Check if roomspace exists
	var roomspace models.Roomspace
	if err := config.DB.Where("id = ?", roomspaceID).First(&roomspace).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("roomspace not found")
		}
		return nil, err
	}
	
	// Check if user is already a member
	var existingMember models.RoomspaceMember
	result := config.DB.Where("roomspace_id = ? AND user_id = ?", roomspaceID, requesterUID).
		First(&existingMember)
	
	if result.Error == nil {
		return nil, errors.New("user is already a member")
	}
	
	// Check if there's already a pending request
	var existingRequest models.JoinRequest
	result = config.DB.Where("roomspace_id = ? AND requester_id = ? AND status = ?", 
		roomspaceID, requesterUID, models.StatusPending).First(&existingRequest)
	
	if result.Error == nil {
		return nil, errors.New("user already has a pending join request")
	}
	
	// Create new join request
	joinRequest := models.JoinRequest{
		RoomspaceID: roomspace.ID,
		RequesterID: requesterUID,
		Status:      models.StatusPending,
		RequestedAt: time.Now(),
		ExpiresAt:   time.Now().Add(7 * 24 * time.Hour), // 7 days
	}
	
	if message != "" {
		joinRequest.Message = &message
	}
	
	if err := config.DB.Create(&joinRequest).Error; err != nil {
		return nil, err
	}
	
	return &joinRequest, nil
}

// GetPendingJoinRequest gets a user's pending join request
func (s *PostgresService) GetPendingJoinRequest(requesterUID string) (*models.JoinRequest, error) {
	var request models.JoinRequest
	result := config.DB.Preload("Roomspace").
		Where("requester_id = ? AND status = ?", requesterUID, models.StatusPending).
		First(&request)
	
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errors.New("no pending join request found")
		}
		return nil, result.Error
	}
	
	return &request, nil
}

// GetJoinRequestsForRoomspace gets all pending join requests for a roomspace
func (s *PostgresService) GetJoinRequestsForRoomspace(roomspaceID string) ([]models.JoinRequest, error) {
	var requests []models.JoinRequest
	err := config.DB.Preload("Requester").Where("roomspace_id = ? AND status = ?", roomspaceID, models.StatusPending).Find(&requests).Error
	return requests, err
}

// ProcessJoinRequest accepts or rejects a join request
func (s *PostgresService) ProcessJoinRequest(requestID string, processedByUID string, accept bool, reason string) error {
	var request models.JoinRequest
	if err := config.DB.Where("id = ?", requestID).First(&request).Error; err != nil {
		return errors.New("join request not found")
	}

	if request.Status != models.StatusPending {
		return errors.New("this request has already been processed")
	}

	// Verify processor is a member of the roomspace
	var member models.RoomspaceMember
	if err := config.DB.Where("roomspace_id = ? AND user_id = ?", request.RoomspaceID, processedByUID).First(&member).Error; err != nil {
		return errors.New("you are not a member of this roomspace")
	}

	return config.DB.Transaction(func(tx *gorm.DB) error {
		if accept {
			request.Status = models.StatusApproved
			// Add user as member
			newMember := models.RoomspaceMember{
				RoomspaceID: request.RoomspaceID,
				UserID:      request.RequesterID,
				Role:        models.RoleMember,
				JoinedAt:    time.Now(),
				InvitedBy:   &processedByUID,
				IsActive:    true,
			}
			if err := tx.Create(&newMember).Error; err != nil {
				return err
			}
		} else {
			request.Status = models.StatusRejected
			if reason != "" {
				request.RejectionReason = &reason
			}
		}
		request.ProcessedBy = &processedByUID
		now := time.Now()
		request.ProcessedAt = &now
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
func (s *PostgresService) GetRoomspaceMembers(roomspaceID string) ([]models.RoomspaceMember, error) {
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
		&models.Expense{},        // Depends on Roomspace and User
		&models.ExpenseSplit{},   // Depends on Expense and User
		&models.PersonalExpense{}, // Depends on User only
		&models.PaymentNotification{}, // Depends on User only
		&models.AnalyticsCache{}, // Depends on User
		&models.RecommendationFeedback{}, // Depends on User
		&models.AnomalyAcknowledgment{}, // Depends on User and Expense
		&models.MLModel{},        // No dependencies
		&models.UserBalance{},    // Depends on User and Roomspace
		&models.Settlement{},     // Depends on User and Roomspace
		&models.PaymentConfirmation{}, // Depends on User and Roomspace
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
// GetJoinRequestByID gets a join request by ID
func (s *PostgresService) GetJoinRequestByID(id string) (*models.JoinRequest, error) {
	var request models.JoinRequest
	result := config.DB.Preload("Roomspace").Preload("Requester").
		Where("id = ?", id).First(&request)
	
	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errors.New("join request not found")
		}
		return nil, result.Error
	}
	
	return &request, nil
}

// Expense Operations (placeholder implementations)

// CreateExpense creates a new expense
func (s *PostgresService) CreateExpense(expense *models.Expense) error {
	tx := config.DB.Begin()
	if tx.Error != nil {
		return fmt.Errorf("failed to begin transaction: %v", tx.Error)
	}
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Create the expense record
	if err := tx.Create(expense).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to create expense: %v", err)
	}

	// Create the expense splits
	for i := range expense.Splits {
		expense.Splits[i].ID = 0  // Ensure ID is 0 for auto-increment
		expense.Splits[i].ExpenseID = expense.ID
		
		if err := tx.Create(&expense.Splits[i]).Error; err != nil {
			tx.Rollback()
			return fmt.Errorf("failed to create expense split: %v", err)
		}
	}

	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("failed to commit transaction: %v", err)
	}

	return nil
}

// GetUserExpenses gets expenses for a user with proper roomspace filtering
func (s *PostgresService) GetUserExpenses(userID string, roomspaceID string, limit, offset int) ([]models.Expense, error) {
	var expenses []models.Expense
	
	// If roomspace_id is provided, validate user membership first
	if roomspaceID != "" {
		if err := s.ValidateRoomspaceMembership(userID, roomspaceID); err != nil {
			return nil, fmt.Errorf("access denied: %v", err)
		}
		
		// Get expenses for the specific roomspace where user is involved
		query := config.DB.Preload("Payer").
			Preload("Splits").
			Preload("Splits.User").
			Where("roomspace_id = ?", roomspaceID).
			Where("paid_by = ? OR id IN (SELECT expense_id FROM expense_splits WHERE user_uid = ?)", userID, userID).
			Order("created_at DESC")
		
		if limit > 0 {
			query = query.Limit(limit)
		}
		
		if offset > 0 {
			query = query.Offset(offset)
		}
		
		err := query.Find(&expenses).Error
		if err != nil {
			return nil, fmt.Errorf("failed to get user expenses: %v", err)
		}
		
		return expenses, nil
	}
	
	// If no roomspace_id provided, get expenses from all user's roomspaces
	// First, get all roomspaces the user is a member of
	var memberRecords []models.RoomspaceMember
	if err := config.DB.Where("user_id = ? AND is_active = ?", userID, true).Find(&memberRecords).Error; err != nil {
		return nil, fmt.Errorf("failed to get user roomspaces: %v", err)
	}
	
	// Extract roomspace IDs
	var roomspaceIDs []string
	for _, member := range memberRecords {
		roomspaceIDs = append(roomspaceIDs, member.RoomspaceID.String())
	}
	
	// If user has no roomspaces, return empty list
	if len(roomspaceIDs) == 0 {
		return []models.Expense{}, nil
	}
	
	// Get expenses from user's roomspaces where user is involved
	query := config.DB.Preload("Payer").
		Preload("Splits").
		Preload("Splits.User").
		Where("roomspace_id IN ?", roomspaceIDs).
		Where("paid_by = ? OR id IN (SELECT expense_id FROM expense_splits WHERE user_uid = ?)", userID, userID).
		Order("created_at DESC")
	
	if limit > 0 {
		query = query.Limit(limit)
	}
	
	if offset > 0 {
		query = query.Offset(offset)
	}
	
	err := query.Find(&expenses).Error
	if err != nil {
		return nil, fmt.Errorf("failed to get user expenses: %v", err)
	}
	
	return expenses, nil
}

// GetExpenseByID gets an expense by ID
func (s *PostgresService) GetExpenseByID(id uint) (*models.Expense, error) {
	var expense models.Expense
	
	err := config.DB.Where("id = ?", id).
		Preload("Payer").
		Preload("Splits").
		Preload("Splits.User").
		First(&expense).Error
	
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("expense not found")
		}
		return nil, fmt.Errorf("failed to get expense: %v", err)
	}
	
	return &expense, nil
}

// GetRoomspaceExpenses gets expenses for a roomspace with membership validation
// Note: This method should be called after validating user membership in the handler
// Optional month/year filtering: if year and month are provided (> 0), filters by that month
func (s *PostgresService) GetRoomspaceExpenses(roomspaceID string, limit, offset int, year, month int) ([]models.Expense, error) {
	var expenses []models.Expense
	
	query := config.DB.Where("roomspace_id = ?", roomspaceID)
	
	// Add month/year filtering if provided
	if year > 0 && month > 0 {
		// Filter by year and month using EXTRACT
		query = query.Where("EXTRACT(YEAR FROM created_at) = ? AND EXTRACT(MONTH FROM created_at) = ?", year, month)
	} else if year > 0 {
		// Filter by year only
		query = query.Where("EXTRACT(YEAR FROM created_at) = ?", year)
	}
	
	query = query.Preload("Payer").
		Preload("Splits").
		Preload("Splits.User").
		Order("created_at DESC")
	
	if limit > 0 {
		query = query.Limit(limit)
	}
	
	if offset > 0 {
		query = query.Offset(offset)
	}
	
	err := query.Find(&expenses).Error
	if err != nil {
		return nil, fmt.Errorf("failed to get roomspace expenses: %v", err)
	}
	
	return expenses, nil
}

// GetRecentExpenses gets recent expenses for a roomspace
// Note: This method should be called after validating user membership in the handler
// Optional month/year filtering: if year and month are provided (> 0), filters by that month
func (s *PostgresService) GetRecentExpenses(roomspaceID string, limit int, year, month int) ([]models.Expense, error) {
	var expenses []models.Expense
	
	query := config.DB.Where("roomspace_id = ?", roomspaceID)
	
	// Add month/year filtering if provided
	if year > 0 && month > 0 {
		query = query.Where("EXTRACT(YEAR FROM created_at) = ? AND EXTRACT(MONTH FROM created_at) = ?", year, month)
	} else if year > 0 {
		query = query.Where("EXTRACT(YEAR FROM created_at) = ?", year)
	}
	
	err := query.Preload("Payer").
		Preload("Splits").
		Preload("Splits.User").
		Order("created_at DESC").
		Limit(limit).
		Find(&expenses).Error
	
	if err != nil {
		return nil, fmt.Errorf("failed to get recent expenses: %v", err)
	}
	
	return expenses, nil
}

// GetExpensesByRoomspaceWithValidation gets expenses for a roomspace with user membership validation
func (s *PostgresService) GetExpensesByRoomspaceWithValidation(userID, roomspaceID string, limit, offset int, year, month int) ([]models.Expense, error) {
	// Validate user membership first
	if err := s.ValidateRoomspaceMembership(userID, roomspaceID); err != nil {
		return nil, fmt.Errorf("access denied: %v", err)
	}
	
	// Get expenses for the roomspace
	return s.GetRoomspaceExpenses(roomspaceID, limit, offset, year, month)
}

// UpdateExpense updates an existing expense
func (s *PostgresService) UpdateExpense(expense *models.Expense) error {
	tx := config.DB.Begin()
	if tx.Error != nil {
		return fmt.Errorf("failed to begin transaction: %v", tx.Error)
	}
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Update the expense record
	if err := tx.Save(expense).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to update expense: %v", err)
	}

	// Delete existing splits
	if err := tx.Where("expense_id = ?", expense.ID).Delete(&models.ExpenseSplit{}).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to delete existing splits: %v", err)
	}

	// Create new splits
	for i := range expense.Splits {
		expense.Splits[i].ID = 0  // Ensure ID is 0 for auto-increment
		expense.Splits[i].ExpenseID = expense.ID
		
		if err := tx.Create(&expense.Splits[i]).Error; err != nil {
			tx.Rollback()
			return fmt.Errorf("failed to create expense split: %v", err)
		}
	}

	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("failed to commit transaction: %v", err)
	}

	return nil
}

// DeleteExpense soft deletes an expense
func (s *PostgresService) DeleteExpense(id uint) error {
	tx := config.DB.Begin()
	if tx.Error != nil {
		return fmt.Errorf("failed to begin transaction: %v", tx.Error)
	}
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Soft delete the expense (GORM will handle the deleted_at field)
	if err := tx.Delete(&models.Expense{}, id).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to delete expense: %v", err)
	}

	// Note: We don't need to delete splits manually as they have CASCADE delete constraint

	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("failed to commit transaction: %v", err)
	}

	return nil
}

// Personal Expense Operations

// CreatePersonalExpense creates a new personal expense
func (s *PostgresService) CreatePersonalExpense(expense *models.PersonalExpense) error {
	if err := config.DB.Create(expense).Error; err != nil {
		return fmt.Errorf("failed to create personal expense: %v", err)
	}
	return nil
}

// GetPersonalExpenses gets personal expenses for a user
// Optional month/year filtering: if year and month are provided (> 0), filters by that month
func (s *PostgresService) GetPersonalExpenses(userUID string, limit, offset int, year, month int) ([]models.PersonalExpense, error) {
	var expenses []models.PersonalExpense
	
	query := config.DB.Where("user_uid = ?", userUID)
	
	// Add month/year filtering if provided
	if year > 0 && month > 0 {
		query = query.Where("EXTRACT(YEAR FROM created_at) = ? AND EXTRACT(MONTH FROM created_at) = ?", year, month)
	} else if year > 0 {
		query = query.Where("EXTRACT(YEAR FROM created_at) = ?", year)
	}
	
	query = query.Order("created_at DESC")
	
	if limit > 0 {
		query = query.Limit(limit)
	}
	
	if offset > 0 {
		query = query.Offset(offset)
	}
	
	if err := query.Find(&expenses).Error; err != nil {
		return nil, fmt.Errorf("failed to get personal expenses: %v", err)
	}
	
	return expenses, nil
}

// GetPersonalExpenseByID gets a personal expense by ID
func (s *PostgresService) GetPersonalExpenseByID(id uint) (*models.PersonalExpense, error) {
	var expense models.PersonalExpense
	
	if err := config.DB.First(&expense, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("personal expense not found")
		}
		return nil, fmt.Errorf("failed to get personal expense: %v", err)
	}
	
	return &expense, nil
}

// DeletePersonalExpense soft deletes a personal expense
func (s *PostgresService) DeletePersonalExpense(id uint) error {
	if err := config.DB.Delete(&models.PersonalExpense{}, id).Error; err != nil {
		return fmt.Errorf("failed to delete personal expense: %v", err)
	}
	
	return nil
}

// ManualSchemaFix fixes schema inconsistencies between database and models
func (s *PostgresService) ManualSchemaFix() error {
	fmt.Println("Running manual schema fixes...")
	
	// Check if created_by column exists and creator_id doesn't
	var createdByExists, creatorIdExists bool
	
	config.DB.Raw(`
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns 
			WHERE table_name = 'roomspaces' 
			AND column_name = 'created_by'
		)
	`).Row().Scan(&createdByExists)
	
	config.DB.Raw(`
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns 
			WHERE table_name = 'roomspaces' 
			AND column_name = 'creator_id'
		)
	`).Row().Scan(&creatorIdExists)
	
	if createdByExists && !creatorIdExists {
		fmt.Println("Renaming created_by to creator_id in roomspaces table...")
		if err := config.DB.Exec("ALTER TABLE roomspaces RENAME COLUMN created_by TO creator_id").Error; err != nil {
			return fmt.Errorf("failed to rename created_by to creator_id: %v", err)
		}
		fmt.Println("Successfully renamed created_by to creator_id")
	}
	
	// Check if roomspace_members table has firebase_uid instead of user_id
	var firebaseUidExists, userIdExists bool
	
	config.DB.Raw(`
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns 
			WHERE table_name = 'roomspace_members' 
			AND column_name = 'firebase_uid'
		)
	`).Row().Scan(&firebaseUidExists)
	
	config.DB.Raw(`
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns 
			WHERE table_name = 'roomspace_members' 
			AND column_name = 'user_id'
		)
	`).Row().Scan(&userIdExists)
	
	if firebaseUidExists && !userIdExists {
		fmt.Println("Renaming firebase_uid to user_id in roomspace_members table...")
		if err := config.DB.Exec("ALTER TABLE roomspace_members RENAME COLUMN firebase_uid TO user_id").Error; err != nil {
			return fmt.Errorf("failed to rename firebase_uid to user_id: %v", err)
		}
		fmt.Println("Successfully renamed firebase_uid to user_id")
	}
	
	fmt.Println("Manual schema fixes completed")
	return nil
}
// Payment Notification Operations

// CreatePaymentNotification creates a new payment notification
func (s *PostgresService) CreatePaymentNotification(notification *models.PaymentNotification) error {
	if err := config.DB.Create(notification).Error; err != nil {
		return fmt.Errorf("failed to create payment notification: %v", err)
	}
	return nil
}

// GetPaymentNotifications gets payment notifications for a user
func (s *PostgresService) GetPaymentNotifications(userUID string, limit, offset int) ([]models.PaymentNotification, error) {
	var notifications []models.PaymentNotification
	
	query := config.DB.Where("user_uid = ?", userUID).
		Order("timestamp DESC")
	
	if limit > 0 {
		query = query.Limit(limit)
	}
	
	if offset > 0 {
		query = query.Offset(offset)
	}
	
	if err := query.Find(&notifications).Error; err != nil {
		return nil, fmt.Errorf("failed to get payment notifications: %v", err)
	}
	
	return notifications, nil
}

// GetPaymentNotificationByID gets a payment notification by ID
func (s *PostgresService) GetPaymentNotificationByID(id uint) (*models.PaymentNotification, error) {
	var notification models.PaymentNotification
	
	if err := config.DB.First(&notification, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("payment notification not found")
		}
		return nil, fmt.Errorf("failed to get payment notification: %v", err)
	}
	
	return &notification, nil
}

// UpdatePaymentNotification updates a payment notification
func (s *PostgresService) UpdatePaymentNotification(id uint, updates map[string]interface{}) error {
	result := config.DB.Model(&models.PaymentNotification{}).
		Where("id = ?", id).
		Updates(updates)
	
	if result.Error != nil {
		return fmt.Errorf("failed to update payment notification: %v", result.Error)
	}
	
	if result.RowsAffected == 0 {
		return fmt.Errorf("payment notification not found")
	}
	
	return nil
}

// DeletePaymentNotification soft deletes a payment notification
func (s *PostgresService) DeletePaymentNotification(id uint) error {
	if err := config.DB.Delete(&models.PaymentNotification{}, id).Error; err != nil {
		return fmt.Errorf("failed to delete payment notification: %v", err)
	}
	
	return nil
}

// MarkPaymentNotificationAsProcessed marks a payment notification as processed
func (s *PostgresService) MarkPaymentNotificationAsProcessed(id uint, expenseID *uint) error {
	updates := map[string]interface{}{
		"is_processed": true,
	}
	
	if expenseID != nil {
		updates["expense_id"] = *expenseID
	}
	
	return s.UpdatePaymentNotification(id, updates)
}

// Analytics Operations

// CreateRecommendationFeedback creates a new recommendation feedback record
func (s *PostgresService) CreateRecommendationFeedback(feedback *models.RecommendationFeedback) error {
	result := config.DB.Create(feedback)
	return result.Error
}
