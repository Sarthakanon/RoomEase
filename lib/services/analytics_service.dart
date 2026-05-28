import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analytics_models.dart';
import 'api_service.dart';

/// Service for handling analytics API calls and caching
/// 
/// NOTE: This service communicates with the backend analytics endpoints.
/// Advanced model behavior is provided server-side via the active ML bridge.
/// 
/// Provides methods to fetch:
/// - Spending summaries
/// - Spending trends
/// - Simple predictions (historical averages)
/// - Basic patterns (rule-based)
/// - Statistical anomalies
/// - Rule-based recommendations
/// - Roomspace analytics
/// 
/// Implements offline caching for better user experience
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final ApiService _apiService = ApiService();

  // Cache keys - made public for cache timestamp checking
  static const String _cacheKeyPrefix = 'analytics_cache_';
  static const String _cacheTimestampPrefix = 'analytics_timestamp_';
  static const Duration _cacheExpiration = Duration(minutes: 15);

  /// Get spending summary with key metrics
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter by
  /// [startDate] - Optional start date (YYYY-MM-DD format)
  /// [endDate] - Optional end date (YYYY-MM-DD format)
  /// 
  /// Returns [AnalyticsSummary] with total spent, predictions, and savings potential
  Future<AnalyticsSummary> getSummary({
    String? roomspaceId,
    String? startDate,
    String? endDate,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}summary_${roomspaceId ?? 'all'}_${startDate ?? ''}_${endDate ?? ''}';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final path = '/api/analytics/summary${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final summary = AnalyticsSummary.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, summary.toJson());
        
        return summary;
      } else {
        throw Exception(response['error'] ?? 'Failed to get spending summary');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return AnalyticsSummary.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get spending summary: ${e.toString()}');
    }
  }

  /// Get spending trends over time
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter by
  /// [startDate] - Optional start date (YYYY-MM-DD format)
  /// [endDate] - Optional end date (YYYY-MM-DD format)
  /// [groupBy] - Grouping period: "day", "week", or "month" (default: "day")
  /// 
  /// Returns [TrendsResponse] with spending data points
  Future<TrendsResponse> getTrends({
    String? roomspaceId,
    String? startDate,
    String? endDate,
    String groupBy = 'day',
  }) async {
    final cacheKey = '${_cacheKeyPrefix}trends_${roomspaceId ?? 'all'}_${startDate ?? ''}_${endDate ?? ''}_$groupBy';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'group_by': groupBy,
      };
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final path = '/api/analytics/trends${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final trends = TrendsResponse.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, trends.toJson());
        
        return trends;
      } else {
        throw Exception(response['error'] ?? 'Failed to get spending trends');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return TrendsResponse.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get spending trends: ${e.toString()}');
    }
  }

  /// Get spending predictions for next month
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter by
  /// 
  /// Returns [PredictionResult] with predictions per category
  Future<PredictionResult> getPredictions({
    String? roomspaceId,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}predictions_${roomspaceId ?? 'all'}';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;

      final path = '/api/analytics/predictions${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final predictions = PredictionResult.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, predictions.toJson());
        
        return predictions;
      } else {
        throw Exception(response['error'] ?? 'Failed to get spending predictions');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return PredictionResult.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get spending predictions: ${e.toString()}');
    }
  }

  /// Get identified spending patterns
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter by
  /// 
  /// Returns [PatternsResponse] with detected patterns
  Future<PatternsResponse> getPatterns({
    String? roomspaceId,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}patterns_${roomspaceId ?? 'all'}';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;

      final path = '/api/analytics/patterns${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final patterns = PatternsResponse.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, patterns.toJson());
        
        return patterns;
      } else {
        throw Exception(response['error'] ?? 'Failed to get spending patterns');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return PatternsResponse.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get spending patterns: ${e.toString()}');
    }
  }

  /// Get detected spending anomalies
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter by
  /// 
  /// Returns [AnomaliesResponse] with flagged anomalies
  Future<AnomaliesResponse> getAnomalies({
    String? roomspaceId,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}anomalies_${roomspaceId ?? 'all'}';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;

      final path = '/api/analytics/anomalies${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final anomalies = AnomaliesResponse.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, anomalies.toJson());
        
        return anomalies;
      } else {
        throw Exception(response['error'] ?? 'Failed to get anomalies');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return AnomaliesResponse.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get anomalies: ${e.toString()}');
    }
  }

  /// Get AI-generated budget recommendations
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter by
  /// 
  /// Returns [RecommendationsResponse] with recommendations sorted by savings potential
  Future<RecommendationsResponse> getRecommendations({
    String? roomspaceId,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}recommendations_${roomspaceId ?? 'all'}';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;

      final path = '/api/analytics/recommendations${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final recommendations = RecommendationsResponse.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, recommendations.toJson());
        
        return recommendations;
      } else {
        throw Exception(response['error'] ?? 'Failed to get recommendations');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return RecommendationsResponse.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get recommendations: ${e.toString()}');
    }
  }

  /// Get analytics for a specific roomspace
  /// 
  /// [roomspaceId] - Roomspace ID (required)
  /// [startDate] - Optional start date (YYYY-MM-DD format)
  /// [endDate] - Optional end date (YYYY-MM-DD format)
  /// 
  /// Returns [RoomspaceAnalytics] with shared expenses and member contributions
  Future<RoomspaceAnalytics> getRoomspaceAnalytics(
    String roomspaceId, {
    String? startDate,
    String? endDate,
  }) async {
    final cacheKey = '${_cacheKeyPrefix}roomspace_${roomspaceId}_${startDate ?? ''}_${endDate ?? ''}';
    
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final path = '/api/analytics/roomspace/$roomspaceId${_buildQueryString(queryParams)}';
      final response = await _apiService.get(path);

      if (response['success'] == true && response['data'] != null) {
        final analytics = RoomspaceAnalytics.fromJson(response['data']);
        
        // Cache the result
        await _cacheData(cacheKey, analytics.toJson());
        
        return analytics;
      } else {
        throw Exception(response['error'] ?? 'Failed to get roomspace analytics');
      }
    } catch (e) {
      // Try to return cached data on error
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        return RoomspaceAnalytics.fromJson(cachedData);
      }
      
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get roomspace analytics: ${e.toString()}');
    }
  }

  /// Submit feedback on a recommendation
  /// 
  /// [recommendationId] - ID of the recommendation
  /// [feedbackType] - Type of feedback: "helpful", "not_helpful", or "applied"
  /// 
  /// Returns true if feedback was submitted successfully
  Future<bool> submitFeedback({
    required String recommendationId,
    required String feedbackType,
  }) async {
    try {
      final data = {
        'recommendation_id': recommendationId,
        'feedback_type': feedbackType,
      };

      final response = await _apiService.post('/api/analytics/feedback', data: data);

      if (response['success'] == true) {
        return true;
      } else {
        throw Exception(response['error'] ?? 'Failed to submit feedback');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to submit feedback: ${e.toString()}');
    }
  }

  /// Clear all cached analytics data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix) || key.startsWith(_cacheTimestampPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Silently fail - cache clearing is not critical
    }
  }

  /// Get the timestamp of the last cache update for a specific key
  /// 
  /// Returns null if no cached data exists or cache is expired
  Future<DateTime?> getCacheTimestamp(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '$_cacheTimestampPrefix$cacheKey';
      final timestamp = prefs.getInt(timestampKey);
      
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      // Check if cache is expired
      if (now.difference(cacheTime) > _cacheExpiration) {
        return null;
      }
      
      return cacheTime;
    } catch (e) {
      return null;
    }
  }

  /// Build cache key for summary endpoint
  String getSummaryCacheKey({
    String? roomspaceId,
    String? startDate,
    String? endDate,
  }) {
    return '${_cacheKeyPrefix}summary_${roomspaceId ?? 'all'}_${startDate ?? ''}_${endDate ?? ''}';
  }

  Future<AnalyticsSummary?> getCachedSummary({
    String? roomspaceId,
    String? startDate,
    String? endDate,
  }) async {
    final key = getSummaryCacheKey(
      roomspaceId: roomspaceId,
      startDate: startDate,
      endDate: endDate,
    );
    final cached = await _getCachedData(key);
    if (cached == null) return null;
    return AnalyticsSummary.fromJson(cached);
  }

  /// Build cache key for trends endpoint
  String getTrendsCacheKey({
    String? roomspaceId,
    String? startDate,
    String? endDate,
    String groupBy = 'day',
  }) {
    return '${_cacheKeyPrefix}trends_${roomspaceId ?? 'all'}_${startDate ?? ''}_${endDate ?? ''}_$groupBy';
  }

  // Private helper methods

  /// Build query string from parameters
  String _buildQueryString(Map<String, String> params) {
    if (params.isEmpty) return '';
    
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '?$query';
  }

  /// Cache data with timestamp
  Future<void> _cacheData(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString(key, jsonString);
      
      // Store timestamp
      final timestampKey = '$_cacheTimestampPrefix$key';
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail - caching is not critical
    }
  }

  /// Get cached data if not expired
  Future<Map<String, dynamic>?> _getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists and is not expired
      final timestampKey = '$_cacheTimestampPrefix$key';
      final timestamp = prefs.getInt(timestampKey);
      
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      // Check if cache is expired
      if (now.difference(cacheTime) > _cacheExpiration) {
        // Remove expired cache
        await prefs.remove(key);
        await prefs.remove(timestampKey);
        return null;
      }
      
      // Get cached data
      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;
      
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // Silently fail - return null to fetch fresh data
      return null;
    }
  }
}
