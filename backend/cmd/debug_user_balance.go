package main

import (
	"fmt"
	"log"
	"os"
	"roomease/backend/config"
	"roomease/backend/models"
)

func main() {
	if len(os.Args) < 3 {
		log.Fatal("Usage: go run cmd/debug_user_balance.go <roomspace_id> <user_id>")
	}

	roomspaceID := os.Args[1]
	userID := os.Args[2]

	// Load configuration
	cfg := config.LoadConfig()
	
	// Initialize database connection
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer config.ClosePostgreSQL()

	fmt.Println("=== USER BALANCE DEBUG ===")
	fmt.Printf("Roomspace ID: %s\n", roomspaceID)
	fmt.Printf("User ID: %s\n\n", userID)

	// Get expenses user paid
	var paidExpenses []models.Expense
	config.DB.Where("roomspace_id = ? AND paid_by = ?", roomspaceID, userID).Find(&paidExpenses)

	fmt.Println("EXPENSES USER PAID:")
	totalPaid := 0.0
	for _, exp := range paidExpenses {
		fmt.Printf("  - %s: Rs. %.2f\n", exp.Title, exp.Amount)
		totalPaid += exp.Amount
	}
	fmt.Printf("Total Paid: Rs. %.2f\n\n", totalPaid)

	// Get user's splits
	var splits []models.ExpenseSplit
	config.DB.
		Joins("JOIN expenses ON expenses.id = expense_splits.expense_id").
		Where("expenses.roomspace_id = ? AND expense_splits.user_uid = ?", roomspaceID, userID).
		Find(&splits)

	fmt.Println("USER'S EXPENSE SPLITS (what user owes):")
	totalOwed := 0.0
	for _, split := range splits {
		// Get expense details
		var expense models.Expense
		config.DB.First(&expense, split.ExpenseID)
		fmt.Printf("  - %s: Rs. %.2f (share of Rs. %.2f expense)\n", expense.Title, split.Amount, expense.Amount)
		totalOwed += split.Amount
	}
	fmt.Printf("Total Owed: Rs. %.2f\n\n", totalOwed)

	// Get settlements
	var settlementsFrom []models.Settlement
	config.DB.Where("roomspace_id = ? AND from_user_id = ?", roomspaceID, userID).Find(&settlementsFrom)

	fmt.Println("SETTLEMENTS FROM USER (user paid debts):")
	settlementsFromTotal := 0.0
	for _, s := range settlementsFrom {
		fmt.Printf("  - To %s: Rs. %.2f\n", s.ToUserID, s.Amount)
		settlementsFromTotal += s.Amount
	}
	fmt.Printf("Total Settlements From: Rs. %.2f\n\n", settlementsFromTotal)

	var settlementsTo []models.Settlement
	config.DB.Where("roomspace_id = ? AND to_user_id = ?", roomspaceID, userID).Find(&settlementsTo)

	fmt.Println("SETTLEMENTS TO USER (user received payments):")
	settlementsToTotal := 0.0
	for _, s := range settlementsTo {
		fmt.Printf("  - From %s: Rs. %.2f\n", s.FromUserID, s.Amount)
		settlementsToTotal += s.Amount
	}
	fmt.Printf("Total Settlements To: Rs. %.2f\n\n", settlementsToTotal)

	// Calculate balance
	balance := totalPaid - totalOwed + settlementsFromTotal - settlementsToTotal

	fmt.Println("=== BALANCE CALCULATION ===")
	fmt.Printf("Total Paid:           Rs. %.2f\n", totalPaid)
	fmt.Printf("Total Owed:           Rs. %.2f\n", totalOwed)
	fmt.Printf("Settlements From:     Rs. %.2f\n", settlementsFromTotal)
	fmt.Printf("Settlements To:       Rs. %.2f\n", settlementsToTotal)
	fmt.Printf("-----------------------------------\n")
	fmt.Printf("Balance:              Rs. %.2f\n", balance)
	
	if balance > 0 {
		fmt.Printf("\n✅ User should GET BACK Rs. %.2f\n", balance)
	} else if balance < 0 {
		fmt.Printf("\n❌ User needs to PAY Rs. %.2f\n", -balance)
	} else {
		fmt.Println("\n✅ User is settled up!")
	}
}
