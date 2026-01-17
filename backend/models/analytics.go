package models

import (
	"time"

	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// AnalyticsCache stores computed analytics data with expiration
type AnalyticsCache struct {
	ID          string         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID      string         `gorm:"type:varchar(255);not null;index" json:"user_id"`
	RoomspaceID *string        `gorm:"type:varchar(255);index" json:"roomspace_id,omitempty"`
	CacheType   string         `gorm:"type:varchar(50);not null;index" json:"cache_type"` // 'summary', 'predictions', 'patterns'
	Data        datatypes.JSON `gorm:"type:jsonb;not null" json:"data"`
	ComputedAt  time.Time      `gorm:"default:CURRENT_TIMESTAMP" json:"computed_at"`
	ExpiresAt   time.Time      `gorm:"not null;index" json:"expires_at"`
	CreatedAt   time.Time      `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time      `gorm:"autoUpdateTime" json:"updated_at"`
}

// TableName specifies the table name for AnalyticsCache
func (AnalyticsCache) TableName() string {
	return "analytics_cache"
}

// RecommendationFeedback stores user feedback on AI recommendations
type RecommendationFeedback struct {
	ID               string    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID           string    `gorm:"type:varchar(255);not null;index" json:"user_id"`
	RecommendationID string    `gorm:"type:varchar(255);not null;index" json:"recommendation_id"`
	FeedbackType     string    `gorm:"type:varchar(20);not null" json:"feedback_type"` // 'helpful', 'not_helpful', 'applied'
	CreatedAt        time.Time `gorm:"default:CURRENT_TIMESTAMP" json:"created_at"`
}

// TableName specifies the table name for RecommendationFeedback
func (RecommendationFeedback) TableName() string {
	return "recommendation_feedback"
}

// AnomalyAcknowledgment stores user acknowledgments of flagged anomalies
type AnomalyAcknowledgment struct {
	ID        string    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID    string    `gorm:"type:varchar(255);not null;index" json:"user_id"`
	ExpenseID uint      `gorm:"not null;index" json:"expense_id"`
	IsNormal  bool      `gorm:"default:false" json:"is_normal"`
	CreatedAt time.Time `gorm:"default:CURRENT_TIMESTAMP" json:"created_at"`
}

// TableName specifies the table name for AnomalyAcknowledgment
func (AnomalyAcknowledgment) TableName() string {
	return "anomaly_acknowledgments"
}

// MLModel stores metadata about trained ML models
type MLModel struct {
	ID         string         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ModelName  string         `gorm:"type:varchar(100);not null;index" json:"model_name"`
	Version    string         `gorm:"type:varchar(50);not null" json:"version"`
	FilePath   string         `gorm:"type:varchar(500);not null" json:"file_path"`
	Accuracy   *float64       `gorm:"type:float" json:"accuracy,omitempty"`
	MAE        *float64       `gorm:"type:float" json:"mae,omitempty"`
	TrainedAt  time.Time      `gorm:"default:CURRENT_TIMESTAMP" json:"trained_at"`
	IsActive   bool           `gorm:"default:false;index" json:"is_active"`
	Metadata   datatypes.JSON `gorm:"type:jsonb" json:"metadata,omitempty"`
	CreatedAt  time.Time      `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt  time.Time      `gorm:"autoUpdateTime" json:"updated_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
}

// TableName specifies the table name for MLModel
func (MLModel) TableName() string {
	return "ml_models"
}
