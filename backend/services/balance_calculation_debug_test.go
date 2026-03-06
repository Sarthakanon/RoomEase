package services

import (
	"fmt"
	"roomease/backend/models"
	"testing"
	"time"
)

// TestBalanceCalculation_SimpleScenario tests the exact scenario the user described
func TestBalanceCalculation_SimpleScenario(t *testing.T) {
	t.Run("User A pays Rs.266 split equally with User B", func(t *testing.T) {
		// Setup: User A pays Rs.266, split equally between A and B
		userA := "user_a_uid"
		userB := "user_b_uid"
		
		// Create expense
		expense := models.Expense{
			ID:          1,
			RoomspaceID: "test_roomspace",
			Title:       "Test Expense",
			Amount:      266.0,
			PaidBy:      userA, // User A paid
			SplitType:   models.SplitTypeEqual,
			CreatedAt:   time.Now(),
		}
		
		// Create splits - split equally means BOTH users get a split
		expense.Splits = []models.ExpenseSplit{
			{
				ExpenseID: 1,
				UserUID:   userA, // User A owes Rs.133
				Amount:    133.0,
			},
			{
				ExpenseID: 1,
				UserUID:   userB, // User B owes Rs.133
				Amount:    133.0,
			},
		}
		
		// Simulate balance calculation
		userBalances := make(map[string]float64)
		userBalances[userA] = 0.0
		userBalances[userB] = 0.0
		
		// Payer gets credit for the full amount
		userBalances[expense.PaidBy] += expense.Amount
		fmt.Printf("After payment: User A = %.2f, User B = %.2f\n", userBalances[userA], userBalances[userB])
		
		// Each split member gets debited for their share
		for _, split := range expense.Splits {
			userBalances[split.UserUID] -= split.Amount
		}
		
		fmt.Printf("After splits: User A = %.2f, User B = %.2f\n", userBalances[userA], userBalances[userB])
		
		// Expected results:
		// User A: paid 266, owes 133 → balance = +133 (is owed)
		// User B: paid 0, owes 133 → balance = -133 (owes)
		
		expectedA := 133.0
		expectedB := -133.0
		
		if userBalances[userA] != expectedA {
			t.Errorf("User A balance incorrect: got %.2f, want %.2f", userBalances[userA], expectedA)
		}
		
		if userBalances[userB] != expectedB {
			t.Errorf("User B balance incorrect: got %.2f, want %.2f", userBalances[userB], expectedB)
		}
		
		// Verify sum is zero
		sum := userBalances[userA] + userBalances[userB]
		if sum != 0.0 {
			t.Errorf("Balance sum should be zero, got %.2f", sum)
		}
		
		t.Logf("✓ User A balance: +Rs.%.2f (is owed)", userBalances[userA])
		t.Logf("✓ User B balance: Rs.%.2f (owes)", userBalances[userB])
		t.Logf("✓ Sum of balances: %.2f (correct!)", sum)
	})
	
	t.Run("User A pays Rs.266 split with B, but B is NOT in splits", func(t *testing.T) {
		// This tests if the payer is NOT included in splits
		userA := "user_a_uid"
		userB := "user_b_uid"
		
		expense := models.Expense{
			ID:          1,
			RoomspaceID: "test_roomspace",
			Amount:      266.0,
			PaidBy:      userA,
		}
		
		// Only User B gets a split (payer not included)
		expense.Splits = []models.ExpenseSplit{
			{
				UserUID: userB,
				Amount:  266.0, // B owes the full amount
			},
		}
		
		userBalances := make(map[string]float64)
		userBalances[userA] = 0.0
		userBalances[userB] = 0.0
		
		userBalances[expense.PaidBy] += expense.Amount
		for _, split := range expense.Splits {
			userBalances[split.UserUID] -= split.Amount
		}
		
		// Expected: A = +266, B = -266
		expectedA := 266.0
		expectedB := -266.0
		
		if userBalances[userA] != expectedA {
			t.Errorf("User A balance incorrect: got %.2f, want %.2f", userBalances[userA], expectedA)
		}
		
		if userBalances[userB] != expectedB {
			t.Errorf("User B balance incorrect: got %.2f, want %.2f", userBalances[userB], expectedB)
		}
		
		sum := userBalances[userA] + userBalances[userB]
		if sum != 0.0 {
			t.Errorf("Balance sum should be zero, got %.2f", sum)
		}
		
		t.Logf("✓ User A balance: +Rs.%.2f", userBalances[userA])
		t.Logf("✓ User B balance: Rs.%.2f", userBalances[userB])
	})
}
