package main

import (
	"log"
	"roomease/backend/config"
	"roomease/backend/models"
	"roomease/backend/services"
)

func main() {
	log.Println("🔧 Fixing settlements table...")

	// Load configuration
	cfg := config.LoadConfig()

	// Initialize PostgreSQL
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Fatalf("Failed to initialize PostgreSQL: %v", err)
	}
	defer config.ClosePostgreSQL()

	// Create PostgreSQL service
	dbService := services.NewPostgresService()

	// Run specific migration for settlements table
	log.Println("Creating settlements table...")
	if err := config.DB.AutoMigrate(&models.Settlement{}); err != nil {
		log.Fatalf("Failed to create settlements table: %v", err)
	}

	log.Println("✅ Settlements table created successfully")

	// Also ensure user_balances table exists
	log.Println("Creating user_balances table...")
	if err := config.DB.AutoMigrate(&models.UserBalance{}); err != nil {
		log.Fatalf("Failed to create user_balances table: %v", err)
	}

	log.Println("✅ User balances table created successfully")

	// Run full migration to ensure everything is up to date
	log.Println("Running full migration...")
	if err := dbService.AutoMigrate(); err != nil {
		log.Fatalf("Failed to run full migration: %v", err)
	}

	log.Println("✅ All migrations completed successfully")
}