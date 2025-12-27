-- Migration: Add additional constraints and business rules for roomspace management
-- Description: Advanced constraints to enforce business rules and data integrity
-- Dependencies: 005_create_roomspaces_table.sql, 006_create_roomspace_members_table.sql, 007_create_join_requests_table.sql

-- Add constraint to ensure roomspace has at least one creator when created
ALTER TABLE roomspaces ADD CONSTRAINT chk_roomspaces_has_creator 
CHECK (
    -- This will be enforced by application logic and triggers
    -- since we can't directly reference other tables in CHECK constraints
    TRUE
);

-- Add function to validate roomspace member limits
CREATE OR REPLACE FUNCTION check_roomspace_member_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_member_count INTEGER;
    max_allowed INTEGER;
BEGIN
    -- Get current active member count and max limit
    SELECT COUNT(*), r.max_members
    INTO current_member_count, max_allowed
    FROM roomspace_members rm
    JOIN roomspaces r ON rm.roomspace_id = r.id
    WHERE rm.roomspace_id = NEW.roomspace_id 
    AND rm.is_active = TRUE
    AND r.is_archived = FALSE
    GROUP BY r.max_members;
    
    -- If no existing members, allow the first one (creator)
    IF current_member_count IS NULL THEN
        current_member_count := 0;
        SELECT max_members INTO max_allowed 
        FROM roomspaces 
        WHERE id = NEW.roomspace_id;
    END IF;
    
    -- Check if adding this member would exceed the limit
    IF NEW.is_active = TRUE AND current_member_count >= max_allowed THEN
        RAISE EXCEPTION 'Roomspace has reached maximum member limit of %', max_allowed;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to check member limits
CREATE TRIGGER trigger_check_roomspace_member_limit
    BEFORE INSERT OR UPDATE ON roomspace_members
    FOR EACH ROW
    EXECUTE FUNCTION check_roomspace_member_limit();

-- Add function to automatically create creator membership when roomspace is created
CREATE OR REPLACE FUNCTION create_creator_membership()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert creator as first member
    INSERT INTO roomspace_members (roomspace_id, user_id, role, joined_at, is_active)
    VALUES (NEW.id, NEW.creator_id, 'creator', NEW.created_at, TRUE);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-create creator membership
CREATE TRIGGER trigger_create_creator_membership
    AFTER INSERT ON roomspaces
    FOR EACH ROW
    EXECUTE FUNCTION create_creator_membership();

-- Add function to handle roomspace archival
CREATE OR REPLACE FUNCTION archive_roomspace_cascade()
RETURNS TRIGGER AS $$
BEGIN
    -- When roomspace is archived, deactivate all members and cancel pending requests
    IF NEW.is_archived = TRUE AND OLD.is_archived = FALSE THEN
        -- Deactivate all members
        UPDATE roomspace_members 
        SET is_active = FALSE 
        WHERE roomspace_id = NEW.id;
        
        -- Cancel all pending join requests
        UPDATE join_requests 
        SET status = 'cancelled', processed_at = NOW()
        WHERE roomspace_id = NEW.id AND status = 'pending';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for roomspace archival
CREATE TRIGGER trigger_archive_roomspace_cascade
    AFTER UPDATE ON roomspaces
    FOR EACH ROW
    EXECUTE FUNCTION archive_roomspace_cascade();

-- Add function to prevent modification of archived roomspaces
CREATE OR REPLACE FUNCTION prevent_archived_roomspace_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if roomspace is archived
    IF EXISTS (
        SELECT 1 FROM roomspaces 
        WHERE id = NEW.roomspace_id 
        AND is_archived = TRUE
    ) THEN
        RAISE EXCEPTION 'Cannot modify members of an archived roomspace';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to prevent changes to archived roomspaces
CREATE TRIGGER trigger_prevent_archived_member_changes
    BEFORE INSERT OR UPDATE ON roomspace_members
    FOR EACH ROW
    EXECUTE FUNCTION prevent_archived_roomspace_changes();

CREATE TRIGGER trigger_prevent_archived_join_requests
    BEFORE INSERT OR UPDATE ON join_requests
    FOR EACH ROW
    EXECUTE FUNCTION prevent_archived_roomspace_changes();

-- Add function to clean up expired join requests (can be called by cron job)
CREATE OR REPLACE FUNCTION cleanup_expired_join_requests()
RETURNS TABLE(expired_count INTEGER, cleaned_requests UUID[]) AS $$
DECLARE
    expired_ids UUID[];
    count_expired INTEGER;
BEGIN
    -- Get IDs of expired requests
    SELECT ARRAY_AGG(id) INTO expired_ids
    FROM join_requests 
    WHERE status = 'pending' 
    AND expires_at < NOW();
    
    -- Update expired requests
    UPDATE join_requests 
    SET status = 'expired', processed_at = NOW()
    WHERE id = ANY(expired_ids);
    
    GET DIAGNOSTICS count_expired = ROW_COUNT;
    
    RETURN QUERY SELECT count_expired, COALESCE(expired_ids, ARRAY[]::UUID[]);
END;
$$ LANGUAGE plpgsql;

-- Add function to transfer ownership when creator leaves
CREATE OR REPLACE FUNCTION handle_creator_departure()
RETURNS TRIGGER AS $$
DECLARE
    new_creator_id VARCHAR(28);
BEGIN
    -- If a creator is being removed or deactivated
    IF (TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND NEW.is_active = FALSE)) 
       AND OLD.role = 'creator' AND OLD.is_active = TRUE THEN
        
        -- Find the next admin or longest-serving member to promote
        SELECT user_id INTO new_creator_id
        FROM roomspace_members 
        WHERE roomspace_id = OLD.roomspace_id 
        AND is_active = TRUE 
        AND user_id != OLD.user_id
        ORDER BY 
            CASE WHEN role = 'admin' THEN 1 ELSE 2 END,
            joined_at ASC
        LIMIT 1;
        
        -- If we found someone to promote
        IF new_creator_id IS NOT NULL THEN
            UPDATE roomspace_members 
            SET role = 'creator'
            WHERE roomspace_id = OLD.roomspace_id 
            AND user_id = new_creator_id;
            
            -- Update the roomspace creator_id
            UPDATE roomspaces 
            SET creator_id = new_creator_id, updated_at = NOW()
            WHERE id = OLD.roomspace_id;
        ELSE
            -- No one left to promote, archive the roomspace
            UPDATE roomspaces 
            SET is_archived = TRUE, updated_at = NOW()
            WHERE id = OLD.roomspace_id;
        END IF;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for creator departure handling
CREATE TRIGGER trigger_handle_creator_departure
    BEFORE UPDATE OR DELETE ON roomspace_members
    FOR EACH ROW
    EXECUTE FUNCTION handle_creator_departure();

-- Add comments for documentation
COMMENT ON FUNCTION check_roomspace_member_limit() IS 'Enforces maximum member limit per roomspace';
COMMENT ON FUNCTION create_creator_membership() IS 'Automatically creates creator membership when roomspace is created';
COMMENT ON FUNCTION archive_roomspace_cascade() IS 'Handles cascading effects when roomspace is archived';
COMMENT ON FUNCTION prevent_archived_roomspace_changes() IS 'Prevents modifications to archived roomspaces';
COMMENT ON FUNCTION cleanup_expired_join_requests() IS 'Utility function to clean up expired join requests';
COMMENT ON FUNCTION handle_creator_departure() IS 'Handles ownership transfer when creator leaves roomspace';