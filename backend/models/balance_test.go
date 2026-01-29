package models

import (
	"testing"
	"time"
)

func TestUserBalance_IsOwed(t *testing.T) {
	tests := []struct {
		name    string
		balance float64
		want    bool
	}{
		{"Positive balance", 100.50, true},
		{"Small positive balance", 0.02, true},
		{"Zero balance", 0.00, false},
		{"Negative balance", -50.00, false},
		{"Very small positive (threshold)", 0.01, false}, // At threshold
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ub := &UserBalance{Balance: tt.balance}
			if got := ub.IsOwed(); got != tt.want {
				t.Errorf("UserBalance.IsOwed() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestUserBalance_Owes(t *testing.T) {
	tests := []struct {
		name    string
		balance float64
		want    bool
	}{
		{"Negative balance", -100.50, true},
		{"Small negative balance", -0.02, true},
		{"Zero balance", 0.00, false},
		{"Positive balance", 50.00, false},
		{"Very small negative (threshold)", -0.01, false}, // At threshold
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ub := &UserBalance{Balance: tt.balance}
			if got := ub.Owes(); got != tt.want {
				t.Errorf("UserBalance.Owes() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestUserBalance_IsSettled(t *testing.T) {
	tests := []struct {
		name    string
		balance float64
		want    bool
	}{
		{"Zero balance", 0.00, true},
		{"Very small positive", 0.005, true},
		{"Very small negative", -0.005, true},
		{"At positive threshold", 0.01, true},
		{"At negative threshold", -0.01, true},
		{"Above threshold", 0.02, false},
		{"Below threshold", -0.02, false},
		{"Large positive", 100.00, false},
		{"Large negative", -100.00, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ub := &UserBalance{Balance: tt.balance}
			if got := ub.IsSettled(); got != tt.want {
				t.Errorf("UserBalance.IsSettled() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestUserBalance_NetContribution(t *testing.T) {
	tests := []struct {
		name      string
		totalPaid float64
		totalOwed float64
		want      float64
	}{
		{"Paid more than owed", 500.00, 200.00, 300.00},
		{"Paid less than owed", 100.00, 300.00, -200.00},
		{"Paid equals owed", 250.00, 250.00, 0.00},
		{"No payments", 0.00, 0.00, 0.00},
		{"Only paid", 100.00, 0.00, 100.00},
		{"Only owed", 0.00, 100.00, -100.00},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ub := &UserBalance{
				TotalPaid: tt.totalPaid,
				TotalOwed: tt.totalOwed,
			}
			if got := ub.NetContribution(); got != tt.want {
				t.Errorf("UserBalance.NetContribution() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestBalanceSummary_Creditors(t *testing.T) {
	bs := &BalanceSummary{
		UserBalances: map[string]float64{
			"user1": 100.00,
			"user2": -50.00,
			"user3": 0.00,
			"user4": 25.50,
			"user5": -0.01, // At threshold, should not be included
		},
	}

	creditors := bs.Creditors()

	if len(creditors) != 2 {
		t.Errorf("Expected 2 creditors, got %d", len(creditors))
	}

	if creditors["user1"] != 100.00 {
		t.Errorf("Expected user1 balance 100.00, got %v", creditors["user1"])
	}

	if creditors["user4"] != 25.50 {
		t.Errorf("Expected user4 balance 25.50, got %v", creditors["user4"])
	}

	if _, exists := creditors["user2"]; exists {
		t.Error("user2 should not be in creditors (negative balance)")
	}

	if _, exists := creditors["user3"]; exists {
		t.Error("user3 should not be in creditors (zero balance)")
	}
}

func TestBalanceSummary_Debtors(t *testing.T) {
	bs := &BalanceSummary{
		UserBalances: map[string]float64{
			"user1": 100.00,
			"user2": -50.00,
			"user3": 0.00,
			"user4": -25.50,
			"user5": 0.01, // At threshold, should not be included
		},
	}

	debtors := bs.Debtors()

	if len(debtors) != 2 {
		t.Errorf("Expected 2 debtors, got %d", len(debtors))
	}

	if debtors["user2"] != -50.00 {
		t.Errorf("Expected user2 balance -50.00, got %v", debtors["user2"])
	}

	if debtors["user4"] != -25.50 {
		t.Errorf("Expected user4 balance -25.50, got %v", debtors["user4"])
	}

	if _, exists := debtors["user1"]; exists {
		t.Error("user1 should not be in debtors (positive balance)")
	}

	if _, exists := debtors["user3"]; exists {
		t.Error("user3 should not be in debtors (zero balance)")
	}
}

func TestBalanceSummary_Balanced(t *testing.T) {
	bs := &BalanceSummary{
		UserBalances: map[string]float64{
			"user1": 100.00,
			"user2": -50.00,
			"user3": 0.00,
			"user4": 0.01,
			"user5": -0.01,
			"user6": 0.005,
		},
	}

	balanced := bs.Balanced()

	if len(balanced) != 4 {
		t.Errorf("Expected 4 balanced users, got %d", len(balanced))
	}

	expectedBalanced := []string{"user3", "user4", "user5", "user6"}
	for _, userID := range expectedBalanced {
		if _, exists := balanced[userID]; !exists {
			t.Errorf("%s should be in balanced users", userID)
		}
	}
}

func TestBalanceSummary_TotalOwed(t *testing.T) {
	bs := &BalanceSummary{
		UserBalances: map[string]float64{
			"user1": 100.00,
			"user2": -50.00,
			"user3": 25.50,
			"user4": -30.00,
		},
	}

	totalOwed := bs.TotalOwed()
	expected := 125.50 // 100.00 + 25.50

	if totalOwed != expected {
		t.Errorf("Expected total owed %v, got %v", expected, totalOwed)
	}
}

func TestBalanceSummary_AverageExpense(t *testing.T) {
	tests := []struct {
		name          string
		totalExpenses float64
		expenseCount  int
		want          float64
	}{
		{"Normal case", 1000.00, 10, 100.00},
		{"Single expense", 50.00, 1, 50.00},
		{"No expenses", 0.00, 0, 0.00},
		{"Decimal result", 100.00, 3, 33.333333333333336},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			bs := &BalanceSummary{
				TotalExpenses: tt.totalExpenses,
				ExpenseCount:  tt.expenseCount,
			}
			if got := bs.AverageExpense(); got != tt.want {
				t.Errorf("BalanceSummary.AverageExpense() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestUserBalance_TableName(t *testing.T) {
	ub := UserBalance{}
	if got := ub.TableName(); got != "user_balances" {
		t.Errorf("UserBalance.TableName() = %v, want %v", got, "user_balances")
	}
}

func TestSettlement_TableName(t *testing.T) {
	s := Settlement{}
	if got := s.TableName(); got != "settlements" {
		t.Errorf("Settlement.TableName() = %v, want %v", got, "settlements")
	}
}

func TestUserBalance_Relationships(t *testing.T) {
	// Test that the struct has the expected relationship fields
	ub := UserBalance{
		ID:           1,
		UserID:       "test_user",
		RoomspaceID:  "test_roomspace",
		Balance:      100.00,
		TotalPaid:    500.00,
		TotalOwed:    400.00,
		ExpenseCount: 5,
		LastUpdated:  time.Now(),
	}

	// Verify fields are accessible
	if ub.ID != 1 {
		t.Error("ID field not accessible")
	}
	if ub.UserID != "test_user" {
		t.Error("UserID field not accessible")
	}
	if ub.RoomspaceID != "test_roomspace" {
		t.Error("RoomspaceID field not accessible")
	}
}

func TestSettlement_Relationships(t *testing.T) {
	// Test that the struct has the expected relationship fields
	s := Settlement{
		ID:          1,
		RoomspaceID: "test_roomspace",
		FromUserID:  "user1",
		ToUserID:    "user2",
		Amount:      100.00,
		SettledAt:   time.Now(),
		Notes:       "Test settlement",
	}

	// Verify fields are accessible
	if s.ID != 1 {
		t.Error("ID field not accessible")
	}
	if s.FromUserID != "user1" {
		t.Error("FromUserID field not accessible")
	}
	if s.ToUserID != "user2" {
		t.Error("ToUserID field not accessible")
	}
	if s.Amount != 100.00 {
		t.Error("Amount field not accessible")
	}
}
