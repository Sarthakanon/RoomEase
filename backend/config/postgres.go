package config

import (
	"fmt"
	"log"
	"net"
	"net/url"
	"strings"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// InitPostgreSQL initializes PostgreSQL connection using GORM with DATABASE_URL
func InitPostgreSQL(databaseURL string) error {
	// Use sslmode=require for Supabase, disable for local development
	var dsn string
	if databaseURL == "" {
		return fmt.Errorf("database URL is empty")
	}
	
	// Check if it's a Supabase connection (contains supabase.co) or AWS RDS (contains amazonaws.com)
	if strings.Contains(databaseURL, "supabase.co") || strings.Contains(databaseURL, "supabase.com") {
		// Try to resolve IPv4 address for Supabase hostname
		hostname := "db.raabjafkrerotvqbimbp.supabase.co"
		
		// Try to get IPv4 address
		ips, err := net.LookupIP(hostname)
		var ipv4Addr string
		
		if err == nil {
			// Look for IPv4 address
			for _, ip := range ips {
				if ip.To4() != nil {
					ipv4Addr = ip.String()
					log.Printf("🔍 Found IPv4 address for %s: %s", hostname, ipv4Addr)
					break
				}
			}
		}
		
		// If we found an IPv4 address, replace the hostname
		if ipv4Addr != "" {
			dsn = strings.Replace(databaseURL, hostname, ipv4Addr, 1)
		} else {
			log.Println("⚠️  Could not resolve IPv4 address, using original hostname")
			dsn = databaseURL
		}
		
		// Add connection optimizations for Supabase and preserve existing query params.
		dsn = addOrUpdateQueryParams(dsn, map[string]string{
			"sslmode":                              "require",
			"search_path":                          "public",
			"connect_timeout":                      "30",
			"statement_timeout":                    "30000",
			"idle_in_transaction_session_timeout":  "30000",
			"tcp_user_timeout":                     "30000",
			"application_name":                     "roomease_backend",
			"prefer_simple_protocol":               "true",
		})
		log.Println("🌐 Connecting to Supabase PostgreSQL with optimized settings...")
	} else if strings.Contains(databaseURL, "amazonaws.com") {
		// AWS RDS connection
		dsn = addOrUpdateQueryParams(databaseURL, map[string]string{
			"sslmode":         "require",
			"connect_timeout": "10",
		})
		log.Println("☁️  Connecting to AWS RDS PostgreSQL...")
	} else {
		dsn = addOrUpdateQueryParams(databaseURL, map[string]string{
			"sslmode":         "disable",
			"connect_timeout": "10",
		})
		log.Println("🐳 Connecting to local PostgreSQL...")
	}
	
	log.Printf("Connecting to PostgreSQL with DSN: %s", dsn)
	
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("failed to connect to PostgreSQL: %w", err)
	}

	// Configure connection pool for better performance
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("failed to get underlying sql.DB: %w", err)
	}

	// Set connection pool settings
	sqlDB.SetMaxOpenConns(10)                    // Maximum number of open connections
	sqlDB.SetMaxIdleConns(5)                     // Maximum number of idle connections
	sqlDB.SetConnMaxLifetime(time.Minute * 5)    // Maximum connection lifetime (5 minutes)

	DB = db
	log.Println("✅ PostgreSQL connected successfully with connection pool configured")
	return nil
}

func addOrUpdateQueryParams(rawURL string, params map[string]string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return rawURL
	}
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()
	return u.String()
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
