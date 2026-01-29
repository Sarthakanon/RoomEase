-- Migration 011: Add Balance and Settlement Tables
-- Purpose: Track user balances and settlement history for roomspaces
-- Date: 2026-01-29

-- ============================================================================
-- USER BALANCES TABLE
-- ============================================================================
-- Stores calculated balance for each user in each roomspace
-- Balance calculation:
--   - Positive balance = User is owed money (they paid more than their share)
--   - Negative balance = User owes money (they paid less than their share)
--   - Zero balance = User is settled up

CREATE TABLE IF NOT EXISTS user_balances (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    roomspace_id UUID NOT NULL,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    total_paid DECIMAL(10, 2) DEFAULT 0.00,
    total_owed DECIMAL(10, 2) DEFAULT 0.00,
    expense_count INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE(user_id, roomspace_id),
    FOREIGN KEY (roomspace_id) REFERENCES roomspaces(id) ON DELETE CASCADE
);

-- ============================================================================
-- SETTLEMENTS TABLE
-- ============================================================================
-- Records when users settle their balances
-- Used for tracking payment history and reducing balances

CREATE TABLE IF NOT EXISTS settlements (
    id SERIAL PRIMARY KEY,
    roomspace_id UUID NOT NULL,
    from_user_id VARCHAR(255) NOT NULL,
    to_user_id VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    settled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    
    -- Constraints
    FOREIGN KEY (roomspace_id) REFERENCES roomspaces(id) ON DELETE CASCADE,
    CHECK (from_user_id != to_user_id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index for querying balances by roomspace
CREATE INDEX IF NOT EXISTS idx_user_balances_roomspace 
ON user_balances(roomspace_id);

-- Index for querying balances by user
CREATE INDEX IF NOT EXISTS idx_user_balances_user 
ON user_balances(user_id);

-- Composite index for user-roomspace lookups
CREATE INDEX IF NOT EXISTS idx_user_balances_user_roomspace 
ON user_balances(user_id, roomspace_id);

-- Index for settlement history by roomspace
CREATE INDEX IF NOT EXISTS idx_settlements_roomspace 
ON settlements(roomspace_id);

-- Index for settlement history by user (from)
CREATE INDEX IF NOT EXISTS idx_settlements_from_user 
ON settlements(from_user_id);

-- Index for settlement history by user (to)
CREATE INDEX IF NOT EXISTS idx_settlements_to_user 
ON settlements(to_user_id);

-- Index for settlement date queries
CREATE INDEX IF NOT EXISTS idx_settlements_date 
ON settlements(settled_at DESC);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE user_balances IS 'Cached balance calculations for users in roomspaces';
COMMENT ON COLUMN user_balances.balance IS 'Net balance: positive = owed, negative = owes';
COMMENT ON COLUMN user_balances.total_paid IS 'Total amount user has paid for expenses';
COMMENT ON COLUMN user_balances.total_owed IS 'Total amount user owes from expense splits';
COMMENT ON COLUMN user_balances.expense_count IS 'Number of expenses user is involved in';

COMMENT ON TABLE settlements IS 'History of balance settlements between users';
COMMENT ON COLUMN settlements.from_user_id IS 'User who paid (debtor)';
COMMENT ON COLUMN settlements.to_user_id IS 'User who received payment (creditor)';
COMMENT ON COLUMN settlements.amount IS 'Amount settled';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify tables were created
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_balances') THEN
        RAISE NOTICE 'Table user_balances created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create user_balances table';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'settlements') THEN
        RAISE NOTICE 'Table settlements created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create settlements table';
    END IF;
END $$;

-- Verify indexes were created
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_user_balances_roomspace') THEN
        RAISE NOTICE 'Index idx_user_balances_roomspace created successfully';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_settlements_roomspace') THEN
        RAISE NOTICE 'Index idx_settlements_roomspace created successfully';
    END IF;
END $$;
