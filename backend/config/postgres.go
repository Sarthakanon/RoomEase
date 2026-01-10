package config

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// InitPostgreSQL initializes PostgreSQL connection using GORM with DATABASE_URL
func InitPostgreSQL(databaseURL string) error {
	// Use sslmode=disable for local development
	dsn := databaseURL + "?sslmode=disable&connect_timeout=10"
	
	log.Printf("Connecting to PostgreSQL with DSN: %s", dsn)
	
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("failed to connect to PostgreSQL: %w", err)
	}

	DB = db
	log.Println("✅ PostgreSQL connected successfully")
	return nil
}

// ClosePostgreSQL closes the PostgreSQL connection
func ClosePostgreSQL() error {
	if DB != nil {
		sqlDB, err := DB.DB()
		if err != nil {
			return err
		}
		return sqlDB.Close()
	}
	return nil
}
