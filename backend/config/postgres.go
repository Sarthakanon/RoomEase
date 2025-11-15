package config

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// InitPostgreSQL initializes PostgreSQL connection using GORM
func InitPostgreSQL(host, port, user, password, dbname string) error {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

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
