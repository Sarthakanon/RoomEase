-- Migration: Create expense_splits table
-- Description: Create the missing expense_splits table for tracking individual expense splits

-- Create expense_splits table
CREATE TABLE IF NOT EXISTS expense_splits (
    id BIGSERIAL PRIMARY KEY,
    expense_id BIGINT NOT NULL,
    user_uid VARCHAR(128) NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    percentage NUMERIC DEFAULT 0 CHECK (percentage >= 0 AND percentage <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    CONSTRAINT fk_expense_splits_expense FOREIGN KEY (expense_id) REFERENCES expenses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_expense_splits_user FOREIGN KEY (user_uid) REFERENCES users(firebase_uid) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_expense_splits_expense_id ON expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_user_uid ON expense_splits(user_uid);
CREATE INDEX IF NOT EXISTS idx_expense_splits_expense_user ON expense_splits(expense_id, user_uid);

-- Add comments for documentation
COMMENT ON TABLE expense_splits IS 'Individual expense splits showing how much each user owes for an expense';
COMMENT ON COLUMN expense_splits.expense_id IS 'Reference to the parent expense';
COMMENT ON COLUMN expense_splits.user_uid IS 'Firebase UID of the user who owes this amount';
COMMENT ON COLUMN expense_splits.amount IS 'Amount this user owes for the expense';
COMMENT ON COLUMN expense_splits.percentage IS 'Percentage of total expense (for percentage-based splits)';