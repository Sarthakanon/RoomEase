package config

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
)

// Config holds all configuration for the application
type Config struct {
	Port                   string
	FirebaseCredentialPath string
	AllowedOrigins         string
	SessionTimeout         string
	SessionSecret          string
	Environment            string
	PostgresDatabaseURL    string
	PostgresHost           string
	PostgresPort           string
	PostgresUser           string
	PostgresPassword       string
	PostgresDatabase       string
}

// AppConfig is the global configuration instance
var AppConfig *Config

// LoadConfig loads configuration from environment variables
func LoadConfig() *Config {
	// Load .env file if it exists
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Get individual PostgreSQL config values
	postgresHost := getEnv("POSTGRES_HOST", "localhost")
	postgresPort := getEnv("POSTGRES_PORT", "5432")
	postgresUser := getEnv("POSTGRES_USER", "postgres")
	postgresPassword := getEnv("POSTGRES_PASSWORD", "postgres")
	postgresDatabase := getEnv("POSTGRES_DATABASE", "roomease")

	// Build DATABASE_URL if not provided
	databaseURL := getEnv("POSTGRES_DATABASE_URL", "")
	if databaseURL == "" {
		databaseURL = fmt.Sprintf("postgresql://%s:%s@%s:%s/%s",
			postgresUser, postgresPassword, postgresHost, postgresPort, postgresDatabase)
	}

	config := &Config{
		Port:                   getEnv("PORT", "8080"),
		FirebaseCredentialPath: getEnv("FIREBASE_CREDENTIAL_PATH", "serviceAccount.json"),
		AllowedOrigins:         getEnv("ALLOWED_ORIGINS", "http://localhost:3000"),
		SessionTimeout:         getEnv("SESSION_TIMEOUT", "24h"),
		SessionSecret:          getEnv("SESSION_SECRET", "your-secret-key"),
		Environment:            getEnv("ENVIRONMENT", "development"),
		PostgresDatabaseURL:    databaseURL,
		PostgresHost:           postgresHost,
		PostgresPort:           postgresPort,
		PostgresUser:           postgresUser,
		PostgresPassword:       postgresPassword,
		PostgresDatabase:       postgresDatabase,
	}

	AppConfig = config
	log.Println("✅ Configuration loaded successfully")
	return config
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
