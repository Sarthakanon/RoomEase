-- Migration: Create payment_confirmations table
-- Description: Add payment confirmation system for tracking and confirming payments between users

-- Create payment_confirmations table
CREATE TABLE IF NOT EXISTS payment_confirmations (
    id SERIAL PRIMARY KEY,
    roomspace_id UUID NOT NULL REFERENCES roomspaces(id) ON DELETE CASCADE,
    from_user_id VARCHAR(255) NOT NULL REFERENCES users(firebase_uid) ON DELETE RESTRICT,
    to_user_id VARCHAR(255) NOT NULL REFERENCES users(firebase_uid) ON DELETE RESTRICT,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN ('FULL', 'PARTIAL')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'CONFIRMED', 'REJECTED')),
    notes TEXT,
    payment_date TIMESTAMP NOT NULL,
    confirmed_at TIMESTAMP,
    confirmed_by VARCHAR(255) REFERENCES users(firebase_uid) ON DELETE SET NULL,
    rejection_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_different_users CHECK (from_user_id != to_user_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_payment_confirmations_roomspace_status ON payment_confirmations(roomspace_id, status);
CREATE INDEX idx_payment_confirmations_from_user ON payment_confirmations(from_user_id);
CREATE INDEX idx_payment_confirmations_to_user ON payment_confirmations(to_user_id);
CREATE INDEX idx_payment_confirmations_payment_date ON payment_confirmations(payment_date);
CREATE INDEX idx_payment_confirmations_created_at ON payment_confirmations(created_at);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_payment_confirmations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_payment_confirmations_updated_at
    BEFORE UPDATE ON payment_confirmations
    FOR EACH ROW
    EXECUTE FUNCTION update_payment_confirmations_updated_at();

-- Add optional fields to settlements table to link with payment confirmations
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS confirmation_id INTEGER REFERENCES payment_confirmations(id) ON DELETE SET NULL;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS is_confirmed BOOLEAN DEFAULT FALSE;

-- Create index on settlements confirmation_id
CREATE INDEX IF NOT EXISTS idx_settlements_confirmation_id ON settlements(confirmation_id);

-- Add comments for documentation
COMMENT ON TABLE payment_confirmations IS 'Tracks payment claims and confirmations between users in a roomspace';
COMMENT ON COLUMN payment_confirmations.from_user_id IS 'User who made the payment (payer)';
COMMENT ON COLUMN payment_confirmations.to_user_id IS 'User who received the payment (recipient)';
COMMENT ON COLUMN payment_confirmations.payment_type IS 'Whether payment is FULL or PARTIAL settlement';
COMMENT ON COLUMN payment_confirmations.status IS 'Payment status: PENDING, CONFIRMED, or REJECTED';
COMMENT ON COLUMN payment_confirmations.confirmed_by IS 'User who confirmed the payment (should be to_user_id)';
