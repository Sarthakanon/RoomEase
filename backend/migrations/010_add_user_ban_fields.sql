-- Add ban fields to users table
ALTER TABLE users 
ADD COLUMN is_banned BOOLEAN DEFAULT FALSE,
ADD COLUMN ban_reason TEXT,
ADD COLUMN banned_at TIMESTAMP;

-- Create index for banned users
CREATE INDEX idx_users_is_banned ON users(is_banned);

-- Update existing users to not be banned
UPDATE users SET is_banned = FALSE WHERE is_banned IS NULL;