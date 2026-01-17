-- Migration: Create analytics tables for AI spending analytics feature
-- Description: Tables for caching analytics data, storing user feedback, anomaly acknowledgments, and ML model metadata
-- Dependencies: 001_create_users_table.sql, 003_create_expenses_table.sql

-- Analytics cache table for storing computed analytics with expiration
CREATE TABLE IF NOT EXISTS analytics_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    roomspace_id VARCHAR(255),
    cache_type VARCHAR(50) NOT NULL, -- 'summary', 'predictions', 'patterns', 'anomalies', 'recommendations'
    data JSONB NOT NULL,
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(firebase_uid) ON DELETE CASCADE
);

-- Create indexes for analytics_cache
CREATE INDEX IF NOT EXISTS idx_analytics_cache_user_id ON analytics_cache(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_roomspace_id ON analytics_cache(roomspace_id);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_cache_type ON analytics_cache(cache_type);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_expires_at ON analytics_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_user_type ON analytics_cache(user_id, cache_type);

-- User feedback on AI recommendations
CREATE TABLE IF NOT EXISTS recommendation_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    recommendation_id VARCHAR(255) NOT NULL,
    feedback_type VARCHAR(20) NOT NULL CHECK (feedback_type IN ('helpful', 'not_helpful', 'applied')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(firebase_uid) ON DELETE CASCADE
);

-- Create indexes for recommendation_feedback
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_user_id ON recommendation_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_recommendation_id ON recommendation_feedback(recommendation_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_created_at ON recommendation_feedback(created_at);

-- Anomaly acknowledgments for user-marked normal expenses
CREATE TABLE IF NOT EXISTS anomaly_acknowledgments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    expense_id BIGINT NOT NULL,
    is_normal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(firebase_uid) ON DELETE CASCADE,
    FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
);

-- Create indexes for anomaly_acknowledgments
CREATE INDEX IF NOT EXISTS idx_anomaly_acknowledgments_user_id ON anomaly_acknowledgments(user_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_acknowledgments_expense_id ON anomaly_acknowledgments(expense_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_acknowledgments_user_expense ON anomaly_acknowledgments(user_id, expense_id);

-- ML model versions and metadata
CREATE TABLE IF NOT EXISTS ml_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_name VARCHAR(100) NOT NULL,
    version VARCHAR(50) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    accuracy FLOAT,
    mae FLOAT,
    trained_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    UNIQUE(model_name, version)
);

-- Create indexes for ml_models
CREATE INDEX IF NOT EXISTS idx_ml_models_model_name ON ml_models(model_name);
CREATE INDEX IF NOT EXISTS idx_ml_models_is_active ON ml_models(is_active);
CREATE INDEX IF NOT EXISTS idx_ml_models_trained_at ON ml_models(trained_at);
CREATE INDEX IF NOT EXISTS idx_ml_models_deleted_at ON ml_models(deleted_at);

-- Function to automatically clean up expired analytics cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_analytics_cache()
RETURNS TABLE(deleted_count INTEGER, cleaned_ids UUID[]) AS $$
DECLARE
    expired_ids UUID[];
    count_deleted INTEGER;
BEGIN
    -- Get IDs of expired cache entries
    SELECT ARRAY_AGG(id) INTO expired_ids
    FROM analytics_cache 
    WHERE expires_at < NOW();
    
    -- Delete expired entries
    DELETE FROM analytics_cache 
    WHERE id = ANY(expired_ids);
    
    GET DIAGNOSTICS count_deleted = ROW_COUNT;
    
    RETURN QUERY SELECT count_deleted, COALESCE(expired_ids, ARRAY[]::UUID[]);
END;
$$ LANGUAGE plpgsql;

-- Function to ensure only one active model per model_name
CREATE OR REPLACE FUNCTION ensure_single_active_model()
RETURNS TRIGGER AS $$
BEGIN
    -- If setting a model to active, deactivate all other models with the same name
    IF NEW.is_active = TRUE THEN
        UPDATE ml_models 
        SET is_active = FALSE, updated_at = NOW()
        WHERE model_name = NEW.model_name 
        AND id != NEW.id 
        AND is_active = TRUE
        AND deleted_at IS NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to ensure single active model
CREATE TRIGGER trigger_ensure_single_active_model
    BEFORE INSERT OR UPDATE ON ml_models
    FOR EACH ROW
    WHEN (NEW.is_active = TRUE)
    EXECUTE FUNCTION ensure_single_active_model();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_analytics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER trigger_analytics_cache_updated_at
    BEFORE UPDATE ON analytics_cache
    FOR EACH ROW
    EXECUTE FUNCTION update_analytics_updated_at();

CREATE TRIGGER trigger_ml_models_updated_at
    BEFORE UPDATE ON ml_models
    FOR EACH ROW
    EXECUTE FUNCTION update_analytics_updated_at();

-- Add comments for documentation
COMMENT ON TABLE analytics_cache IS 'Stores computed analytics data with expiration for performance optimization';
COMMENT ON TABLE recommendation_feedback IS 'Tracks user feedback on AI-generated budget recommendations';
COMMENT ON TABLE anomaly_acknowledgments IS 'Records user acknowledgments of flagged spending anomalies';
COMMENT ON TABLE ml_models IS 'Stores metadata and versioning information for trained ML models';

COMMENT ON COLUMN analytics_cache.cache_type IS 'Type of cached analytics: summary, predictions, patterns, anomalies, recommendations';
COMMENT ON COLUMN analytics_cache.data IS 'JSON data containing the computed analytics results';
COMMENT ON COLUMN analytics_cache.expires_at IS 'Timestamp when this cache entry should be invalidated';

COMMENT ON COLUMN recommendation_feedback.feedback_type IS 'User feedback: helpful, not_helpful, or applied';
COMMENT ON COLUMN anomaly_acknowledgments.is_normal IS 'Whether user marked the flagged anomaly as normal spending';

COMMENT ON COLUMN ml_models.is_active IS 'Whether this model version is currently active for inference';
COMMENT ON COLUMN ml_models.accuracy IS 'Model accuracy metric from training evaluation';
COMMENT ON COLUMN ml_models.mae IS 'Mean Absolute Error metric from training evaluation';

COMMENT ON FUNCTION cleanup_expired_analytics_cache() IS 'Utility function to remove expired cache entries, can be called by cron job';
COMMENT ON FUNCTION ensure_single_active_model() IS 'Ensures only one model version is active per model_name';
