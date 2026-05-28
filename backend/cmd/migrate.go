//go:build ignore

package main

import (
	"fmt"
	"log"
	"os"
	"roomease/backend/config"

	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: .env file not found: %v", err)
	}

	// Get database URL from environment
	databaseURL := os.Getenv("POSTGRES_DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("POSTGRES_DATABASE_URL environment variable is required")
	}

	// Initialize database connection
	if err := config.InitPostgreSQL(databaseURL); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Add ban fields to users table
	sql := `
		ALTER TABLE users 
		ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE,
		ADD COLUMN IF NOT EXISTS ban_reason TEXT,
		ADD COLUMN IF NOT EXISTS banned_at TIMESTAMP;

		-- Create index for banned users
		CREATE INDEX IF NOT EXISTS idx_users_is_banned ON users(is_banned);

		-- Update existing users to not be banned
		UPDATE users SET is_banned = FALSE WHERE is_banned IS NULL;
	`

	result := config.DB.Exec(sql)
	if result.Error != nil {
		log.Fatalf("Migration failed: %v", result.Error)
	}

	fmt.Println("✅ Migration completed successfully!")
	fmt.Printf("Rows affected: %d\n", result.RowsAffected)
}
