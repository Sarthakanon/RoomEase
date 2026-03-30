package config

import (
	"os"
)

// MLConfig holds configuration for the ML API service
type MLConfig struct {
	APIURL string
	Port   string
}

// GetMLConfig returns the ML API configuration
func GetMLConfig() *MLConfig {
	// Default to localhost, can be overridden with environment variables
	apiURL := os.Getenv("ML_API_URL")
	if apiURL == "" {
		apiURL = "http://localhost:5001"
	}

	port := os.Getenv("ML_API_PORT")
	if port == "" {
		port = "5001"
	}

	return &MLConfig{
		APIURL: apiURL,
		Port:   port,
	}
}