package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	// Load environment variables
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	// Get database URL
	databaseURL := os.Getenv("POSTGRES_DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("POSTGRES_DATABASE_URL not set")
	}

	fmt.Printf("Testing connection with URL: %s\n", databaseURL)

	// Test connection
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}
	defer db.Close()

	// Test ping
	err = db.Ping()
	if err != nil {
		log.Fatalf("Error pinging database: %v", err)
	}

	fmt.Println("✅ Database connection successful!")

	// Test simple query
	var version string
	err = db.QueryRow("SELECT version()").Scan(&version)
	if err != nil {
		log.Fatalf("Error querying database: %v", err)
	}

	fmt.Printf("✅ Database version: %s\n", version)
}