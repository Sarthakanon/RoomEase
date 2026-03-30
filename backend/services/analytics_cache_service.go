package services

import (
	"encoding/json"
	"fmt"
	"roomease/backend/config"
	"roomease/backend/models"
	"time"

	"gorm.io/datatypes"
)

// AnalyticsCacheService handles caching of analytics data
type AnalyticsCacheService struct {
	dbService *PostgresService
}

// NewAnalyticsCacheService creates a new analytics cache service
func NewAnalyticsCacheService(dbService *PostgresService) *AnalyticsCacheService {
	return &AnalyticsCacheService{
		dbService: dbService,
	}
}

// GetOrComputeSummary gets cached summary or computes and caches it
func (s *AnalyticsCacheService) GetOrComputeSummary(
	userID string,
	roomspaceID *string,
	startDate, endDate time.Time,
	computeFunc func() (*AnalyticsSummary, error),
) (*AnalyticsSummary, error) {
	// Try to get from cache
	cached, err := s.getCachedData(userID, roomspaceID, "summary")
	if err == nil && cached != nil {
		var summary AnalyticsSummary
		if err := json.Unmarshal(cached.Data, &summary); err == nil {
			return &summary, nil
		}
	}

	// Compute fresh data
	summary, err := computeFunc()
	if err != nil {
		return nil, err
	}

	// Cache the result
	if err := s.cacheData(userID, roomspaceID, "summary", summary, 1*time.Hour); err != nil {
		// Log error but don't fail the request
		fmt.Printf("Warning: Failed to cache summary: %v\n", err)
	}

	return summary, nil
}

// GetOrComputePredictions gets cached predictions or computes and caches them
func (s *AnalyticsCacheService) GetOrComputePredictions(
	userID string,
	roomspaceID *string,
	computeFunc func() (*PredictionResult, error),
) (*PredictionResult, error) {
	// Try to get from cache
	cached, err := s.getCachedData(userID, roomspaceID, "predictions")
	if err == nil && cached != nil {
		var predictions PredictionResult
		if err := json.Unmarshal(cached.Data, &predictions); err == nil {
			return &predictions, nil
		}
	}

	// Compute fresh data
	predictions, err := computeFunc()
	if err != nil {
		return nil, err
	}

	// Cache the result (predictions valid for 24 hours)
	if err := s.cacheData(userID, roomspaceID, "predictions", predictions, 24*time.Hour); err != nil {
		fmt.Printf("Warning: Failed to cache predictions: %v\n", err)
	}

	return predictions, nil
}

// GetOrComputeRecommendations gets cached recommendations or computes and caches them
func (s *AnalyticsCacheService) GetOrComputeRecommendations(
	userID string,
	roomspaceID *string,
	computeFunc func() ([]Recommendation, error),
) ([]Recommendation, error) {
	// Try to get from cache
	cached, err := s.getCachedData(userID, roomspaceID, "recommendations")
	if err == nil && cached != nil {
		var recommendations []Recommendation
		if err := json.Unmarshal(cached.Data, &recommendations); err == nil {
			return recommendations, nil
		}
	}

	// Compute fresh data
	recommendations, err := computeFunc()
	if err != nil {
		return nil, err
	}

	// Cache the result (recommendations valid for 12 hours)
	if err := s.cacheData(userID, roomspaceID, "recommendations", recommendations, 12*time.Hour); err != nil {
		fmt.Printf("Warning: Failed to cache recommendations: %v\n", err)
	}

	return recommendations, nil
}

// GetOrComputeAnomalies gets cached anomalies or computes and caches them
func (s *AnalyticsCacheService) GetOrComputeAnomalies(
	userID string,
	roomspaceID *string,
	computeFunc func() ([]Anomaly, error),
) ([]Anomaly, error) {
	// Try to get from cache
	cached, err := s.getCachedData(userID, roomspaceID, "anomalies")
	if err == nil && cached != nil {
		var anomalies []Anomaly
		if err := json.Unmarshal(cached.Data, &anomalies); err == nil {
			return anomalies, nil
		}
	}

	// Compute fresh data
	anomalies, err := computeFunc()
	if err != nil {
		return nil, err
	}

	// Cache the result (anomalies valid for 6 hours)
	if err := s.cacheData(userID, roomspaceID, "anomalies", anomalies, 6*time.Hour); err != nil {
		fmt.Printf("Warning: Failed to cache anomalies: %v\n", err)
	}

	return anomalies, nil
}

// GetOrComputeRoomspaceAnalytics gets cached roomspace analytics or computes and caches them
func (s *AnalyticsCacheService) GetOrComputeRoomspaceAnalytics(
	userID string,
	roomspaceID string,
	computeFunc func() (*RoomspaceAnalytics, error),
) (*RoomspaceAnalytics, error) {
	// Try to get from cache
	cached, err := s.getCachedData(userID, &roomspaceID, "roomspace_analytics")
	if err == nil && cached != nil {
		var analytics RoomspaceAnalytics
		if err := json.Unmarshal(cached.Data, &analytics); err == nil {
			return &analytics, nil
		}
	}

	// Compute fresh data
	analytics, err := computeFunc()
	if err != nil {
		return nil, err
	}

	// Cache the result (roomspace analytics valid for 2 hours)
	if err := s.cacheData(userID, &roomspaceID, "roomspace_analytics", analytics, 2*time.Hour); err != nil {
		fmt.Printf("Warning: Failed to cache roomspace analytics: %v\n", err)
	}

	return analytics, nil
}

// InvalidateCache removes cached data for a user
func (s *AnalyticsCacheService) InvalidateCache(userID string, roomspaceID *string, cacheType string) error {
	query := config.DB.Where("user_id = ? AND cache_type = ?", userID, cacheType)
	
	if roomspaceID != nil {
		query = query.Where("roomspace_id = ?", *roomspaceID)
	} else {
		query = query.Where("roomspace_id IS NULL")
	}

	return query.Delete(&models.AnalyticsCache{}).Error
}

// InvalidateAllUserCache removes all cached data for a user
func (s *AnalyticsCacheService) InvalidateAllUserCache(userID string) error {
	return config.DB.Where("user_id = ?", userID).Delete(&models.AnalyticsCache{}).Error
}

// InvalidateAllRoomspaceCache removes all cached data for a roomspace
func (s *AnalyticsCacheService) InvalidateAllRoomspaceCache(roomspaceID string) error {
	return config.DB.Where("roomspace_id = ?", roomspaceID).Delete(&models.AnalyticsCache{}).Error
}

// CleanupExpiredCache removes expired cache entries
func (s *AnalyticsCacheService) CleanupExpiredCache() error {
	return config.DB.Where("expires_at < ?", time.Now()).Delete(&models.AnalyticsCache{}).Error
}

// SaveRecommendationFeedback stores user feedback on recommendations
func (s *AnalyticsCacheService) SaveRecommendationFeedback(userID, recommendationID, feedbackType string) error {
	feedback := models.RecommendationFeedback{
		UserID:           userID,
		RecommendationID: recommendationID,
		FeedbackType:     feedbackType,
	}

	return config.DB.Create(&feedback).Error
}

// SaveAnomalyAcknowledgment stores user acknowledgment of an anomaly
func (s *AnalyticsCacheService) SaveAnomalyAcknowledgment(userID string, expenseID uint, isNormal bool) error {
	acknowledgment := models.AnomalyAcknowledgment{
		UserID:    userID,
		ExpenseID: expenseID,
		IsNormal:  isNormal,
	}

	return config.DB.Create(&acknowledgment).Error
}

// GetAnomalyAcknowledgments gets all anomaly acknowledgments for a user
func (s *AnalyticsCacheService) GetAnomalyAcknowledgments(userID string) ([]models.AnomalyAcknowledgment, error) {
	var acknowledgments []models.AnomalyAcknowledgment
	err := config.DB.Where("user_id = ?", userID).Find(&acknowledgments).Error
	return acknowledgments, err
}

// Private helper methods

func (s *AnalyticsCacheService) getCachedData(userID string, roomspaceID *string, cacheType string) (*models.AnalyticsCache, error) {
	var cache models.AnalyticsCache

	query := config.DB.Where("user_id = ? AND cache_type = ? AND expires_at > ?", 
		userID, cacheType, time.Now())

	if roomspaceID != nil {
		query = query.Where("roomspace_id = ?", *roomspaceID)
	} else {
		query = query.Where("roomspace_id IS NULL")
	}

	if err := query.First(&cache).Error; err != nil {
		return nil, err
	}

	return &cache, nil
}

func (s *AnalyticsCacheService) cacheData(userID string, roomspaceID *string, cacheType string, data interface{}, ttl time.Duration) error {
	// Marshal data to JSON
	jsonData, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal data: %v", err)
	}

	// Delete existing cache entry
	query := config.DB.Where("user_id = ? AND cache_type = ?", userID, cacheType)
	if roomspaceID != nil {
		query = query.Where("roomspace_id = ?", *roomspaceID)
	} else {
		query = query.Where("roomspace_id IS NULL")
	}
	query.Delete(&models.AnalyticsCache{})

	// Create new cache entry
	cache := models.AnalyticsCache{
		UserID:      userID,
		RoomspaceID: roomspaceID,
		CacheType:   cacheType,
		Data:        datatypes.JSON(jsonData),
		ComputedAt:  time.Now(),
		ExpiresAt:   time.Now().Add(ttl),
	}

	return config.DB.Create(&cache).Error
}

// GetCacheStats returns statistics about cached analytics data
func (s *AnalyticsCacheService) GetCacheStats() (map[string]interface{}, error) {
	var totalCount int64
	var expiredCount int64

	if err := config.DB.Model(&models.AnalyticsCache{}).Count(&totalCount).Error; err != nil {
		return nil, err
	}

	if err := config.DB.Model(&models.AnalyticsCache{}).
		Where("expires_at < ?", time.Now()).
		Count(&expiredCount).Error; err != nil {
		return nil, err
	}

	// Count by cache type
	var typeCounts []struct {
		CacheType string
		Count     int64
	}

	if err := config.DB.Model(&models.AnalyticsCache{}).
		Select("cache_type, COUNT(*) as count").
		Group("cache_type").
		Scan(&typeCounts).Error; err != nil {
		return nil, err
	}

	typeCountsMap := make(map[string]int64)
	for _, tc := range typeCounts {
		typeCountsMap[tc.CacheType] = tc.Count
	}

	return map[string]interface{}{
		"total_cached":   totalCount,
		"expired":        expiredCount,
		"active":         totalCount - expiredCount,
		"by_type":        typeCountsMap,
		"last_cleanup":   time.Now().Format(time.RFC3339),
	}, nil
}
