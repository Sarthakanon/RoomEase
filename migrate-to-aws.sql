-- RoomEase Database Migration to AWS RDS
-- Run this script on your new AWS RDS PostgreSQL instance

-- Create database (if not created during RDS setup)
-- CREATE DATABASE roomease;

-- Connect to roomease database and run the following:

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    profile_picture_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_banned BOOLEAN DEFAULT FALSE,
    banned_at TIMESTAMP,
    ban_reason TEXT
);

-- Roomspaces table
CREATE TABLE IF NOT EXISTS roomspaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    code VARCHAR(10) UNIQUE NOT NULL,
    created_by VARCHAR(255) REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Roomspace members table
CREATE TABLE IF NOT EXISTS roomspace_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roomspace_id UUID REFERENCES roomspaces(id) ON DELETE CASCADE,
    user_id VARCHAR(255) REFERENCES users(id),
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(roomspace_id, user_id)
);

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roomspace_id UUID REFERENCES roomspaces(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    amount DECIMAL(10,2) NOT NULL,
    category VARCHAR(100),
    paid_by VARCHAR(255) REFERENCES users(id),
    receipt_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expense_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Expense splits table
CREATE TABLE IF NOT EXISTS expense_splits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID REFERENCES expenses(id) ON DELETE CASCADE,
    user_id VARCHAR(255) REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Personal expenses table
CREATE TABLE IF NOT EXISTS personal_expenses (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    amount DECIMAL(10,2) NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User balances table
CREATE TABLE IF NOT EXISTS user_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roomspace_id UUID REFERENCES roomspaces(id) ON DELETE CASCADE,
    user_id VARCHAR(255) REFERENCES users(id),
    balance DECIMAL(10,2) DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(roomspace_id, user_id)
);

-- Settlements table
CREATE TABLE IF NOT EXISTS settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roomspace_id UUID REFERENCES roomspaces(id) ON DELETE CASCADE,
    from_user_id VARCHAR(255) REFERENCES users(id),
    to_user_id VARCHAR(255) REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) REFERENCES users(id),
    roomspace_id UUID REFERENCES roomspaces(id),
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Join requests table
CREATE TABLE IF NOT EXISTS join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roomspace_id UUID REFERENCES roomspaces(id) ON DELETE CASCADE,
    user_id VARCHAR(255) REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    processed_by VARCHAR(255) REFERENCES users(id)
);

-- Payment confirmations table
CREATE TABLE IF NOT EXISTS payment_confirmations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roomspace_id UUID REFERENCES roomspaces(id) ON DELETE CASCADE,
    from_user_id VARCHAR(255) REFERENCES users(id),
    to_user_id VARCHAR(255) REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP,
    rejected_at TIMESTAMP
);

-- Recommendation feedback table
CREATE TABLE IF NOT EXISTS recommendation_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) REFERENCES users(id),
    roomspace_id UUID REFERENCES roomspaces(id),
    recommendation_type VARCHAR(100) NOT NULL,
    feedback_type VARCHAR(20) NOT NULL,
    feedback_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_expenses_roomspace_id ON expenses(roomspace_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by);
CREATE INDEX IF NOT EXISTS idx_expense_splits_expense_id ON expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_user_id ON expense_splits(user_id);
CREATE INDEX IF NOT EXISTS idx_user_balances_roomspace_user ON user_balances(roomspace_id, user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_roomspace_members_roomspace_id ON roomspace_members(roomspace_id);

-- Insert sample data (optional)
-- You can export your existing data from Supabase and import here

COMMIT;