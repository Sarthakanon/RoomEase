package main

import (
	"fmt"
	"roomease/backend/models"
)

// Simple test to verify balance calculation logic
func main() {
	fmt.Println("🧪 Testing Balance Calculation Logic")
	fmt.Println("===================================")

	// Mock data
	userA := "user_a_123"
	userB := "user_b_456"

	// Create a mock expense: User A pays 100, split equally between A and B
	expense := models.Expense{
		RoomspaceID: "room_123",
		Title:       "Test Expense",
		Amount:      100.0,
		PaidBy:      userA,
		Splits: []models.ExpenseSplit{
			{UserUID: userA, Amount: 50.0},
			{UserUID: userB, Amount: 50.0},
		},
	}

	fmt.Printf("📋 Expense: %s pays %.2f, split between %s and %s\n", 
		expense.PaidBy, expense.Amount, userA, userB)

	// Calculate balances manually
	userBalances := make(map[string]float64)
	userBalances[userA] = 0.0
	userBalances[userB] = 0.0

	// Payer gets credit for the full amount
	userBalances[expense.PaidBy] += expense.Amount
	fmt.Printf("After payment: %s = %.2f, %s = %.2f\n", 
		userA, userBalances[userA], userB, userBalances[userB])

	// Each split member gets debited for their share
	for _, split := range expense.Splits {
		userBalances[split.UserUID] -= split.Amount
	}

	fmt.Printf("After splits: %s = %.2f, %s = %.2f\n", 
		userA, userBalances[userA], userB, userBalances[userB])

	// Calculate you_owe and you_are_owed for each user
	for userID, balance := range userBalances {
		youOwe := 0.0
		youAreOwed := 0.0

		if balance < 0 {
			youOwe = -balance
		} else if balance > 0 {
			youAreOwed = balance
		}

		fmt.Printf("User %s: Balance=%.2f, YouOwe=%.2f, YouAreOwed=%.2f\n", 
			userID, balance, youOwe, youAreOwed)
	}

	fmt.Println("\n✅ Balance calculation test completed")
}