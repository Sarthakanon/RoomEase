package main

import (
	"fmt"
	"log"
	"os"
	"roomease/backend/config"
	"roomease/backend/models"
	
	"github.com/joho/godotenv"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run cmd/debug_balance.go <roomspace_id>")
		os.Exit(1)
	}

	roomspaceID := os.Args[1]

	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Initialize database
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		// Build DATABASE_URL from individual components
		host := os.Getenv("POSTGRES_HOST")
		port := os.Getenv("POSTGRES_PORT")
		user := os.Getenv("POSTGRES_USER")
		password := os.Getenv("POSTGRES_PASSWORD")
		dbname := os.Getenv("POSTGRES_DATABASE")
		
		if host == "" || port == "" || user == "" || password == "" || dbname == "" {
			log.Fatal("DATABASE_URL or POSTGRES_* environment variables are required")
		}
		
		databaseURL = fmt.Sprintf("postgresql://%s:%s@%s:%s/%s", user, password, host, port, dbname)
	}

	if err := config.InitPostgreSQL(databaseURL); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer config.ClosePostgreSQL()

	fmt.Println("===================================")
	fmt.Println("Balance Debug Report")
	fmt.Printf("Roomspace ID: %s\n", roomspaceID)
	fmt.Println("===================================")
	fmt.Println()

	// 1. Get all members
	var members []models.RoomspaceMember
	config.DB.Preload("User").Where("roomspace_id = ? AND is_active = ?", roomspaceID, true).Find(&members)

	fmt.Println("1. USER BALANCES SUMMARY")
	fmt.Println("========================")

	userBalances := make(map[string]struct {
		Name      string
		Paid      float64
		Owed      float64
		Balance   float64
	})

	// Initialize balances
	for _, member := range members {
		userBalances[member.UserID] = struct {
			Name      string
			Paid      float64
			Owed      float64
			Balance   float64
		}{
			Name:    member.User.Name,
			Paid:    0,
			Owed:    0,
			Balance: 0,
		}
	}

	// 2. Get all expenses
	var expenses []models.Expense
	config.DB.Preload("Splits").Preload("Payer").Where("roomspace_id = ?", roomspaceID).Find(&expenses)

	fmt.Printf("Total Expenses: %d\n\n", len(expenses))

	// Calculate balances
	for _, expense := range expenses {
		// Payer gets credit
		if bal, ok := userBalances[expense.PaidBy]; ok {
			bal.Paid += expense.Amount
			userBalances[expense.PaidBy] = bal
		}

		// Each split member gets debited
		for _, split := range expense.Splits {
			if bal, ok := userBalances[split.UserUID]; ok {
				bal.Owed += split.Amount
				userBalances[split.UserUID] = bal
			}
		}
	}

	// Calculate final balances and print
	totalBalance := 0.0
	for userID, bal := range userBalances {
		balance := bal.Paid - bal.Owed
		fmt.Printf("User: %s\n", bal.Name)
		fmt.Printf("  User ID: %s\n", userID)
		fmt.Printf("  Total Paid: Rs. %.2f\n", bal.Paid)
		fmt.Printf("  Total Owed: Rs. %.2f\n", bal.Owed)
		fmt.Printf("  Balance: Rs. %.2f", balance)
		if balance > 0 {
			fmt.Printf(" (should GET BACK)\n")
		} else if balance < 0 {
			fmt.Printf(" (needs to PAY)\n")
		} else {
			fmt.Printf(" (settled)\n")
		}
		fmt.Println()
		totalBalance += balance
	}

	fmt.Println("2. BALANCE CHECK")
	fmt.Println("================")
	fmt.Printf("Sum of all balances: Rs. %.2f (should be ~0)\n", totalBalance)
	if totalBalance > 0.01 || totalBalance < -0.01 {
		fmt.Println("⚠️  WARNING: Balances don't sum to zero! Data inconsistency detected.")
	} else {
		fmt.Println("✓ Balances are correct")
	}
	fmt.Println()

	// 3. Check for duplicate splits
	fmt.Println("3. DUPLICATE SPLITS CHECK")
	fmt.Println("=========================")
	duplicateFound := false

	type SplitKey struct {
		ExpenseID uint
		UserUID   string
	}
	splitCounts := make(map[SplitKey]int)

	for _, expense := range expenses {
		for _, split := range expense.Splits {
			key := SplitKey{ExpenseID: expense.ID, UserUID: split.UserUID}
			splitCounts[key]++
		}
	}

	for key, count := range splitCounts {
		if count > 1 {
			duplicateFound = true
			// Find the expense
			for _, expense := range expenses {
				if expense.ID == key.ExpenseID {
					userName := "Unknown"
					for _, member := range members {
						if member.UserID == key.UserUID {
							userName = member.User.Name
							break
						}
					}
					fmt.Printf("⚠️  Expense #%d (%s): User %s has %d duplicate splits\n",
						expense.ID, expense.Title, userName, count)
					break
				}
			}
		}
	}

	if !duplicateFound {
		fmt.Println("✓ No duplicate splits found")
	}
	fmt.Println()

	// 4. Check split amount totals
	fmt.Println("4. SPLIT AMOUNT MISMATCH CHECK")
	fmt.Println("==============================")
	mismatchFound := false

	for _, expense := range expenses {
		totalSplits := 0.0
		for _, split := range expense.Splits {
			totalSplits += split.Amount
		}

		diff := expense.Amount - totalSplits
		if diff > 0.01 || diff < -0.01 {
			mismatchFound = true
			fmt.Printf("⚠️  Expense #%d (%s):\n", expense.ID, expense.Title)
			fmt.Printf("    Expense Amount: Rs. %.2f\n", expense.Amount)
			fmt.Printf("    Total Splits: Rs. %.2f\n", totalSplits)
			fmt.Printf("    Difference: Rs. %.2f\n", diff)
			fmt.Println()
		}
	}

	if !mismatchFound {
		fmt.Println("✓ All split amounts match expense amounts")
	}
	fmt.Println()

	// 5. Check for expenses without splits
	fmt.Println("5. EXPENSES WITHOUT SPLITS")
	fmt.Println("==========================")
	noSplitsFound := false

	for _, expense := range expenses {
		if len(expense.Splits) == 0 {
			noSplitsFound = true
			payerName := "Unknown"
			if expense.Payer != nil {
				payerName = expense.Payer.Name
			}
			fmt.Printf("⚠️  Expense #%d (%s): Rs. %.2f paid by %s - NO SPLITS!\n",
				expense.ID, expense.Title, expense.Amount, payerName)
		}
	}

	if !noSplitsFound {
		fmt.Println("✓ All expenses have splits")
	}
	fmt.Println()

	// 6. Recent expenses
	fmt.Println("6. RECENT EXPENSES (Last 10)")
	fmt.Println("============================")
	count := 0
	for i := len(expenses) - 1; i >= 0 && count < 10; i-- {
		expense := expenses[i]
		payerName := "Unknown"
		if expense.Payer != nil {
			payerName = expense.Payer.Name
		}

		totalSplits := 0.0
		for _, split := range expense.Splits {
			totalSplits += split.Amount
		}

		fmt.Printf("Expense #%d: %s\n", expense.ID, expense.Title)
		fmt.Printf("  Amount: Rs. %.2f | Paid by: %s\n", expense.Amount, payerName)
		fmt.Printf("  Splits: %d | Total: Rs. %.2f\n", len(expense.Splits), totalSplits)
		fmt.Printf("  Date: %s\n", expense.CreatedAt.Format("2006-01-02 15:04:05"))
		fmt.Println()
		count++
	}

	fmt.Println("===================================")
	fmt.Println("Debug report complete!")
	fmt.Println("===================================")
}
