-- Migration: Add recurring_config column to expenses table
-- Description: Add support for recurring expenses configuration

-- Add recurring_config column to expenses table
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS recurring_config JSONB;

-- Add index for recurring expenses queries
CREATE INDEX IF NOT EXISTS idx_expenses_recurring_config ON expenses USING GIN (recurring_config);

-- Add comment for documentation
COMMENT ON COLUMN expenses.recurring_config IS 'JSON configuration for recurring expenses (frequency, end date, etc.)';