//go:build ignore

package main

import (
	"fmt"
	"log"
	"roomease/backend/config"
)

func main() {
	// Load configuration
	cfg := config.LoadConfig()

	// Initialize database connection
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer config.ClosePostgreSQL()

	log.Println("✅ Connected to database")

	// Get raw SQL database connection
	sqlDB, err := config.DB.DB()
	if err != nil {
		log.Fatalf("Failed to get database connection: %v", err)
	}

	// Find and display solo expenses
	log.Println("\n=== Finding Solo Expenses ===")

	query := `
		SELECT 
			e.id,
			e.title,
			e.amount,
			e.roomspace_id,
			e.paid_by,
			COUNT(es.id) as split_count
		FROM expenses e
		LEFT JOIN expense_splits es ON e.id = es.expense_id
		GROUP BY e.id, e.title, e.amount, e.roomspace_id, e.paid_by
		HAVING COUNT(es.id) = 1
		ORDER BY e.created_at DESC
	`

	rows, err := sqlDB.Query(query)
	if err != nil {
		log.Fatalf("Failed to query solo expenses: %v", err)
	}
	defer rows.Close()

	type SoloExpense struct {
		ID          int
		Title       string
		Amount      float64
		RoomspaceID string
		PaidBy      string
		SplitCount  int
	}

	var soloExpenses []SoloExpense
	for rows.Next() {
		var exp SoloExpense
		if err := rows.Scan(&exp.ID, &exp.Title, &exp.Amount, &exp.RoomspaceID, &exp.PaidBy, &exp.SplitCount); err != nil {
			log.Printf("Error scanning row: %v", err)
			continue
		}
		soloExpenses = append(soloExpenses, exp)
	}

	if len(soloExpenses) == 0 {
		log.Println("✅ No solo expenses found!")
		return
	}

	log.Printf("Found %d solo expenses (expenses with only 1 person in split)\n", len(soloExpenses))

	// Display them
	for i, exp := range soloExpenses {
		log.Printf("%d. ID: %d | %s | Rs. %.2f | Roomspace: %s | Paid by: %s",
			i+1, exp.ID, exp.Title, exp.Amount, exp.RoomspaceID, exp.PaidBy)
	}

	// Ask for confirmation
	fmt.Print("\n⚠️  Do you want to DELETE these solo expenses? (yes/no): ")
	var response string
	fmt.Scanln(&response)

	if response != "yes" {
		log.Println("❌ Cleanup cancelled")
		return
	}

	// Begin transaction
	tx, err := sqlDB.Begin()
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}
	defer tx.Rollback()

	// Delete splits first (foreign key constraint)
	deleteSplitsQuery := `
		DELETE FROM expense_splits
		WHERE expense_id IN (
			SELECT e.id
			FROM expenses e
			LEFT JOIN expense_splits es ON e.id = es.expense_id
			GROUP BY e.id
			HAVING COUNT(es.id) = 1
		)
	`

	result, err := tx.Exec(deleteSplitsQuery)
	if err != nil {
		log.Fatalf("Failed to delete splits: %v", err)
	}

	splitsDeleted, _ := result.RowsAffected()
	log.Printf("✅ Deleted %d expense splits", splitsDeleted)

	// Delete expenses
	deleteExpensesQuery := `
		DELETE FROM expenses
		WHERE id IN (
			SELECT e.id
			FROM expenses e
			LEFT JOIN expense_splits es ON e.id = es.expense_id
			GROUP BY e.id
			HAVING COUNT(es.id) = 0
		)
	`

	result, err = tx.Exec(deleteExpensesQuery)
	if err != nil {
		log.Fatalf("Failed to delete expenses: %v", err)
	}

	expensesDeleted, _ := result.RowsAffected()
	log.Printf("✅ Deleted %d solo expenses", expensesDeleted)

	// Commit transaction
	if err := tx.Commit(); err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}

	log.Println("\n✅ Cleanup completed successfully!")
	log.Println("💡 These expenses should have been added as personal expenses instead.")
	log.Println("💡 From now on, the app will prevent adding shared expenses with only 1 person.")
}
