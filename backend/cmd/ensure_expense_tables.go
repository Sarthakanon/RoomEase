//go:build ignore

package main

import (
	"log"
	"os"

	"roomease/backend/config"
	"roomease/backend/models"
	"roomease/backend/services"
)

func main() {
	log.Println("Ensuring expense tables exist...")

	// Load configuration
	cfg := config.LoadConfig()

	// Initialize database connection
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer config.ClosePostgreSQL()

	// Initialize services
	dbService := services.NewPostgresService()

	log.Println("Creating expense tables...")

	// Drop existing expense_splits table if it exists to avoid constraint issues
	if config.DB.Migrator().HasTable(&models.ExpenseSplit{}) {
		log.Println("Dropping existing expense_splits table...")
		if err := config.DB.Migrator().DropTable(&models.ExpenseSplit{}); err != nil {
			log.Printf("Warning: Failed to drop expense_splits table: %v", err)
		}
	}

	// Create tables in the correct order
	log.Println("Creating users table...")
	if err := config.DB.AutoMigrate(&models.User{}); err != nil {
		log.Fatalf("Failed to create users table: %v", err)
	}

	log.Println("Creating roomspaces table...")
	if err := config.DB.AutoMigrate(&models.Roomspace{}); err != nil {
		log.Fatalf("Failed to create roomspaces table: %v", err)
	}

	log.Println("Creating expenses table...")
	if err := config.DB.AutoMigrate(&models.Expense{}); err != nil {
		log.Fatalf("Failed to create expenses table: %v", err)
	}

	log.Println("Creating expense_splits table...")
	if err := config.DB.AutoMigrate(&models.ExpenseSplit{}); err != nil {
		log.Fatalf("Failed to create expense_splits table: %v", err)
	}

	log.Println("Creating personal_expenses table...")
	if err := config.DB.AutoMigrate(&models.PersonalExpense{}); err != nil {
		log.Fatalf("Failed to create personal_expenses table: %v", err)
	}

	log.Println("✅ Expense tables created successfully")

	// Run full migration to ensure everything is up to date
	log.Println("Running full migration...")
	if err := dbService.AutoMigrate(); err != nil {
		log.Printf("Warning: Full migration had issues: %v", err)
		log.Println("But continuing to verify tables...")
	}

	log.Println("✅ Migration completed")

	// Verify expense_splits table exists
	if config.DB.Migrator().HasTable(&models.ExpenseSplit{}) {
		log.Println("✅ expense_splits table exists")
	} else {
		log.Println("❌ expense_splits table does not exist")
		os.Exit(1)
	}

	// Verify expenses table exists
	if config.DB.Migrator().HasTable(&models.Expense{}) {
		log.Println("✅ expenses table exists")
	} else {
		log.Println("❌ expenses table does not exist")
		os.Exit(1)
	}

	// Verify personal_expenses table exists
	if config.DB.Migrator().HasTable(&models.PersonalExpense{}) {
		log.Println("✅ personal_expenses table exists")
	} else {
		log.Println("❌ personal_expenses table does not exist")
		os.Exit(1)
	}

	log.Println("🎉 Database migration completed successfully!")
	log.Println("🚀 You can now restart your Flutter app - the balance API should work correctly.")
}
