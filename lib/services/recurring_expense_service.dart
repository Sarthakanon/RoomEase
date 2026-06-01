import '../models/recurring_expense_models.dart';
import 'api_service.dart';
import 'real_time_data_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing recurring expenses
class RecurringExpenseService {
  static final RecurringExpenseService _instance = RecurringExpenseService._internal();
  factory RecurringExpenseService() => _instance;
  RecurringExpenseService._internal();

  final ApiService _apiService = ApiService();
  static const String _templatesCachePrefix = 'recurring_templates_cache_';
  static const String _notificationsCachePrefix = 'recurring_notifications_cache_';

  Future<void> _cacheTemplates(String roomspaceId, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_templatesCachePrefix$roomspaceId',
        jsonEncode({
          'data': data,
          'cached_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<List<RecurringExpenseTemplate>> _readCachedTemplates(String roomspaceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_templatesCachePrefix$roomspaceId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['data'] as List<dynamic>? ?? const [];
      return list
          .map((data) => RecurringExpenseTemplate.fromJson(Map<String, dynamic>.from(data as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheNotifications(String roomspaceId, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_notificationsCachePrefix$roomspaceId',
        jsonEncode({
          'data': data,
          'cached_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<List<RecurringExpenseNotification>> _readCachedNotifications(String roomspaceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_notificationsCachePrefix$roomspaceId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['data'] as List<dynamic>? ?? const [];
      return list
          .map((data) => RecurringExpenseNotification.fromJson(Map<String, dynamic>.from(data as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get recurring expense templates for a roomspace
  Future<List<RecurringExpenseTemplate>> getRecurringExpenseTemplates(String roomspaceId) async {
    try {
      final response = await _apiService.getRecurringExpenseTemplates(roomspaceId);
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> templatesData = response['data'];
        await _cacheTemplates(roomspaceId, templatesData);
        return templatesData
            .map((data) => RecurringExpenseTemplate.fromJson(data))
            .toList();
      }
      final cached = await _readCachedTemplates(roomspaceId);
      if (cached.isNotEmpty) return cached;
      return [];
    } catch (e) {
      final cached = await _readCachedTemplates(roomspaceId);
      if (cached.isNotEmpty) return cached;
      throw Exception('Failed to get recurring expense templates: ${e.toString()}');
    }
  }

  /// Create a recurring expense template
  Future<RecurringExpenseTemplate> createRecurringExpenseTemplate(
    RecurringExpenseTemplate template,
  ) async {
    try {
      final response = await _apiService.createRecurringExpenseTemplate(
        template.toJson(),
      );
      
      if (response['success'] == true && response['data'] != null) {
        return RecurringExpenseTemplate.fromJson(response['data']);
      }
      
      throw Exception('Failed to create recurring expense template');
    } catch (e) {
      throw Exception('Failed to create recurring expense template: ${e.toString()}');
    }
  }

  /// Update a recurring expense template
  Future<RecurringExpenseTemplate> updateRecurringExpenseTemplate(
    int templateId,
    RecurringExpenseTemplate template, {
    DateTime? nextScheduledDate,
  }) async {
    try {
      final payload = template.toJson();
      if (nextScheduledDate != null) {
        final normalizedUtc = DateTime.utc(
          nextScheduledDate.year,
          nextScheduledDate.month,
          nextScheduledDate.day,
          12,
          0,
          0,
        );
        payload['next_scheduled_date'] = normalizedUtc.toIso8601String();
      }
      final response = await _apiService.updateRecurringExpenseTemplate(
        templateId,
        payload,
      );
      
      if (response['success'] == true && response['data'] != null) {
        RealTimeDataService().clearAllData();
        return RecurringExpenseTemplate.fromJson(response['data']);
      }
      
      throw Exception('Failed to update recurring expense template');
    } catch (e) {
      throw Exception('Failed to update recurring expense template: ${e.toString()}');
    }
  }

  /// Delete a recurring expense template
  Future<void> deleteRecurringExpenseTemplate(int templateId) async {
    try {
      final response = await _apiService.deleteRecurringExpenseTemplate(templateId);
      
      if (response['success'] != true) {
        throw Exception('Failed to delete recurring expense template');
      }
    } catch (e) {
      throw Exception('Failed to delete recurring expense template: ${e.toString()}');
    }
  }

  /// Restore a soft-deleted recurring expense template
  Future<RecurringExpenseTemplate> restoreRecurringExpenseTemplate(int templateId) async {
    try {
      final response = await _apiService.restoreRecurringExpenseTemplate(templateId);
      if (response['success'] == true && response['data'] != null) {
        RealTimeDataService().clearAllData();
        return RecurringExpenseTemplate.fromJson(response['data']);
      }
      throw Exception('Failed to restore recurring expense template');
    } catch (e) {
      throw Exception('Failed to restore recurring expense template: ${e.toString()}');
    }
  }

  /// Get recurring expense notifications
  Future<List<RecurringExpenseNotification>> getRecurringExpenseNotifications([String? roomspaceId]) async {
    try {
      final response = await _apiService.getRecurringExpenseNotifications();
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> notificationsData = response['data'];
        if (roomspaceId != null && roomspaceId.isNotEmpty) {
          await _cacheNotifications(roomspaceId, notificationsData);
        }
        return notificationsData
            .map((data) => RecurringExpenseNotification.fromJson(data))
            .toList();
      }
      
      if (roomspaceId != null && roomspaceId.isNotEmpty) {
        return await _readCachedNotifications(roomspaceId);
      }
      return [];
    } catch (e) {
      if (roomspaceId != null && roomspaceId.isNotEmpty) {
        final cached = await _readCachedNotifications(roomspaceId);
        if (cached.isNotEmpty) return cached;
      }
      throw Exception('Failed to get recurring expense notifications: ${e.toString()}');
    }
  }

  /// Process a recurring expense notification
  Future<void> processRecurringExpenseNotification(
    int notificationId,
    String action, {
    DateTime? scheduledDate,
  }) async {
    try {
      final actionData = <String, dynamic>{
        'action': action,
      };
      
      if (scheduledDate != null) {
        actionData['scheduled_date'] = scheduledDate.toIso8601String();
      }
      
      final response = await _apiService.processRecurringExpenseNotification(
        notificationId,
        actionData,
      );
      
      if (response['success'] != true) {
        throw Exception('Failed to process recurring expense notification');
      }
    } catch (e) {
      throw Exception('Failed to process recurring expense notification: ${e.toString()}');
    }
  }

  /// Get upcoming recurring expenses for a roomspace
  Future<List<RecurringExpenseTemplate>> getUpcomingRecurringExpenses(
    String roomspaceId, {
    int days = 30,
  }) async {
    try {
      final response = await _apiService.getUpcomingRecurringExpenses(roomspaceId, days: days);
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> templatesData = response['data'];
        return templatesData
            .map((data) => RecurringExpenseTemplate.fromJson(data))
            .toList();
      }
      
      return [];
    } catch (e) {
      throw Exception('Failed to get upcoming recurring expenses: ${e.toString()}');
    }
  }

  /// Get recurring expense statistics for a roomspace
  Future<Map<String, dynamic>> getRecurringExpenseStats(String roomspaceId) async {
    try {
      final response = await _apiService.getRecurringExpenseStats(roomspaceId);
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'];
      }
      
      return {};
    } catch (e) {
      throw Exception('Failed to get recurring expense statistics: ${e.toString()}');
    }
  }
}
