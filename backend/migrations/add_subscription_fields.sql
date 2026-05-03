-- Add subscription fields to users table
-- This migration adds subscription_plan and subscription_expiry columns

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS subscription_plan VARCHAR(50) DEFAULT 'free',
ADD COLUMN IF NOT EXISTS subscription_expiry TIMESTAMP NULL;

-- Create index for faster subscription queries
CREATE INDEX IF NOT EXISTS idx_users_subscription_plan ON users(subscription_plan);
CREATE INDEX IF NOT EXISTS idx_users_subscription_expiry ON users(subscription_expiry);

-- Update existing users to have free plan
UPDATE users 
SET subscription_plan = 'free' 
WHERE subscription_plan IS NULL OR subscription_plan = '';

COMMENT ON COLUMN users.subscription_plan IS 'User subscription plan: free, pro';
COMMENT ON COLUMN users.subscription_expiry IS 'Subscription expiry date (NULL for free plan or lifetime)';
