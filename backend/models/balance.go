package models

import (
	"encoding/json"
	"errors"
	"time"
)

// Error types for balance operations
var (
	ErrSelfSettlement = errors.New("cannot settle with yourself")
	ErrInvalidAmount  = errors.New("settlement amount must be positive")
)

// UserBalance represents a user's balance in a specific roomspace
// Balance calculation:
//   - Positive balance = User is owed money (they paid more than their share)
//   - Negative balance = User owes money (they paid less than their share)
//   - Zero balance = User is settled up
type UserBalance struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	UserID       string    `gorm:"type:varchar(255);not null;index" json:"user_id"`                                                                    // Firebase UID
	RoomspaceID  string    `gorm:"type:uuid;not null;index;constraint:OnDelete:CASCADE" json:"roomspace_id"`                                          // UUID of roomspace
	Balance      float64   `gorm:"type:decimal(10,2);default:0.00" json:"balance"`                                                                    // Net balance (positive = owed, negative = owes)
	TotalPaid    float64   `gorm:"type:decimal(10,2);default:0.00" json:"total_paid"`                                                                 // Total amount user has paid
	TotalOwed    float64   `gorm:"type:decimal(10,2);default:0.00" json:"total_owed"`                                                                 // Total amount user owes
	ExpenseCount int       `gorm:"default:0" json:"expense_count"`                                                                                    // Number of expenses user is involved in
	LastUpdated  time.Time `gorm:"default:CURRENT_TIMESTAMP" json:"last_updated"`                                                                     // Last balance update timestamp
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`

	// Relationships
	Roomspace *Roomspace `gorm:"foreignKey:RoomspaceID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"roomspace,omitempty"`
	User      *User      `gorm:"foreignKey:UserID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"user,omitempty"`
}

// TableName specifies the table name for GORM
func (UserBalance) TableName() string {
	return "user_balances"
}

// IsOwed returns true if the user is owed money
func (ub *UserBalance) IsOwed() bool {
	return ub.Balance > 0.01
}

// Owes returns true if the user owes money
func (ub *UserBalance) Owes() bool {
	return ub.Balance < -0.01
}

// IsSettled returns true if the user's balance is near zero
func (ub *UserBalance) IsSettled() bool {
	return ub.Balance >= -0.01 && ub.Balance <= 0.01
}

// NetContribution returns the net contribution (paid - owed)
func (ub *UserBalance) NetContribution() float64 {
	return ub.TotalPaid - ub.TotalOwed
}

// Settlement represents a payment between two users to settle balances
type Settlement struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	RoomspaceID string    `gorm:"type:uuid;not null;index;constraint:OnDelete:CASCADE" json:"roomspace_id"` // UUID of roomspace
	FromUserID  string    `gorm:"type:varchar(255);not null;index" json:"from_user_id"`                     // User who paid (debtor)
	ToUserID    string    `gorm:"type:varchar(255);not null;index" json:"to_user_id"`                       // User who received payment (creditor)
	Amount      float64   `gorm:"type:decimal(10,2);not null;check:amount > 0" json:"amount"`              // Amount settled
	SettledAt   time.Time `gorm:"default:CURRENT_TIMESTAMP;index:idx_settlements_date" json:"settled_at"`  // Settlement timestamp
	Notes       string    `gorm:"type:text" json:"notes,omitempty"`                                         // Optional notes
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Relationships
	Roomspace *Roomspace `gorm:"foreignKey:RoomspaceID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"roomspace,omitempty"`
	FromUser  *User      `gorm:"foreignKey:FromUserID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"from_user,omitempty"`
	ToUser    *User      `gorm:"foreignKey:ToUserID;references:FirebaseUID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"to_user,omitempty"`
}

// TableName specifies the table name for GORM
func (Settlement) TableName() string {
	return "settlements"
}

// Description returns a human-readable description of the settlement
func (s *Settlement) Description() string {
	return "Settlement payment"
}

// MarshalJSON customizes JSON serialization to include user names
func (s Settlement) MarshalJSON() ([]byte, error) {
	type Alias Settlement
	
	fromUserName := "Unknown"
	toUserName := "Unknown"
	
	if s.FromUser != nil {
		fromUserName = s.FromUser.Name
	}
	if s.ToUser != nil {
		toUserName = s.ToUser.Name
	}
	
	return json.Marshal(&struct {
		*Alias
		FromUserName string `json:"from_user_name"`
		ToUserName   string `json:"to_user_name"`
	}{
		Alias:        (*Alias)(&s),
		FromUserName: fromUserName,
		ToUserName:   toUserName,
	})
}

// BalanceSummary represents the overall balance state for a roomspace
// This is typically calculated on-the-fly rather than stored
type BalanceSummary struct {
	RoomspaceID   string             `json:"roomspace_id"`
	TotalExpenses float64            `json:"total_expenses"`
	ExpenseCount  int                `json:"expense_count"`
	UserBalances  map[string]float64 `json:"user_balances"` // user_id -> balance
	Members       []interface{}      `json:"members"`       // Roomspace members with details
	LastUpdated   time.Time          `json:"last_updated"`
}

// Creditors returns users who are owed money (positive balance)
func (bs *BalanceSummary) Creditors() map[string]float64 {
	creditors := make(map[string]float64)
	for userID, balance := range bs.UserBalances {
		if balance > 0.01 {
			creditors[userID] = balance
		}
	}
	return creditors
}

// Debtors returns users who owe money (negative balance)
func (bs *BalanceSummary) Debtors() map[string]float64 {
	debtors := make(map[string]float64)
	for userID, balance := range bs.UserBalances {
		if balance < -0.01 {
			debtors[userID] = balance
		}
	}
	return debtors
}

// Balanced returns users with balanced accounts (near zero)
func (bs *BalanceSummary) Balanced() map[string]float64 {
	balanced := make(map[string]float64)
	for userID, balance := range bs.UserBalances {
		if balance >= -0.01 && balance <= 0.01 {
			balanced[userID] = balance
		}
	}
	return balanced
}

// TotalOwed returns the total amount owed across all creditors
func (bs *BalanceSummary) TotalOwed() float64 {
	total := 0.0
	for _, balance := range bs.Creditors() {
		total += balance
	}
	return total
}

// AverageExpense returns the average expense amount
func (bs *BalanceSummary) AverageExpense() float64 {
	if bs.ExpenseCount > 0 {
		return bs.TotalExpenses / float64(bs.ExpenseCount)
	}
	return 0.0
}

// SettlementSuggestion represents a suggested payment to settle balances
type SettlementSuggestion struct {
	FromUserID   string  `json:"from_user_id"`
	FromUserName string  `json:"from_user_name"`
	ToUserID     string  `json:"to_user_id"`
	ToUserName   string  `json:"to_user_name"`
	Amount       float64 `json:"amount"`
}

// Description returns a human-readable description of the settlement suggestion
func (ss *SettlementSuggestion) Description() string {
	return "Settlement suggestion"
}
