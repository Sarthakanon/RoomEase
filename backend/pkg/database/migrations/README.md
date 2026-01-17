# Database Migrations

This directory contains SQL migration files for the RoomEase backend database schema.

## Migration Files

### 009_add_roomspace_constraints.sql
Advanced constraints and triggers for roomspace management, including:
- Member limit enforcement
- Creator membership auto-creation
- Roomspace archival cascading
- Creator departure handling
- Join request expiration cleanup

### 010_create_analytics_tables.sql
Analytics tables for AI spending analytics feature, including:
- `analytics_cache` - Stores computed analytics with expiration
- `recommendation_feedback` - Tracks user feedback on AI recommendations
- `anomaly_acknowledgments` - Records user acknowledgments of spending anomalies
- `ml_models` - Stores ML model metadata and versioning

## Running Migrations

The application uses GORM's AutoMigrate feature to automatically create and update database tables based on the model definitions. The migration SQL files serve as documentation and can be run manually if needed.

### Automatic Migration (Recommended)
Migrations run automatically when the application starts:
```bash
go run main.go
```

### Manual Migration
To run a specific migration file manually:
```bash
psql -U your_username -d your_database -f backend/pkg/database/migrations/010_create_analytics_tables.sql
```

## Analytics Tables Schema

### analytics_cache
Caches computed analytics data to improve performance:
- `id` - UUID primary key
- `user_id` - Reference to user
- `roomspace_id` - Optional reference to roomspace
- `cache_type` - Type of cached data (summary, predictions, patterns, etc.)
- `data` - JSONB containing the analytics results
- `computed_at` - When the analytics were computed
- `expires_at` - When the cache should be invalidated

### recommendation_feedback
Stores user feedback on AI-generated recommendations:
- `id` - UUID primary key
- `user_id` - Reference to user
- `recommendation_id` - ID of the recommendation
- `feedback_type` - Type of feedback (helpful, not_helpful, applied)
- `created_at` - Timestamp

### anomaly_acknowledgments
Records when users mark flagged anomalies as normal:
- `id` - UUID primary key
- `user_id` - Reference to user
- `expense_id` - Reference to expense
- `is_normal` - Whether user marked it as normal
- `created_at` - Timestamp

### ml_models
Stores metadata about trained ML models:
- `id` - UUID primary key
- `model_name` - Name of the model (e.g., "spending_predictor")
- `version` - Version string
- `file_path` - Path to model file
- `accuracy` - Model accuracy metric
- `mae` - Mean Absolute Error metric
- `trained_at` - When the model was trained
- `is_active` - Whether this version is currently active
- `metadata` - JSONB for additional model information

## Utility Functions

### cleanup_expired_analytics_cache()
Removes expired cache entries. Can be called manually or scheduled via cron:
```sql
SELECT * FROM cleanup_expired_analytics_cache();
```

### ensure_single_active_model()
Automatically triggered when a model is set to active. Ensures only one version of each model is active at a time.

## Notes

- All analytics tables use UUID primary keys for better distribution
- Foreign keys include CASCADE delete to maintain referential integrity
- Indexes are created on frequently queried columns
- JSONB columns allow flexible schema evolution
- Timestamps use PostgreSQL's CURRENT_TIMESTAMP for consistency
