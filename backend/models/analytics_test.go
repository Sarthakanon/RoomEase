package models

import (
	"testing"
	"time"

	"gorm.io/datatypes"
)

func TestAnalyticsCacheTableName(t *testing.T) {
	cache := AnalyticsCache{}
	if cache.TableName() != "analytics_cache" {
		t.Errorf("Expected table name 'analytics_cache', got '%s'", cache.TableName())
	}
}

func TestRecommendationFeedbackTableName(t *testing.T) {
	feedback := RecommendationFeedback{}
	if feedback.TableName() != "recommendation_feedback" {
		t.Errorf("Expected table name 'recommendation_feedback', got '%s'", feedback.TableName())
	}
}

func TestAnomalyAcknowledgmentTableName(t *testing.T) {
	ack := AnomalyAcknowledgment{}
	if ack.TableName() != "anomaly_acknowledgments" {
		t.Errorf("Expected table name 'anomaly_acknowledgments', got '%s'", ack.TableName())
	}
}

func TestMLModelTableName(t *testing.T) {
	model := MLModel{}
	if model.TableName() != "ml_models" {
		t.Errorf("Expected table name 'ml_models', got '%s'", model.TableName())
	}
}

func TestAnalyticsCacheCreation(t *testing.T) {
	userID := "test-user-123"
	roomspaceID := "test-roomspace-456"
	
	cache := AnalyticsCache{
		UserID:      userID,
		RoomspaceID: &roomspaceID,
		CacheType:   "summary",
		Data:        datatypes.JSON([]byte(`{"total_spent": 1000}`)),
		ComputedAt:  time.Now(),
		ExpiresAt:   time.Now().Add(24 * time.Hour),
	}
	
	if cache.UserID != userID {
		t.Errorf("Expected UserID '%s', got '%s'", userID, cache.UserID)
	}
	
	if cache.CacheType != "summary" {
		t.Errorf("Expected CacheType 'summary', got '%s'", cache.CacheType)
	}
}

func TestRecommendationFeedbackCreation(t *testing.T) {
	feedback := RecommendationFeedback{
		UserID:           "test-user-123",
		RecommendationID: "rec-456",
		FeedbackType:     "helpful",
		CreatedAt:        time.Now(),
	}
	
	if feedback.FeedbackType != "helpful" {
		t.Errorf("Expected FeedbackType 'helpful', got '%s'", feedback.FeedbackType)
	}
}

func TestAnomalyAcknowledgmentCreation(t *testing.T) {
	ack := AnomalyAcknowledgment{
		UserID:    "test-user-123",
		ExpenseID: 789,
		IsNormal:  true,
		CreatedAt: time.Now(),
	}
	
	if !ack.IsNormal {
		t.Error("Expected IsNormal to be true")
	}
	
	if ack.ExpenseID != 789 {
		t.Errorf("Expected ExpenseID 789, got %d", ack.ExpenseID)
	}
}

func TestMLModelCreation(t *testing.T) {
	accuracy := 0.85
	mae := 12.5
	
	model := MLModel{
		ModelName: "spending_predictor",
		Version:   "v1.0.0",
		FilePath:  "/models/spending_predictor_v1.tflite",
		Accuracy:  &accuracy,
		MAE:       &mae,
		TrainedAt: time.Now(),
		IsActive:  true,
		Metadata:  datatypes.JSON([]byte(`{"training_samples": 10000}`)),
	}
	
	if model.ModelName != "spending_predictor" {
		t.Errorf("Expected ModelName 'spending_predictor', got '%s'", model.ModelName)
	}
	
	if !model.IsActive {
		t.Error("Expected IsActive to be true")
	}
	
	if *model.Accuracy != 0.85 {
		t.Errorf("Expected Accuracy 0.85, got %f", *model.Accuracy)
	}
}
