-- Add created_at and updated_at columns to settlements table
-- These columns are required by GORM for automatic timestamp management

-- Add created_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'settlements' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE settlements ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'settlements' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE settlements ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
END $$;

-- Create trigger to automatically update updated_at on row updates
CREATE OR REPLACE FUNCTION update_settlements_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists and recreate
DROP TRIGGER IF EXISTS settlements_updated_at_trigger ON settlements;
CREATE TRIGGER settlements_updated_at_trigger
    BEFORE UPDATE ON settlements
    FOR EACH ROW
    EXECUTE FUNCTION update_settlements_updated_at();
