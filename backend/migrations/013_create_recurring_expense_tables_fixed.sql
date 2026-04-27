-- Migration: Create recurring expense tables (fixed)
-- Description: Create tables for recurring expense templates and notifications

-- Create recurring_expense_templates table
CREATE TABLE IF NOT EXISTS recurring_expense_templates (
    id SERIAL PRIMARY KEY,
    roomspace_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    category VARCHAR(100) NOT NULL,
    created_by VARCHAR(128) NOT NULL,
    selected_roommates TEXT,
    split_type VARCHAR(20) NOT NULL,
    custom_splits JSONB,
    recurring_config JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_generated TIMESTAMP WITH TIME ZONE,
    occurrence_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Foreign key constraints
    CONSTRAINT fk_recurring_templates_roomspace FOREIGN KEY (roomspace_id) REFERENCES roomspaces(id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_recurring_templates_creator FOREIGN KEY (created_by) REFERENCES users(firebase_uid) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Create recurring_expense_notifications table
CREATE TABLE IF NOT EXISTS recurring_expense_notifications (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL,
    roomspace_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    notification_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    is_processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    CONSTRAINT fk_recurring_notifications_template FOREIGN KEY (template_id) REFERENCES recurring_expense_templates(id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_recurring_notifications_roomspace FOREIGN KEY (roomspace_id) REFERENCES roomspaces(id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_recurring_templates_roomspace ON recurring_expense_templates(roomspace_id);
CREATE INDEX IF NOT EXISTS idx_recurring_templates_creator ON recurring_expense_templates(created_by);
CREATE INDEX IF NOT EXISTS idx_recurring_templates_active ON recurring_expense_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_recurring_templates_roomspace_active ON recurring_expense_templates(roomspace_id, is_active);

CREATE INDEX IF NOT EXISTS idx_recurring_notifications_template ON recurring_expense_notifications(template_id);
CREATE INDEX IF NOT EXISTS idx_recurring_notifications_roomspace ON recurring_expense_notifications(roomspace_id);
CREATE INDEX IF NOT EXISTS idx_recurring_notifications_scheduled ON recurring_expense_notifications(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_recurring_notifications_processed ON recurring_expense_notifications(is_processed);
CREATE INDEX IF NOT EXISTS idx_recurring_notifications_roomspace_processed ON recurring_expense_notifications(roomspace_id, is_processed);

-- Create triggers to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_recurring_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_recurring_templates_updated_at
    BEFORE UPDATE ON recurring_expense_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_recurring_templates_updated_at();

CREATE OR REPLACE FUNCTION update_recurring_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_recurring_notifications_updated_at
    BEFORE UPDATE ON recurring_expense_notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_recurring_notifications_updated_at();

-- Add comments for documentation
COMMENT ON TABLE recurring_expense_templates IS 'Templates for recurring expenses that generate expenses automatically';
COMMENT ON TABLE recurring_expense_notifications IS 'Notifications for upcoming recurring expenses';

COMMENT ON COLUMN recurring_expense_templates.roomspace_id IS 'Reference to the roomspace where this recurring expense applies';
COMMENT ON COLUMN recurring_expense_templates.created_by IS 'Firebase UID of the user who created this template';
COMMENT ON COLUMN recurring_expense_templates.selected_roommates IS 'JSON array of Firebase UIDs for selected roommates';
COMMENT ON COLUMN recurring_expense_templates.recurring_config IS 'JSON configuration for recurring schedule (interval, end date, etc.)';
COMMENT ON COLUMN recurring_expense_templates.last_generated IS 'Timestamp of when this template last generated an expense';
COMMENT ON COLUMN recurring_expense_templates.occurrence_count IS 'Number of times this template has generated an expense';

COMMENT ON COLUMN recurring_expense_notifications.template_id IS 'Reference to the recurring expense template';
COMMENT ON COLUMN recurring_expense_notifications.scheduled_date IS 'When the recurring expense is scheduled to be created';
COMMENT ON COLUMN recurring_expense_notifications.notification_date IS 'When the notification was/should be sent';
COMMENT ON COLUMN recurring_expense_notifications.is_processed IS 'Whether this notification has been processed (expense created or skipped)';