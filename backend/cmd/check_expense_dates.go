package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"roomease/backend/config"
	"roomease/backend/models"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run cmd/check_expense_dates.go <roomspace_id>")
	}

	roomspaceID := os.Args[1]

	// Load config
	if err := config.LoadConfig(); err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Connect to database
	if err := config.InitPostgres(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	var expenses []models.Expense
	result := config.DB.Where("roomspace_id = ?", roomspaceID).
		Order("created_at DESC").
		Find(&expenses)

	if result.Error != nil {
		log.Fatalf("Failed to fetch expenses: %v", result.Error)
	}

	fmt.Println("=== ALL EXPENSES BY DATE ===")
	fmt.Printf("Roomspace ID: %s\n\n", roomspaceID)

	for _, expense := range expenses {
		month := expense.CreatedAt.Format("2006-01")
		fmt.Printf("%s | %-20s | Rs. %8.2f | Paid by: %s\n", 
			month, expense.Title, expense.Amount, expense.PaidBy)
	}

	fmt.Println("\n=== EXPENSES BY MONTH ===")
	monthTotals := make(map[string]float64)
	for _, expense := range expenses {
		month := expense.CreatedAt.Format("2006-01")
		monthTotals[month] += expense.Amount
	}

	for month, total := range monthTotals {
		fmt.Printf("%s: Rs. %.2f\n", month, total)
	}
}
