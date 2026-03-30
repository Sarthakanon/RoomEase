package main

import (
	"log"
	"roomease/backend/config"
)

func main() {
	log.Println("🔧 Creating settlements table manually...")

	// Load configuration
	cfg := config.LoadConfig()

	// Initialize PostgreSQL
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Fatalf("Failed to initialize PostgreSQL: %v", err)
	}
	defer config.ClosePostgreSQL()

	// Create settlements table manually
	createSettlementsSQL := `
	CREATE TABLE IF NOT EXISTS settlements (
		id BIGSERIAL PRIMARY KEY,
		roomspace_id UUID NOT NULL,
		from_user_id VARCHAR(255) NOT NULL,
		to_user_id VARCHAR(255) NOT NULL,
		amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
		settled_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
		notes TEXT,
		created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
		CONSTRAINT fk_settlements_roomspace FOREIGN KEY (roomspace_id) REFERENCES roomspaces(id) ON DELETE CASCADE ON UPDATE CASCADE,
		CONSTRAINT fk_settlements_from_user FOREIGN KEY (from_user_id) REFERENCES users(firebase_uid) ON DELETE RESTRICT ON UPDATE CASCADE,
		CONSTRAINT fk_settlements_to_user FOREIGN KEY (to_user_id) REFERENCES users(firebase_uid) ON DELETE RESTRICT ON UPDATE CASCADE
	);`

	if err := config.DB.Exec(createSettlementsSQL).Error; err != nil {
		log.Printf("⚠️  Warning: Failed to create settlements table: %v", err)
		log.Println("Table might already exist, continuing...")
	} else {
		log.Println("✅ Settlements table created successfully")
	}

	// Create index for settlements
	createIndexSQL := `
	CREATE INDEX IF NOT EXISTS idx_settlements_date ON settlements(settled_at);
	CREATE INDEX IF NOT EXISTS idx_settlements_roomspace_id ON settlements(roomspace_id);
	CREATE INDEX IF NOT EXISTS idx_settlements_from_user_id ON settlements(from_user_id);
	CREATE INDEX IF NOT EXISTS idx_settlements_to_user_id ON settlements(to_user_id);`

	if err := config.DB.Exec(createIndexSQL).Error; err != nil {
		log.Printf("⚠️  Warning: Failed to create settlements indexes: %v", err)
	} else {
		log.Println("✅ Settlements indexes created successfully")
	}

	// Create user_balances table if it doesn't exist
	createUserBalancesSQL := `
	CREATE TABLE IF NOT EXISTS user_balances (
		id BIGSERIAL PRIMARY KEY,
		user_id VARCHAR(255) NOT NULL,
		roomspace_id UUID NOT NULL,
		balance DECIMAL(10,2) DEFAULT 0.00,
		total_paid DECIMAL(10,2) DEFAULT 0.00,
		total_owed DECIMAL(10,2) DEFAULT 0.00,
		expense_count INTEGER DEFAULT 0,
		last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
		created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
		CONSTRAINT fk_user_balances_user FOREIGN KEY (user_id) REFERENCES users(firebase_uid) ON DELETE RESTRICT ON UPDATE CASCADE,
		CONSTRAINT fk_user_balances_roomspace FOREIGN KEY (roomspace_id) REFERENCES roomspaces(id) ON DELETE CASCADE ON UPDATE CASCADE
	);`

	if err := config.DB.Exec(createUserBalancesSQL).Error; err != nil {
		log.Printf("⚠️  Warning: Failed to create user_balances table: %v", err)
		log.Println("Table might already exist, continuing...")
	} else {
		log.Println("✅ User balances table created successfully")
	}

	// Create indexes for user_balances
	createUserBalancesIndexSQL := `
	CREATE INDEX IF NOT EXISTS idx_user_balances_user_id ON user_balances(user_id);
	CREATE INDEX IF NOT EXISTS idx_user_balances_roomspace_id ON user_balances(roomspace_id);`

	if err := config.DB.Exec(createUserBalancesIndexSQL).Error; err != nil {
		log.Printf("⚠️  Warning: Failed to create user_balances indexes: %v", err)
	} else {
		log.Println("✅ User balances indexes created successfully")
	}

	log.Println("✅ All balance-related tables created successfully")
}