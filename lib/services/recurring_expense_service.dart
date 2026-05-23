import '../models/recurring_expense_models.dart';
import 'api_service.dart';
import 'real_time_data_service.dart';

/// Service for managing recurring expenses
class RecurringExpenseService {
  static final RecurringExpenseService _instance = RecurringExpenseService._internal();
  factory RecurringExpenseService() => _instance;
  RecurringExpenseService._internal();

  final ApiService _apiService = ApiService();

  /// Get recurring expense templates for a roomspace
  Future<List<RecurringExpenseTemplate>> getRecurringExpenseTemplates(String roomspaceId) async {
    try {
      final response = await _apiService.getRecurringExpenseTemplates(roomspaceId);
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> templatesData = response['data'];
        return templatesData
            .map((data) => RecurringExpenseTemplate.fromJson(data))
            .toList();
      }
      
      return [];
    } catch (e) {
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
  Future<List<RecurringExpenseNotification>> getRecurringExpenseNotifications() async {
    try {
      final response = await _apiService.getRecurringExpenseNotifications();
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> notificationsData = response['data'];
        return notificationsData
            .map((data) => RecurringExpenseNotification.fromJson(data))
            .toList();
      }
      
      return [];
    } catch (e) {
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
