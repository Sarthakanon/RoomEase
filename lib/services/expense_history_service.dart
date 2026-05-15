import 'package:flutter/foundation.dart';
import '../models/expense_history_models.dart';
import 'api_service.dart';

/// Service for managing expense history
class ExpenseHistoryService {
  static final ExpenseHistoryService _instance = ExpenseHistoryService._internal();
  factory ExpenseHistoryService() => _instance;
  ExpenseHistoryService._internal();

  final ApiService _apiService = ApiService();

  /// Get expense history for a roomspace
  Future<List<ExpenseHistoryItem>> getRoomspaceHistory({
    required String roomspaceId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      debugPrint('📜 Fetching expense history for roomspace: $roomspaceId');
      
      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/history?limit=$limit&offset=$offset',
      );
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> historyData = response['data'];
        final history = historyData
            .map((item) => ExpenseHistoryItem.fromJson(item))
            .toList();
        
        debugPrint('✅ Fetched ${history.length} history items');
        return history;
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching expense history: $e');
      return [];
    }
  }

  /// Get recent history (last 10 items)
  Future<List<ExpenseHistoryItem>> getRecentHistory({
    required String roomspaceId,
  }) async {
    return getRoomspaceHistory(
      roomspaceId: roomspaceId,
      limit: 10,
      offset: 0,
    );
  }

  /// Log expense creation
  Future<void> logExpenseCreated({
    required String roomspaceId,
    required String expenseId,
    required String title,
    required double amount,
    required String createdBy,
  }) async {
    try {
      await _apiService.post(
        '/api/roomspaces/$roomspaceId/history',
        data: {
          'type': 'expense_created',
          'title': title,
          'description': 'Created expense "$title" for Rs. ${amount.toStringAsFixed(2)}',
          'performed_by': createdBy,
          'amount': amount,
          'metadata': {
            'expense_id': expenseId,
          },
        },
      );
    } catch (e) {
      debugPrint('❌ Error logging expense creation: $e');
    }
  }

  /// Log expense edit
  Future<void> logExpenseEdited({
    required String roomspaceId,
    required String expenseId,
    required String title,
    required String editedBy,
    String? changes,
  }) async {
    try {
      await _apiService.post(
        '/api/roomspaces/$roomspaceId/history',
        data: {
          'type': 'expense_edited',
          'title': title,
          'description': changes ?? 'Edited expense "$title"',
          'performed_by': editedBy,
          'metadata': {
            'expense_id': expenseId,
          },
        },
      );
    } catch (e) {
      debugPrint('❌ Error logging expense edit: $e');
    }
  }

  /// Log expense deletion
  Future<void> logExpenseDeleted({
    required String roomspaceId,
    required String expenseId,
    required String title,
    required double amount,
    required String deletedBy,
  }) async {
    try {
      await _apiService.post(
        '/api/roomspaces/$roomspaceId/history',
        data: {
          'type': 'expense_deleted',
          'title': title,
          'description': 'Deleted expense "$title" (Rs. ${amount.toStringAsFixed(2)})',
          'performed_by': deletedBy,
          'amount': amount,
          'metadata': {
            'expense_id': expenseId,
          },
        },
      );
    } catch (e) {
      debugPrint('❌ Error logging expense deletion: $e');
    }
  }

  /// Log payment confirmation
  Future<void> logPaymentConfirmed({
    required String roomspaceId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String confirmedBy,
  }) async {
    try {
      await _apiService.post(
        '/api/roomspaces/$roomspaceId/history',
        data: {
          'type': 'payment_confirmed',
          'title': 'Payment Confirmed',
          'description': 'Payment of Rs. ${amount.toStringAsFixed(2)} confirmed',
          'performed_by': confirmedBy,
          'amount': amount,
          'metadata': {
            'from_user': fromUser,
            'to_user': toUser,
          },
        },
      );
    } catch (e) {
      debugPrint('❌ Error logging payment confirmation: $e');
    }
  }

  /// Log settlement
  Future<void> logSettlement({
    required String roomspaceId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String settledBy,
  }) async {
    try {
      await _apiService.post(
        '/api/roomspaces/$roomspaceId/history',
        data: {
          'type': 'settlement_made',
          'title': 'Settlement Made',
          'description': 'Settled Rs. ${amount.toStringAsFixed(2)}',
          'performed_by': settledBy,
          'amount': amount,
          'metadata': {
            'from_user': fromUser,
            'to_user': toUser,
          },
        },
      );
    } catch (e) {
      debugPrint('❌ Error logging settlement: $e');
    }
  }
}
