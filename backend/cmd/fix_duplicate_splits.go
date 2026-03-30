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
		fmt.Println("Usage: go run cmd/fix_duplicate_splits.go <roomspace_id>")
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
	fmt.Println("Fix Duplicate Splits")
	fmt.Printf("Roomspace ID: %s\n", roomspaceID)
	fmt.Println("===================================")
	fmt.Println()

	// Get all expenses for this roomspace
	var expenses []models.Expense
	config.DB.Preload("Splits").Where("roomspace_id = ?", roomspaceID).Find(&expenses)

	fmt.Printf("Found %d expenses\n", len(expenses))
	fmt.Println()

	totalDuplicatesRemoved := 0

	// For each expense, remove duplicate splits
	for _, expense := range expenses {
		// Group splits by user_uid
		splitsByUser := make(map[string][]models.ExpenseSplit)
		for _, split := range expense.Splits {
			splitsByUser[split.UserUID] = append(splitsByUser[split.UserUID], split)
		}

		// For each user, keep only the first split and delete the rest
		for userUID, splits := range splitsByUser {
			if len(splits) > 1 {
				fmt.Printf("Expense #%d (%s): User %s has %d splits, keeping 1, deleting %d\n",
					expense.ID, expense.Title, userUID, len(splits), len(splits)-1)

				// Keep the first split, delete the rest
				for i := 1; i < len(splits); i++ {
					if err := config.DB.Delete(&splits[i]).Error; err != nil {
						log.Printf("Error deleting split ID %d: %v", splits[i].ID, err)
					} else {
						totalDuplicatesRemoved++
					}
				}
			}
		}
	}

	fmt.Println()
	fmt.Printf("✅ Removed %d duplicate splits\n", totalDuplicatesRemoved)
	fmt.Println()

	// Verify the fix
	fmt.Println("Verifying fix...")
	config.DB.Preload("Splits").Where("roomspace_id = ?", roomspaceID).Find(&expenses)

	allGood := true
	for _, expense := range expenses {
		totalSplits := 0.0
		uniqueUsers := make(map[string]bool)

		for _, split := range expense.Splits {
			totalSplits += split.Amount
			uniqueUsers[split.UserUID] = true
		}

		diff := expense.Amount - totalSplits
		if diff > 0.01 || diff < -0.01 {
			fmt.Printf("⚠️  Expense #%d still has mismatch: %.2f vs %.2f\n",
				expense.ID, expense.Amount, totalSplits)
			allGood = false
		}

		if len(expense.Splits) != len(uniqueUsers) {
			fmt.Printf("⚠️  Expense #%d still has duplicates\n", expense.ID)
			allGood = false
		}
	}

	if allGood {
		fmt.Println("✅ All expenses are now correct!")
	} else {
		fmt.Println("⚠️  Some issues remain, please check manually")
	}

	fmt.Println()
	fmt.Println("===================================")
	fmt.Println("Fix complete!")
	fmt.Println("Please refresh your app to see updated balances")
	fmt.Println("===================================")
}
