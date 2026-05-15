package services

import (
	"errors"
	"fmt"
	"roomease/backend/config"
	"roomease/backend/models"
	"time"

	"gorm.io/gorm"
)

// BalanceService handles balance calculation and management operations
type BalanceService struct{}

// NewBalanceService creates a new balance service
func NewBalanceService() *BalanceService {
	return &BalanceService{}
}

// CalculateRoomspaceBalances calculates all user balances for a roomspace
// Returns a BalanceSummary with aggregated balance information
func (s *BalanceService) CalculateRoomspaceBalances(roomspaceID string) (*models.BalanceSummary, error) {
	fmt.Printf("🔍 Starting balance calculation for roomspace: %s\n", roomspaceID)

	// Get all expenses for the roomspace
	var expenses []models.Expense
	result := config.DB.
		Preload("Splits").
		Where("roomspace_id = ?", roomspaceID).
		Find(&expenses)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch expenses: %w", result.Error)
	}

	fmt.Printf("📋 Found %d expenses for roomspace %s\n", len(expenses), roomspaceID)
	for i, expense := range expenses {
		fmt.Printf("  Expense %d: ID=%s, Amount=%.2f, PaidBy=%s, Splits=%d\n",
			i+1, expense.ID, expense.Amount, expense.PaidBy, len(expense.Splits))
	}

	// Get roomspace members
	var members []models.RoomspaceMember
	result = config.DB.
		Preload("User").
		Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).
		Find(&members)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch members: %w", result.Error)
	}

	fmt.Printf("👥 Found %d active members for roomspace %s\n", len(members), roomspaceID)
	for i, member := range members {
		fmt.Printf("  Member %d: UserID=%s, Name=%s\n",
			i+1, member.UserID, member.User.Name)
	}

	// Initialize balance map for all members
	userBalances := make(map[string]float64)
	for _, member := range members {
		userBalances[member.UserID] = 0.0
	}

	fmt.Printf("💰 Initialized balances: %+v\n", userBalances)

	// Calculate balances from expenses
	totalExpenses := 0.0
	for i, expense := range expenses {
		fmt.Printf("🧮 Processing expense %d: ID=%s, Amount=%.2f, PaidBy=%s\n",
			i+1, expense.ID, expense.Amount, expense.PaidBy)

		totalExpenses += expense.Amount

		// Payer gets credit for the full amount
		if _, exists := userBalances[expense.PaidBy]; exists {
			userBalances[expense.PaidBy] += expense.Amount
			fmt.Printf("  ✅ Added %.2f to payer %s, new balance: %.2f\n",
				expense.Amount, expense.PaidBy, userBalances[expense.PaidBy])
		} else {
			fmt.Printf("  ⚠️  Payer %s not found in members list\n", expense.PaidBy)
		}

		// Each split member gets debited for their share
		fmt.Printf("  📊 Processing %d splits:\n", len(expense.Splits))
		for j, split := range expense.Splits {
			fmt.Printf("    Split %d: UserUID=%s, Amount=%.2f\n",
				j+1, split.UserUID, split.Amount)

			if _, exists := userBalances[split.UserUID]; exists {
				userBalances[split.UserUID] -= split.Amount
				fmt.Printf("    ✅ Subtracted %.2f from %s, new balance: %.2f\n",
					split.Amount, split.UserUID, userBalances[split.UserUID])
			} else {
				fmt.Printf("    ⚠️  Split user %s not found in members list\n", split.UserUID)
			}
		}

		fmt.Printf("  💰 Balances after expense %d: %+v\n", i+1, userBalances)
	}

	fmt.Printf("🏁 Final balances before settlements: %+v\n", userBalances)

	// Apply settlements (payments) to balances
	var settlements []models.Settlement
	result = config.DB.
		Where("roomspace_id = ?", roomspaceID).
		Find(&settlements)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch settlements: %w", result.Error)
	}

	for _, settlement := range settlements {
		// When FromUser pays ToUser:
		// - FromUser's balance increases (they paid their debt)
		// - ToUser's balance decreases (they received what they were owed)
		userBalances[settlement.FromUserID] += settlement.Amount
		userBalances[settlement.ToUserID] -= settlement.Amount
	}

	// Convert members to interface slice for JSON with their balances
	memberInterfaces := make([]interface{}, len(members))
	for i, member := range members {
		memberInterfaces[i] = map[string]interface{}{
			"user_id":      member.UserID,
			"user_name":    member.User.Name,
			"name":         member.User.Name, // Add 'name' field for frontend compatibility
			"role":         member.Role,
			"balance":      userBalances[member.UserID], // Include the calculated balance
			"qr_image_url": member.User.QRImageURL,
		}
	}

	summary := &models.BalanceSummary{
		RoomspaceID:   roomspaceID,
		TotalExpenses: totalExpenses,
		ExpenseCount:  len(expenses),
		UserBalances:  userBalances,
		Members:       memberInterfaces,
		LastUpdated:   time.Now(),
	}

	return summary, nil
}

// GetUserBalance gets a specific user's balance in a roomspace
// Returns detailed balance information including total paid and owed
func (s *BalanceService) GetUserBalance(roomspaceID, userID string) (*models.UserBalance, error) {
	// Check if user is a member of the roomspace
	var member models.RoomspaceMember
	result := config.DB.
		Where("roomspace_id = ? AND user_id = ? AND is_active = ?", roomspaceID, userID, true).
		First(&member)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, errors.New("user is not a member of this roomspace")
		}
		return nil, fmt.Errorf("failed to verify membership: %w", result.Error)
	}

	// Get all expenses where user is the payer
	var paidExpenses []models.Expense
	result = config.DB.
		Where("roomspace_id = ? AND paid_by = ?", roomspaceID, userID).
		Find(&paidExpenses)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch paid expenses: %w", result.Error)
	}

	// Calculate total paid
	totalPaid := 0.0
	for _, expense := range paidExpenses {
		totalPaid += expense.Amount
	}

	// Get all expense splits for this user
	var splits []models.ExpenseSplit
	result = config.DB.
		Joins("JOIN expenses ON expenses.id = expense_splits.expense_id").
		Where("expenses.roomspace_id = ? AND expense_splits.user_uid = ?", roomspaceID, userID).
		Find(&splits)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch expense splits: %w", result.Error)
	}

	// Calculate total owed
	totalOwed := 0.0
	expenseCount := len(splits)
	for _, split := range splits {
		totalOwed += split.Amount
	}

	// Calculate net balance from expenses
	balance := totalPaid - totalOwed

	// Apply settlements (payments) to balance
	// Get settlements where user paid someone
	var settlementsFrom []models.Settlement
	result = config.DB.
		Where("roomspace_id = ? AND from_user_id = ?", roomspaceID, userID).
		Find(&settlementsFrom)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch settlements from user: %w", result.Error)
	}

	for _, settlement := range settlementsFrom {
		balance += settlement.Amount // User paid debt, balance increases
	}

	// Get settlements where user received payment
	var settlementsTo []models.Settlement
	result = config.DB.
		Where("roomspace_id = ? AND to_user_id = ?", roomspaceID, userID).
		Find(&settlementsTo)

	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch settlements to user: %w", result.Error)
	}

	for _, settlement := range settlementsTo {
		balance -= settlement.Amount // User received payment, balance decreases
	}

	userBalance := &models.UserBalance{
		UserID:       userID,
		RoomspaceID:  roomspaceID,
		Balance:      balance,
		TotalPaid:    totalPaid,
		TotalOwed:    totalOwed,
		ExpenseCount: expenseCount,
		LastUpdated:  time.Now(),
	}

	return userBalance, nil
}

// UpdateBalanceCache updates the cached balances in the user_balances table
// This should be called after expense operations (create, update, delete)
func (s *BalanceService) UpdateBalanceCache(roomspaceID string) error {
	// Get all active members
	var members []models.RoomspaceMember
	result := config.DB.
		Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).
		Find(&members)

	if result.Error != nil {
		return fmt.Errorf("failed to fetch members: %w", result.Error)
	}

	// Calculate and update balance for each member
	for _, member := range members {
		balance, err := s.GetUserBalance(roomspaceID, member.UserID)
		if err != nil {
			return fmt.Errorf("failed to calculate balance for user %s: %w", member.UserID, err)
		}

		// Upsert balance record
		err = s.upsertBalanceRecord(balance)
		if err != nil {
			return fmt.Errorf("failed to update balance cache for user %s: %w", member.UserID, err)
		}
	}

	return nil
}

// upsertBalanceRecord inserts or updates a balance record
func (s *BalanceService) upsertBalanceRecord(balance *models.UserBalance) error {
	// Check if record exists
	var existing models.UserBalance
	result := config.DB.
		Where("user_id = ? AND roomspace_id = ?", balance.UserID, balance.RoomspaceID).
		First(&existing)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			// Create new record
			return config.DB.Create(balance).Error
		}
		return result.Error
	}

	// Update existing record
	existing.Balance = balance.Balance
	existing.TotalPaid = balance.TotalPaid
	existing.TotalOwed = balance.TotalOwed
	existing.ExpenseCount = balance.ExpenseCount
	existing.LastUpdated = time.Now()

	return config.DB.Save(&existing).Error
}

// GetCachedBalance retrieves a cached balance from the database
// Falls back to real-time calculation if cache is missing or stale
func (s *BalanceService) GetCachedBalance(roomspaceID, userID string) (*models.UserBalance, error) {
	var balance models.UserBalance
	result := config.DB.
		Where("user_id = ? AND roomspace_id = ?", userID, roomspaceID).
		First(&balance)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			// Cache miss - calculate and cache
			calculated, err := s.GetUserBalance(roomspaceID, userID)
			if err != nil {
				return nil, err
			}

			// Cache the result
			if err := s.upsertBalanceRecord(calculated); err != nil {
				// Log error but return calculated balance anyway
				fmt.Printf("Warning: failed to cache balance: %v\n", err)
			}

			return calculated, nil
		}
		return nil, result.Error
	}

	// Check if cache is stale (older than 1 hour)
	if time.Since(balance.LastUpdated) > time.Hour {
		// Recalculate and update cache
		calculated, err := s.GetUserBalance(roomspaceID, userID)
		if err != nil {
			// Return stale cache on error
			return &balance, nil
		}

		if err := s.upsertBalanceRecord(calculated); err != nil {
			fmt.Printf("Warning: failed to update cache: %v\n", err)
		}

		return calculated, nil
	}

	return &balance, nil
}

// CreateSettlement records a settlement between two users
// Updates both users' balances accordingly
func (s *BalanceService) CreateSettlement(settlement *models.Settlement) error {
	// Validate settlement
	if settlement.FromUserID == settlement.ToUserID {
		return errors.New("cannot settle with yourself")
	}

	if settlement.Amount <= 0 {
		return errors.New("settlement amount must be positive")
	}

	// Verify both users are members of the roomspace
	var fromMember, toMember models.RoomspaceMember
	result := config.DB.
		Where("roomspace_id = ? AND user_id = ? AND is_active = ?",
			settlement.RoomspaceID, settlement.FromUserID, true).
		First(&fromMember)

	if result.Error != nil {
		return errors.New("from_user is not a member of this roomspace")
	}

	result = config.DB.
		Where("roomspace_id = ? AND user_id = ? AND is_active = ?",
			settlement.RoomspaceID, settlement.ToUserID, true).
		First(&toMember)

	if result.Error != nil {
		return errors.New("to_user is not a member of this roomspace")
	}

	// Create settlement record
	if err := config.DB.Create(settlement).Error; err != nil {
		return fmt.Errorf("failed to create settlement: %w", err)
	}

	// Update balance cache
	if err := s.UpdateBalanceCache(settlement.RoomspaceID); err != nil {
		return fmt.Errorf("failed to update balance cache: %w", err)
	}

	return nil
}

// GetSettlementHistory retrieves settlement history for a roomspace
func (s *BalanceService) GetSettlementHistory(roomspaceID string, limit, offset int) ([]models.Settlement, error) {
	var settlements []models.Settlement
	query := config.DB.
		Preload("FromUser").
		Preload("ToUser").
		Where("roomspace_id = ?", roomspaceID).
		Order("settled_at DESC")

	if limit > 0 {
		query = query.Limit(limit)
	}
	if offset > 0 {
		query = query.Offset(offset)
	}

	result := query.Find(&settlements)
	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch settlement history: %w", result.Error)
	}

	return settlements, nil
}

// GenerateSettlementSuggestions generates optimal settlement suggestions
// Uses a greedy algorithm to minimize the number of transactions
func (s *BalanceService) GenerateSettlementSuggestions(roomspaceID string) ([]models.SettlementSuggestion, error) {
	summary, err := s.CalculateRoomspaceBalances(roomspaceID)
	if err != nil {
		return nil, err
	}

	creditors := summary.Creditors()
	debtors := summary.Debtors()

	var suggestions []models.SettlementSuggestion

	// Convert maps to slices for easier manipulation
	type userBalance struct {
		userID  string
		balance float64
	}

	var creditorList []userBalance
	for userID, balance := range creditors {
		creditorList = append(creditorList, userBalance{userID, balance})
	}

	var debtorList []userBalance
	for userID, balance := range debtors {
		debtorList = append(debtorList, userBalance{userID, -balance}) // Make positive
	}

	// Greedy algorithm: match largest creditor with largest debtor
	for len(creditorList) > 0 && len(debtorList) > 0 {
		creditor := creditorList[0]
		debtor := debtorList[0]

		// Determine settlement amount
		amount := creditor.balance
		if debtor.balance < amount {
			amount = debtor.balance
		}

		// Get user names
		var fromUser, toUser models.User
		config.DB.Where("firebase_uid = ?", debtor.userID).First(&fromUser)
		config.DB.Where("firebase_uid = ?", creditor.userID).First(&toUser)

		suggestions = append(suggestions, models.SettlementSuggestion{
			FromUserID:   debtor.userID,
			FromUserName: fromUser.Name,
			ToUserID:     creditor.userID,
			ToUserName:   toUser.Name,
			Amount:       amount,
		})

		// Update balances
		creditorList[0].balance -= amount
		debtorList[0].balance -= amount

		// Remove settled users
		if creditorList[0].balance < 0.01 {
			creditorList = creditorList[1:]
		}
		if debtorList[0].balance < 0.01 {
			debtorList = debtorList[1:]
		}
	}

	return suggestions, nil
}
